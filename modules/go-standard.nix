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

    systems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultSystems;
      defaultText = lib.literalExpression ''
        [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ]
      '';
      description = ''
        Systems to build for. Defaults to the standard set from
        github:nix-systems/default. Override to restrict or extend.
        Alternatively, use a `systems` flake input and set
        `go-standard.systems = import inputs.systems;`.
      '';
    };

    enableCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run `go test` during the Nix build (doCheck)";
    };

    enableOverlay = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to generate flake.overlays.default";
    };

    buildFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra build flags passed to `go build` (e.g. build tags)";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = self.rev or self.dirtyRev or "dev";
      defaultText = lib.literalExpression "self.rev or self.dirtyRev or \"dev\"";
      description = ''
        Version string for the package. Defaults to the git revision.
        Override for custom versioning.
      '';
    };

    enableGolangciLint = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include golangci-lint in devShells and the lint app";
    };

    enableGofumpt = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable gofumpt in treefmt programs";
    };

    enableGoimports = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable goimports in treefmt programs";
    };

    enableNixfmt = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable nixfmt in treefmt programs";
    };

    enableShfmt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable shfmt (shell script formatter) in treefmt programs";
    };

    enableCompletions = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install shell completions (bash, zsh, fish) for the default binary.
        Requires the binary to support `--completion <shell>` subcommand
        (e.g. cobra, urfave/cli). Emits a build-time warning if the binary
        doesn't support completions instead of silently doing nothing.
      '';
    };

    packages = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            subPackages = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "." ];
              description = "Go subPackages to build for this binary";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "A LarsArtmann Go project";
              description = "Short description for this package's meta";
            };
          };
        }
      );
      default = { };
      description = ''
        Additional packages for monorepo support.
        When set, generates a separate buildGoModule for each entry,
        all sharing the same source and vendor hash.

        Example:
        ```
        go-standard.packages = {
          server.subPackages = [ "cmd/server" ];
          worker.subPackages = [ "cmd/worker" ];
        };
        ```
      '';
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
        Uses `privateGlobPattern` (default: LarsArtmann globs) so all repos
        matching the pattern are covered, including those not explicitly
        listed in deps but resolvable via SSH in the devShell.
        Can be overridden via shellExtraEnv.GOPRIVATE if needed.
      '';
    };

    privateGlobPattern = lib.mkOption {
      type = lib.types.str;
      default = "github.com/larsartmann/*,github.com/LarsArtmann/*";
      description = ''
        GOPRIVATE glob pattern used by `autoGoPrivate`.
        Defaults to LarsArtmann repos. Override for other organizations,
        e.g. `"github.com/myorg/*"` or `"github.com/myorg/*,github.com/MyOrg/*"`.
        Only effective when `autoGoPrivate = true` and `deps` is non-empty.
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

    privateDepPattern = lib.mkOption {
      type = lib.types.str;
      default = "github\\.com/[Ll]ars[Aa]rtmann/";
      description = ''
        ERE regex matching module paths in go.mod that must have a replace
        directive. Override for other organizations. Default matches all
        LarsArtmann repos.
      '';
    };

    publicDeps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Module paths to exclude from private dependency validation only.
        Use for repos that match privateDepPattern but are actually public
        (served by proxy.golang.org). Entries must match the exact module
        path as it appears in go.mod.
        Example: [ "github.com/larsartmann/go-atomic-write" ]

        NOTE: This does NOT affect GOPRIVATE. All modules matching
        `privateGlobPattern` are always marked private in devShells.
        This option only suppresses false-positive "missing dep" errors
        during build-time validation.
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
      description = ''
        Extra attributes merged into buildGoModule.
        Six attributes receive special concatenation handling:
        - `nativeBuildInputs` — appended to module's list (templ, installShellFiles)
        - `buildInputs` — appended to module's list
        - `checkInputs` — appended to module's list
        - `configureFlags` — appended to module's list
        - `preBuild` — prepended to module-generated preBuild
        - `postInstall` — prepended to module-generated postInstall
        All other attributes override module defaults via the `//` operator.
      '';
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
    inherit (cfg) systems;

    perSystem =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        inherit (cfg) version;

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
                inherit (cfg) src;
                inherit (cfg)
                  deps
                  subModules
                  postPatchExtra
                  validatePrivateDeps
                  privateDepPattern
                  publicDeps
                  ;
              }
          else
            null;

        finalSrc = if usePreparedSource then preparedSrc else cfg.src;

        buildGoModule = pkgs.buildGoModule.override { go = goPkg; };

        # Warn if vendorHash looks like a placeholder that the consumer
        # forgot to replace with a real hash after initial setup.
        vendorHashWarning =
          if cfg.vendorHash != null && builtins.match "sha256-(AAA[A+/]*=*)" cfg.vendorHash != null then
            builtins.trace "warning: go-standard.vendorHash appears to be a placeholder (${cfg.vendorHash}). Set the real hash after the first build." null
          else
            null;

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

        # Merge user's extraBuildAttrs, with special handling for attrs
        # that should be concatenated rather than overridden:
        # - preBuild/postInstall: concatenated with module-generated values
        # - nativeBuildInputs: concatenated (module adds templ, installShellFiles)
        # - buildInputs/checkInputs/configureFlags: concatenated for future-proofing
        # All other attrs override the module defaults via the // operator.
        userExtraBuildAttrs = builtins.removeAttrs cfg.extraBuildAttrs [
          "preBuild"
          "postInstall"
          "nativeBuildInputs"
          "buildInputs"
          "checkInputs"
          "configureFlags"
        ];
        userNativeBuildInputs = cfg.extraBuildAttrs.nativeBuildInputs or [ ];
        userBuildInputs = cfg.extraBuildAttrs.buildInputs or [ ];
        userCheckInputs = cfg.extraBuildAttrs.checkInputs or [ ];
        userConfigureFlags = cfg.extraBuildAttrs.configureFlags or [ ];
        mergedPreBuild = autoDepSyncPreBuild + (cfg.extraBuildAttrs.preBuild or "");

        # Reusable package builder for monorepo support.
        # Builds one Go binary with the given name and subPackages.
        mkGoPackage =
          pkgName: subPkgs: pkgDesc:
          let
            completionPostInstall = lib.optionalString cfg.enableCompletions ''
              # Check if the binary supports --completion before installing.
              # Falls back to a clear warning instead of silently installing
              # empty completion files.
              # timeout prevents a hanging binary from blocking the build.
              if ! timeout 10 $out/bin/${pkgName} --completion bash >/dev/null 2>&1; then
                echo "" >&2
                echo "=======================================================" >&2
                echo "go-standard: enableCompletions is enabled but ${pkgName}" >&2
                echo "does not support the --completion subcommand." >&2
                echo "Shell completions were NOT installed." >&2
                echo "Either set enableCompletions = false or ensure the binary" >&2
                echo "uses a framework that supports --completion (cobra, urfave/cli)." >&2
                echo "=======================================================" >&2
              else
                installShellCompletion --cmd ${pkgName} \
                  --bash <(timeout 10 $out/bin/${pkgName} --completion bash 2>/dev/null || true) \
                  --zsh <(timeout 10 $out/bin/${pkgName} --completion zsh 2>/dev/null || true) \
                  --fish <(timeout 10 $out/bin/${pkgName} --completion fish 2>/dev/null || true)
              fi
            '';
            mergedPostInstall = completionPostInstall + (cfg.extraBuildAttrs.postInstall or "");
          in
          buildGoModule (
            {
              pname = pkgName;
              inherit version;
              src = finalSrc;
              inherit (cfg) vendorHash;
              proxyVendor = if usePreparedSource then false else cfg.proxyVendor;
              subPackages = subPkgs;
              doCheck = cfg.enableCheck;
              inherit (cfg) buildFlags;
              ldflags = finalLdflags;
              preBuild = mergedPreBuild;
              postInstall = mergedPostInstall;
              nativeBuildInputs =
                lib.optionals cfg.enableTempl [ pkgs.templ ]
                ++ lib.optionals cfg.enableCompletions [ pkgs.installShellFiles ]
                ++ userNativeBuildInputs;
              buildInputs = userBuildInputs;
              checkInputs = userCheckInputs;
              configureFlags = userConfigureFlags;
              meta = {
                description = pkgDesc;
                license = lib.licenses.mit;
                mainProgram = pkgName;
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
            // userExtraBuildAttrs
          );

        # Build the default package (always present)
        # vendorHashWarning is referenced here to force evaluation of the
        # placeholder-detection trace at build time.
        package = builtins.seq vendorHashWarning (mkGoPackage cfg.pname cfg.subPackages cfg.description);

        # Build extra packages when monorepo config is set
        extraPackages = lib.mapAttrs (
          name: pcfg: mkGoPackage name pcfg.subPackages pcfg.description
        ) cfg.packages;

        templPkg = lib.optionals cfg.enableTempl [ pkgs.templ ];
        goplsPkg = lib.optionals cfg.enableGopls [ pkgs.gopls ];
        vulncheckPkg = lib.optionals cfg.enableGovulncheck [ pkgs.govulncheck ];
        golangciLintPkg = lib.optionals cfg.enableGolangciLint [ pkgs.golangci-lint ];

        mkApp = name: runtimeInputs: text: {
          type = "app";
          program = lib.getExe (pkgs.writeShellApplication { inherit name runtimeInputs text; });
        };

        autoGoPrivateEnv =
          if cfg.deps != { } && cfg.autoGoPrivate then { GOPRIVATE = cfg.privateGlobPattern; } else { };

        finalShellExtraEnv = autoGoPrivateEnv // cfg.shellExtraEnv;
      in
      {
        packages = {
          default = package;
          ${cfg.pname} = package;
        }
        // extraPackages;

        apps = {
          default = {
            type = "app";
            program = lib.getExe config.packages.default;
          };
          test = mkApp "run-test" [ goPkg ] "go test -race -v -coverprofile=coverage.out ./...";
        }
        // lib.optionalAttrs cfg.enableGolangciLint {
          lint = mkApp "run-lint" [
            goPkg
            pkgs.golangci-lint
          ] "golangci-lint run ./...";
        }
        //
          lib.optionalAttrs (cfg.enableGofumpt || cfg.enableGoimports || cfg.enableNixfmt || cfg.enableTempl)
            {
              fmt = {
                type = "app";
                program = lib.getExe (
                  pkgs.writeShellApplication {
                    name = "run-fmt";
                    runtimeInputs = [ config.treefmt.build.wrapper ];
                    text = "treefmt";
                  }
                );
              };
            }
        // lib.mapAttrs' (
          name: pkg:
          lib.nameValuePair name {
            type = "app";
            program = lib.getExe pkg;
          }
        ) extraPackages;

        devShells = {
          default = pkgs.mkShell (
            {
              packages = [
                goPkg
              ]
              ++ golangciLintPkg
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
              packages = [ goPkg ] ++ golangciLintPkg ++ templPkg;
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
            gofumpt.enable = cfg.enableGofumpt;
            goimports.enable = cfg.enableGoimports;
            nixfmt.enable = cfg.enableNixfmt;
            templ.enable = cfg.enableTempl;
            shfmt.enable = cfg.enableShfmt;
          };
        };
      };

    flake.overlays.default = lib.mkIf cfg.enableOverlay (
      final: _prev:
      {
        ${cfg.pname} = self.packages.${final.stdenv.system}.default;
      }
      // (builtins.mapAttrs (name: _pkg: self.packages.${final.stdenv.system}.${name}) cfg.packages)
    );
  };
}
