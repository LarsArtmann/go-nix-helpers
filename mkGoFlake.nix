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

  # Build configuration
  doCheck ? true,
  ldflags ? null,
  goPkgAttr ? "go_1_26",
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
      goPkg = pkgs.${goPkgAttr};

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

      treefmt = {
        projectRootFile = "go.mod";
        programs = {
          gofumpt.enable = true;
          goimports.enable = true;
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
