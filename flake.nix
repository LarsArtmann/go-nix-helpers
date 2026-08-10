{
  description = "Shared Nix helpers for LarsArtmann Go repositories — mkPreparedSource for private-dep injection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [ inputs.treefmt-nix.flakeModule ];

      flake = {
        # Public library API — system-independent pure functions.
        # Consumers can use either:
        #   (a) raw import (works with flake = false):
        #       mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") { inherit pkgs lib; goPkg = pkgs.go_1_26; };
        #   (b) flake lib (works when imported as a real flake):
        #       mkPreparedSource = go-nix-helpers.lib.mkPreparedSource { inherit pkgs lib; goPkg = pkgs.go_1_26; };
        lib.mkPreparedSource = import ./mkPreparedSource.nix;
        lib.mkGoFlake =
          args:
          builtins.trace "WARNING: mkGoFlake.nix is deprecated and will be removed in the first tagged release (v1.0.0). Migrate to flakeModules.go-standard — see docs/migration-guide.md" (
            import ./mkGoFlake.nix args
          );

        # go-standard is a composite module that bundles treefmt-nix internally,
        # so consumers do NOT need to declare treefmt-nix or systems as inputs.
        # Consumer needs only: nixpkgs, flake-parts, go-nix-helpers.
        flakeModules.go-standard = {
          imports = [
            inputs.treefmt-nix.flakeModule
            ./modules/go-standard.nix
          ];
        };
      };

      perSystem =
        {
          config,
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
              self
              inputs
              ;
          };
          # Pure function property tests for stripVersionSuffix/repoName.
          pureFunctionTests = import ./test-pure-functions.nix { inherit pkgs lib; };
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
            pureFunctions = pureFunctionTests;
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
              program = pkgs.writeShellApplication {
                name = "dashboard";
                runtimeInputs = [ pkgs.nix ];
                text = ''
                  exec ${./scripts/dashboard.sh} "$@"
                '';
              };
              meta.description = "Overview of flake check status across all projects";
            };

            lint = {
              type = "app";
              program = pkgs.writeShellApplication {
                name = "nix-lint";
                runtimeInputs = [ pkgs.nix ];
                text = ''
                  exec ${./scripts/nix-lint.sh} "$@"
                '';
              };
              meta.description = "Lint flake.nix files for common error patterns";
            };
          };

          # -- Dev Shell ----------------------------------------------------------
          devShells.default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              nixfmt
              nix
              git
              man
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
