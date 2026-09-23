# mkGoFlake.nix  (DEPRECATED — use modules/go-standard.nix instead)
#
# This function-based approach is superseded by the flake-parts module
# `go-standard`, which provides the same functionality via typed options.
# New projects should use `flakeModules.go-standard`; existing consumers
# will be migrated gradually.
#
# Migration: replace the `import ... mkGoFlake.nix` call with
#   imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];
#   go-standard = { pname = "..."; vendorHash = "..."; ... };
#
# --- Original docs (kept for reference during migration) ---
#
# Shared flake-parts module for LarsArtmann Go projects.
#
# Generates standard flake outputs from a single config attrset:
#   packages.default + packages.<pname>
#   apps.default, apps.test, apps.lint
#   devShells.default, devShells.ci
#   checks.format (treefmt), checks.build
#   treefmt (gofumpt + goimports + nixfmt)
#   flake.overlays.default
#
# Eliminates ~150 lines of duplicated flake.nix boilerplate per project.
#
# Usage (consumer's flake.nix):
#
#   outputs = inputs@{ self, ... }:
#     flake-parts.lib.mkFlake { inherit inputs; }
#       (import (inputs.go-nix-helpers + "/mkGoFlake.nix") {
#         inherit inputs self;
#         pname = "my-project";
#         version = "0.1.0";
#         vendorHash = "sha256-AAA...";
#         description = "What this project does";
#         src = ./.;
#         deps = {
#           "github.com/larsartmann/go-cqrs-lite" = inputs.go-cqrs-lite;
#         };
#       });
#
# All parameters with defaults are optional. For project-specific
# customisation, use: buildGoModuleOverrides, devShellExtraPackages,
# shellExtraEnv, extraApps, extraChecks, extraFlake.
{
  inputs,
  self,

  pname,
  version,
  vendorHash,
  description,

  src,

  # Private deps for mkPreparedSource (empty = no prepared source)
  deps ? { },
  subModules ? { },
  postPatchExtra ? "",
  validatePrivateDeps ? true,
  privateDepPattern ? "github\\.com/[Ll]ars[Aa]rtmann/",
  publicDeps ? [ ],

  # Build configuration
  doCheck ? true,
  ldflags ? null,
  goPkgAttr ? "go_1_26",
  # Go from the go.dev SOURCE tarball — set when the go.mod floor is newer
  # than nixpkgs' go (buildGoModule pins GOTOOLCHAIN=local, so the sandbox
  # cannot auto-download a toolchain). Drop once nixpkgs catches up.
  goTarballVersion ? null,
  goTarballHash ? null,
  buildGoModuleOverrides ? { },

  # Dev shell configuration
  devShellExtraPackages ? _pkgs: [ ],
  devShellShellHook ? "",
  shellExtraEnv ? { },

  # Extra outputs (functions receiving perSystem args)
  extraApps ? _: { },
  extraChecks ? _: { },
  extraFlake ? { },
}:
{
  systems = import inputs.systems;
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      goPkg =
        if goTarballVersion != null then
          if goTarballHash == null then
            throw "mkGoFlake: goTarballHash is required when goTarballVersion is set"
          else
            pkgs.${goPkgAttr}.overrideAttrs (
              finalAttrs: _prev: {
                version = goTarballVersion;
                src = pkgs.fetchurl {
                  url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
                  hash = goTarballHash;
                };
              }
            )
        else
          pkgs.${goPkgAttr};

      mkPreparedSource = import (inputs.go-nix-helpers + "/mkPreparedSource.nix") {
        inherit pkgs lib goPkg;
      };

      usePreparedSource = deps != { };

      preparedSrc = mkPreparedSource {
        name = pname;
        inherit
          version
          src
          deps
          subModules
          postPatchExtra
          validatePrivateDeps
          privateDepPattern
          publicDeps
          ;
      };

      finalSrc = if usePreparedSource then preparedSrc else src;

      buildGoModule = pkgs.buildGoModule.override { go = goPkg; };

      defaultLdflags = [
        "-s"
        "-w"
        "-X main.version=${version}"
      ];
      finalLdflags = if ldflags != null then ldflags else defaultLdflags;

      package = buildGoModule (
        {
          inherit pname version;
          src = finalSrc;
          inherit vendorHash doCheck;
          proxyVendor = true;
          ldflags = finalLdflags;
          meta = with lib; {
            inherit description;
            license = licenses.mit;
            mainProgram = pname;
          };
        }
        // buildGoModuleOverrides
      );

      mkApp = name: runtimeInputs: text: {
        type = "app";
        program = "${pkgs.writeShellApplication { inherit name runtimeInputs text; }}/bin/${name}";
      };

      finalShellHook =
        if devShellShellHook != "" then
          devShellShellHook
        else
          ''echo "${pname} dev shell — $(go version)"'';

      perSystemArgs = {
        inherit
          config
          pkgs
          lib
          goPkg
          package
          mkApp
          ;
      };
    in
    {
      packages = {
        default = package;
        ${pname} = package;
      };

      apps = {
        default = {
          type = "app";
          program = lib.getExe config.packages.default;
        };
        test = mkApp "run-test" [ goPkg ] "go test -race -v -coverprofile=coverage.out ./...";
        lint = mkApp "run-lint" [
          goPkg
          pkgs.golangci-lint
        ] "golangci-lint run ./...";
      }
      // (extraApps perSystemArgs);

      devShells = {
        default = pkgs.mkShell (
          {
            packages = [
              goPkg
              pkgs.golangci-lint
            ]
            ++ (devShellExtraPackages pkgs);
            GOWORK = "off";
            shellHook = finalShellHook;
          }
          // shellExtraEnv
        );
        ci = pkgs.mkShellNoCC (
          {
            packages = [
              goPkg
              pkgs.golangci-lint
            ];
            GOWORK = "off";
          }
          // shellExtraEnv
        );
      };

      checks = {
        format = config.treefmt.build.check self;
        build = config.packages.default;
      }
      // (extraChecks perSystemArgs);

      treefmt =
        let
          # Go formatters built on x/tools (gofumpt, goimports) resolve
          # packages through the `go` tool. Once go.mod's `go` directive is
          # NEWER than the formatter binary's own build toolchain, that
          # resolution triggers a GOTOOLCHAIN=auto download of the newer
          # toolchain — which always dies in the offline check sandbox
          # (reproduced 2026-09-23: go.mod `go 1.27.1` vs goTools/gofumpt
          # built on 1.26.x → "go: downloading go1.27.1: connection
          # refused" → exit 2/1 → check red). Wrapping each formatter with
          # the project's OWN Go (the same goPkg the build uses) on PATH
          # makes resolution local and version-exact.
          wrapWithGo =
            name: drv:
            pkgs.writeShellScriptBin name ''
              export PATH="${drv}/bin:${goPkg}/bin:$PATH"
              exec "${drv}/bin/${name}" "$@"
            '';
        in
        {
          projectRootFile = "go.mod";
          programs = {
            gofumpt = {
              enable = true;
              package = wrapWithGo "gofumpt" pkgs.gofumpt;
            };
            goimports = {
              enable = true;
              package = wrapWithGo "goimports" pkgs.gotools;
            };
            nixfmt.enable = true;
          };
        };
    };

  flake = {
    overlays.default = final: _prev: {
      ${pname} = self.packages.${final.stdenv.system}.default;
    };
  }
  // extraFlake;
}
