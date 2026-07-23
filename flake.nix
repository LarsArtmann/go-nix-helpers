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

      # Public library API — system-independent pure functions.
      # Consumers can use either:
      #   (a) raw import (works with flake = false):
      #       mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") { inherit pkgs lib; goPkg = pkgs.go_1_26; };
      #   (b) flake lib (works when imported as a real flake):
      #       mkPreparedSource = go-nix-helpers.lib.mkPreparedSource { inherit pkgs lib; goPkg = pkgs.go_1_26; };
      flake.lib.mkPreparedSource = import ./mkPreparedSource.nix;
      flake.lib.mkGoFlake = import ./mkGoFlake.nix;

      flake.flakeModules.go-standard = import ./modules/go-standard.nix;

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
        in
        {
          # -- Checks (nix flake check) -------------------------------------------
          # IMPORTANT: single checks attrset; verifyValidation is a shell script
          # (needs nix-store at runtime, unavailable in the sandbox) so it is
          # exposed as an app, not a check.
          checks = {
            inherit (tests) autoDiscovery explicitOnly;
            inherit (tests) verify;
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
            ];
            shellHook = ''
              echo "go-nix-helpers dev shell — nix $(nix --version)"
            '';
          };

          # -- Formatter (nix fmt) ------------------------------------------------
          # Pure Nix repo — only nixfmt; no gofumpt/goimports.
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
          };
        };
    };
}
