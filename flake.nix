{
  description = "Shared Nix helpers for LarsArtmann Go repositories — mkPreparedSource for private-dep injection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OCI image building for the go-standard `container` option — bundled by
    # the composite module, so consumers do NOT declare it as an input.
    # Lock pin policy (2026-10-30): pinned to nlewo/nix2container rev
    # 42d1df94. Bumping it is a fleet-wide eval+build change (every consumer
    # inherits it transitively through this flake), so it bumps ONLY together
    # with a containerSmoke run here (the real-backend check) plus a green
    # `nix flake check` — never as part of an unrelated `nix flake update`.
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Match go-standard's default system set (nix-systems/default minus
      # x86_64-darwin, which nixpkgs 26.11 dropped) — importing the full
      # default set generated outputs for a system nothing can build.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      imports = [ inputs.treefmt-nix.flakeModule ];

      flake = {
        # Public library API — system-independent pure functions.
        # Consumers can use either:
        #   (a) raw import (works with flake = false):
        #       mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") { inherit pkgs lib; goPkg = pkgs.go_1_27; };
        #   (b) flake lib (works when imported as a real flake):
        #       mkPreparedSource = go-nix-helpers.lib.mkPreparedSource { inherit pkgs lib; goPkg = pkgs.go_1_27; };
        lib.mkPreparedSource = import ./mkPreparedSource.nix;
        # Newest go_1_XX branch in THIS flake's nixpkgs pin — the fleet-wide
        # "current Go" reference (dashboard.sh derives GO_LATEST from it, so
        # no script carries a manual bump site).
        lib.newestGoAttr =
          let
            pure = import ./pure-functions.nix { lib = inputs.nixpkgs.lib; };
          in
          pure.newestGoAttrName (builtins.attrNames inputs.nixpkgs.legacyPackages.x86_64-linux);
        lib.mkGoFlake =
          args:
          builtins.trace "WARNING: mkGoFlake.nix is deprecated and will be removed in the first tagged release (v1.0.0). Migrate to flakeModules.go-standard — see docs/migration-guide.md" (
            import ./mkGoFlake.nix args
          );

        # go-standard is a composite module that bundles treefmt-nix and
        # nix2container internally, so consumers do NOT need to declare
        # treefmt-nix, nix2container or systems as inputs.
        # Consumer needs only: nixpkgs, flake-parts, go-nix-helpers.
        flakeModules.go-standard =
          { config, ... }:
          {
            imports = [
              inputs.treefmt-nix.flakeModule
              ./modules/go-standard.nix
            ];
            # NOTE: go-standard.systems is mapped onto flake-parts' systems
            # INSIDE modules/go-standard.nix (`inherit (cfg) systems` in its
            # config block — eval-tested by test-module.nix
            # systemsOverrideCheck, plus a source-text guard). This composite
            # must NOT repeat the mapping: flake-parts' systems option is
            # listOf str (concat merge), so a second definition duplicates
            # the list (2026-09-25 added exactly that redundant copy; removed
            # 2026-11-17).
            # OCI image support: hand the per-system nix2container builders
            # to the module, the same closure-over-own-inputs trick as
            # treefmt-nix above. Consumers get container images without
            # declaring a fourth input.
            config.go-standard.container.nix2container = inputs.nix2container.packages;
          };
      };

      perSystem =
        {
          pkgs,
          lib,
          system,
          ...
        }:
        let
          # Integration-test derivations from test.nix, wired as flake checks.
          tests = import ./test.nix { inherit pkgs; };
          # Module-level tests for go-standard options and outputs.
          moduleTests = import ./test-module.nix {
            inherit
              pkgs
              lib
              inputs
              ;
          };
          # Pure function property tests for stripVersionSuffix/repoName.
          pureFunctionTests = import ./test-pure-functions.nix { inherit pkgs lib; };
          # Real-backend container smoke test: assemble an actual OCI image
          # with the locked nix2container (the same builder the composite
          # module wires into consumers) and run the module's structure gate
          # against the produced image.json. Covers what the stubbed module
          # tests cannot: the nix2container Go binary assembling layers,
          # perms handling, and the jq contract assertions.
          containerSmoke =
            let
              containerLib = import ./container.nix { inherit pkgs lib; };
              smokeConfig = containerLib.mkImageConfig {
                entrypoint = [ "/bin/hello" ];
                cmd = [
                  "-g"
                  "hi"
                ];
                env = containerLib.envList { SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt"; };
                user = "65532:65532";
                exposedPorts = [ "8080/tcp" ];
                volumes = [ "/data" ];
                labels = {
                  "org.opencontainers.image.title" = "container-smoke";
                  "org.opencontainers.image.version" = "smoke";
                };
              };
              smokeVols = containerLib.mkVolumeDirs {
                name = "container-smoke";
                volumes = [ "/data" ];
                user = "65532:65532";
              };
              smokeImage = containerLib.mkContainerImage {
                n2c = inputs.nix2container.packages.${system}.nix2container;
                imageName = "ghcr.io/larsartmann/container-smoke";
                config = smokeConfig;
                mainPackage = pkgs.hello;
                volumeDirs = smokeVols.dirs;
                volumePerms = smokeVols.perms;
                meta.description = "go-nix-helpers container smoke test image";
              };
            in
            containerLib.mkContainerStructureCheck {
              name = "container-smoke";
              image = smokeImage;
              config = smokeConfig;
              arch = pkgs.go.GOARCH;
            };
          # Man pages for go-standard and mkPreparedSource
          manPages = pkgs.stdenv.mkDerivation {
            name = "go-nix-helpers-manpages";
            dontUnpack = true;
            installPhase = ''
              mkdir -p $out/share/man/man5
              cp ${./docs/man/go-standard.5} $out/share/man/man5/
              cp ${./docs/man/mkPreparedSource.5} $out/share/man/man5/
            '';
          };
        in
        {
          # -- Checks (nix flake check) -------------------------------------------
          # IMPORTANT: single checks attrset; verifyValidation is a shell script
          # (needs nix-store at runtime, unavailable in the sandbox) so it is
          # exposed as an app, not a check.
          checks = {
            inherit (tests) autoDiscovery explicitOnly;
            inherit (tests) verify;
            inherit (moduleTests) moduleTest moduleTestNoOverlay;
            inherit (moduleTests) moduleTestTemplFreshness;
            pureFunctions = pureFunctionTests;
            inherit containerSmoke;
            # Fixture-integrity tripwire: test-assets/mock-templ-missing-generated
            # must NEVER contain generated *_templ.go files — the
            # templ-committed check depends on their absence, and the
            # auto-commit daemon has re-added them before (they are
            # gitignored for exactly this reason). Flake source copies
            # contain only git-tracked files, so absence here == absence
            # in git; scanning the store path is the sandbox-safe
            # equivalent of `git ls-files | grep _templ.go`.
            templFixtureGuard = pkgs.runCommand "templ-fixture-guard" { } ''
              committed=$(find ${self}/test-assets/mock-templ-missing-generated -name '*_templ.go' 2>/dev/null || true)
              if [ -n "$committed" ]; then
                echo "FAIL: generated *_templ.go files are tracked under test-assets/mock-templ-missing-generated:" >&2
                echo "$committed" >&2
                echo "The templ-committed fixture requires them absent; git rm them and commit." >&2
                exit 1
              fi
              echo "PASS: templ fixture clean (no tracked *_templ.go)"
              mkdir $out
            '';
            # Docs-annotation gates (docs-health annotate discipline):
            # gate 1 — every archived status report carries at least one
            # strikethrough resolution; gate 2 — no table in docs/status/
            # mixes struck and unstruck rows. Wrapper + vendored checker
            # live in scripts/ with upstream attribution.
            docsAnnotations =
              pkgs.runCommand "docs-annotations"
                {
                  nativeBuildInputs = [ pkgs.python3 ];
                }
                ''
                  bash ${self}/scripts/check-docs-annotations.sh ${self}
                  touch $out
                '';
            # Structural test: verify all expected flake outputs exist
            structural = pkgs.runCommand "structural-test" { } ''
              ${lib.concatStringsSep "\n" (
                lib.map
                  (check: ''
                    if [ -z "${check.value}" ]; then
                      echo "FAIL: ${check.name} is empty"
                      exit 1
                    fi
                  '')
                  [
                    {
                      name = "flakeModules.go-standard";
                      value = toString (self.flakeModules.go-standard or { } != { });
                    }
                    {
                      name = "lib.mkPreparedSource";
                      value = toString (self.lib ? mkPreparedSource);
                    }
                    {
                      name = "lib.mkGoFlake";
                      value = toString (self.lib ? mkGoFlake);
                    }
                  ]
              )}
              echo "PASS: all expected flake outputs exist"
              mkdir $out
            '';

            # Template evaluation test: verifies the go-standard template's
            # outputs function accepts mock inputs and produces a valid module.
            # Catches the class of bug where an identifier (e.g. flake-parts)
            # is used in the body but not destructured from inputs@{ ... }.
            # The original template bug (9471741→26b7620) went undetected
            # because nix-instantiate --parse only checks syntax, not semantics.
            templateEval =
              let
                evalResult = builtins.tryEval (
                  let
                    templateContent = import ./templates/go-standard/flake.nix;
                    outputsFn = templateContent.outputs;
                    mockInputs = {
                      inherit self;
                      flake-parts = {
                        lib.mkFlake = _: attrs: attrs;
                      };
                      nixpkgs = pkgs;
                      go-nix-helpers = self;
                    };
                    result = outputsFn mockInputs;
                  in
                  result ? go-standard && result ? imports
                );
              in
              pkgs.runCommand "template-eval-check" { } ''
                ${
                  if evalResult.success && evalResult.value then
                    ""
                  else
                    ''
                      echo "FAIL: go-standard template does not evaluate to a valid module"
                      echo "The outputs function must:"
                      echo "  1. Accept inputs@{ self, flake-parts, ... }"
                      echo "  2. Return an attrset with 'imports' and 'go-standard' keys"
                      echo "Common cause: an identifier used in the body is not"
                      echo "destructured from the inputs attribute set."
                      exit 1
                    ''
                }
                echo "PASS: go-standard template evaluates correctly"
                mkdir $out
              '';
          };

          # -- Apps (nix run .#<name>) --------------------------------------------
          apps = {
            # Run the negative-case validation check (outside the sandbox).
            # nix run .#verifyValidation
            verifyValidation = {
              type = "app";
              program = lib.getExe tests.verifyValidation;
              meta.description = "Verify validationTest fails with the expected error";
            };

            # Legacy entrypoints kept for discoverability.
            dashboard = {
              type = "app";
              program = lib.getExe (
                pkgs.writeShellApplication {
                  name = "dashboard";
                  runtimeInputs = [ pkgs.nix ];
                  text = ''
                    exec ${./scripts/dashboard.sh} "$@"
                  '';
                }
              );
              meta.description = "Overview of flake check status across all projects";
            };

            lint = {
              type = "app";
              program = lib.getExe (
                pkgs.writeShellApplication {
                  name = "nix-lint";
                  runtimeInputs = [ pkgs.nix ];
                  text = ''
                    exec ${./scripts/nix-lint.sh} "$@"
                  '';
                }
              );
              meta.description = "Lint flake.nix files for common error patterns";
            };
          };

          # -- Dev Shell ----------------------------------------------------------
          devShells.default = pkgs.mkShellNoCC {
            packages = [
              pkgs.nixfmt
              pkgs.nix
              pkgs.git
              pkgs.man
              manPages
            ];
            shellHook = ''
              echo "go-nix-helpers dev shell — nix $(nix --version)"
              echo "Man pages: man go-standard / man mkPreparedSource"
            '';
          };

          # -- Formatter (nix fmt) ------------------------------------------------
          # Pure Nix repo — only nixfmt; no gofumpt/goimports.
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.shfmt.enable = true;
          };
        };
    };
}
