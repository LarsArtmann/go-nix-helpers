# go-standard.nix — Standard flake-parts module for LarsArtmann Go projects
#
# Bundles: treefmt-nix (via composite module in flake.nix)
#
# Provides: packages.default, apps.default/test/lint, devShells.default/ci,
#           checks.format/build, treefmt, flake.overlays.default
#
# Usage (consumer's flake.nix — only 3 inputs needed!):
#
#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#     flake-parts = {
#       url = "github:hercules-ci/flake-parts";
#       inputs.nixpkgs-lib.follows = "nixpkgs";
#     };
#     go-nix-helpers = {
#       url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
#       inputs.nixpkgs.follows = "nixpkgs";
#     };
#   };
#
#   outputs = inputs@{ self, ... }:
#     flake-parts.lib.mkFlake { inherit inputs; } {
#       imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];
#       go-standard = {
#         pname = "my-project";
#         vendorHash = "sha256-AAA...";
#         description = "What this project does";
#       };
#     };
{
  config,
  lib,
  inputs,
  self,
  ...
}:
let
  cfg = config.go-standard;

  # Default systems matching github:nix-systems/default
  # Consumers no longer need a `systems` flake input.
  defaultSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
in
{
  options.go-standard = {
    pname = lib.mkOption {
      type = lib.types.str;
      description = "Package name (also used as overlay attr and mainProgram)";
    };

    vendorHash = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Vendor hash for buildGoModule (null = committed vendor/)";
    };

    src = lib.mkOption {
      type = lib.types.path;
      default = self.outPath;
      defaultText = "self.outPath";
      description = "Source path for the Go module (use lib.fileset for filtering)";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "A LarsArtmann Go project";
      description = "Short description for package meta";
    };

    subPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "." ];
      description = "Subpackages to build";
    };

    goPkgAttr = lib.mkOption {
      type = lib.types.str;
      default = "go_1_26";
      description = "Go package attribute in nixpkgs";
    };

    enableTempl = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include templ in devShells and treefmt";
    };

    enableGovulncheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include govulncheck in the default devShell";
    };

    enableGopls = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include gopls in the default devShell";
    };

    deps = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = ''
        Private Go deps for mkPreparedSource.
        When non-empty, the module auto-wires mkPreparedSource and
        auto-injects GOPRIVATE into devShells.
      '';
    };

    subModules = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = ''
        Explicit sub-modules for mkPreparedSource (merged with auto-discovered).
        Rarely needed — auto-discovery handles everything by default.
      '';
    };

    postPatchExtra = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Extra postPatch commands for mkPreparedSource (rarely needed)";
    };

    autoGoPrivate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When deps are set, auto-inject GOPRIVATE into devShells to prevent
        Go from trying to reach the public proxy for private repos.
        Uses both casings: github.com/larsartmann/*,github.com/LarsArtmann/*.
        Can be overridden via shellExtraEnv.GOPRIVATE if needed.
      '';
    };

    validatePrivateDeps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Pass through to mkPreparedSource. When true, build fails with a clear
        error if any private require in go.mod lacks a replace directive.
        Set to false if some LarsArtmann deps are public.
      '';
    };

    proxyVendor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Pass proxyVendor to buildGoModule (true = vendor via Go proxy)";
    };

    ldflags = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = "Custom ldflags (null = default version-injection flags)";
    };

    extraMeta = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra attributes merged into package meta";
    };

    extraBuildAttrs = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra attributes merged into buildGoModule";
    };

    devShellExtraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      description = "Extra packages for the default devShell (function of pkgs)";
    };

    shellExtraEnv = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra env vars for devShells";
    };
  };

  config = {
    systems = lib.mkDefault defaultSystems;

    perSystem =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        version = self.rev or self.dirtyRev or "dev";

        goPkg = pkgs.${cfg.goPkgAttr};

        usePreparedSource = cfg.deps != { };

        preparedSrc =
          if usePreparedSource then
            (import "${inputs.go-nix-helpers}/mkPreparedSource.nix" {
              inherit pkgs lib goPkg;
            })
              {
                name = cfg.pname;
                inherit version;
                src = cfg.src;
                inherit (cfg)
                  deps
                  subModules
                  postPatchExtra
                  validatePrivateDeps
                  ;
              }
          else
            null;

        finalSrc = if usePreparedSource then preparedSrc else cfg.src;

        buildGoModule = pkgs.buildGoModule.override { go = goPkg; };

        finalLdflags =
          if cfg.ldflags != null then
            cfg.ldflags
          else
            [
              "-s"
              "-w"
              "-X main.version=${version}"
            ];

        # When using mkPreparedSource, the local copies may introduce
        # transitive deps not in go.mod. The FOD (go-modules derivation)
        # has network access, so we run `go mod tidy` there to resolve
        # them, then propagate the tidied go.mod/go.sum to the main build.
        autoDepFodAttrs = lib.optionalAttrs usePreparedSource {
          modBuildPhase = ''
            runHook preBuild
            export GOCACHE=$TMPDIR/go-cache
            export GOPATH="$TMPDIR/go"
            cd "$modRoot"
            go mod tidy
            go mod vendor
            mkdir -p vendor
            runHook postBuild
          '';
          modInstallPhase = ''
            cp -r --reflink=auto vendor $out
            cp go.mod $out/go.mod
            cp go.sum $out/go.sum
          '';
        };

        # Sync tidied go.mod/go.sum from FOD output to main build directory.
        autoDepSyncPreBuild = lib.optionalString usePreparedSource ''
          if [ -n "''${goModules:-}" ] && [ -f "$goModules/go.mod" ]; then
            cp "$goModules/go.mod" go.mod
            cp "$goModules/go.sum" go.sum
          fi
        '';

        # Merge user's extraBuildAttrs, with special preBuild handling.
        userExtraMinusPreBuild = builtins.removeAttrs cfg.extraBuildAttrs [ "preBuild" ];
        mergedPreBuild = autoDepSyncPreBuild + (cfg.extraBuildAttrs.preBuild or "");

        package = buildGoModule (
          {
            inherit (cfg) pname;
            inherit version;
            src = finalSrc;
            inherit (cfg) vendorHash;
            proxyVendor = if usePreparedSource then false else cfg.proxyVendor;
            inherit (cfg) subPackages;
            ldflags = finalLdflags;
            preBuild = mergedPreBuild;
            nativeBuildInputs = lib.optionals cfg.enableTempl [ pkgs.templ ];
            meta = {
              inherit (cfg) description;
              license = lib.licenses.mit;
              mainProgram = cfg.pname;
              maintainers = [
                {
                  name = "Lars Artmann";
                  github = "LarsArtmann";
                }
              ];
            }
            // cfg.extraMeta;
          }
          // autoDepFodAttrs
          // userExtraMinusPreBuild
        );

        templPkg = lib.optionals cfg.enableTempl [ pkgs.templ ];
        goplsPkg = lib.optionals cfg.enableGopls [ pkgs.gopls ];
        vulncheckPkg = lib.optionals cfg.enableGovulncheck [ pkgs.govulncheck ];

        mkApp = name: runtimeInputs: text: {
          type = "app";
          program = lib.getExe (pkgs.writeShellApplication { inherit name runtimeInputs text; });
        };

        autoGoPrivateEnv =
          if cfg.deps != { } && cfg.autoGoPrivate then
            { GOPRIVATE = "github.com/larsartmann/*,github.com/LarsArtmann/*"; }
          else
            { };

        finalShellExtraEnv = autoGoPrivateEnv // cfg.shellExtraEnv;
      in
      {
        packages = {
          default = package;
          ${cfg.pname} = package;
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
        };

        devShells = {
          default = pkgs.mkShell (
            {
              packages = [
                goPkg
                pkgs.golangci-lint
              ]
              ++ templPkg
              ++ goplsPkg
              ++ vulncheckPkg
              ++ (cfg.devShellExtraPackages pkgs);
              GOWORK = "off";
              GOTOOLCHAIN = "local";
            }
            // finalShellExtraEnv
          );

          ci = pkgs.mkShellNoCC (
            {
              packages = [
                goPkg
                pkgs.golangci-lint
              ]
              ++ templPkg;
              GOWORK = "off";
              GOTOOLCHAIN = "local";
            }
            // finalShellExtraEnv
          );
        };

        checks = {
          format = config.treefmt.build.check self;
          build = config.packages.default;
        };

        treefmt = {
          projectRootFile = "go.mod";
          programs = {
            gofumpt.enable = true;
            goimports.enable = true;
            nixfmt.enable = true;
            templ.enable = cfg.enableTempl;
          };
        };
      };

    flake.overlays.default = final: _prev: {
      ${cfg.pname} = self.packages.${final.stdenv.system}.default;
    };
  };
}
