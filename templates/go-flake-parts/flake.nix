{
  description = "REPLACE_ME — short description of what this project does";

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

    go-nix-helpers = {
      url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
      flake = false;
    };

    # -- Private deps (flake = false, add/remove as needed) ----------------
    # go-finding = {
    #   url = "git+ssh://git@github.com/LarsArtmann/go-finding?ref=master";
    #   flake = false;
    # };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      go-nix-helpers,
      # go-finding,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem =
        { config, pkgs, lib, system, ... }:
        let
          goPkg = pkgs.go_1_26;

          version = self.shortRev or self.dirtyRev or "dev";
          commit = self.rev or "dirty";

          ldflags = [
            "-s"
            "-w"
            "-X REPLACE_ME/internal/appversion.Version=${version}"
            "-X REPLACE_ME/internal/appversion.Commit=${commit}"
          ];

          buildTags = [ ];
          buildTagsFlag =
            if buildTags != [ ]
            then "-tags=${lib.concatStringsSep "," buildTags}"
            else "";

          # -- Use go-nix-helpers for private deps (optional) ----------------
          # mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
          #   inherit pkgs lib;
          #   inherit goPkg;
          # };
          #
          # preparedSrc = mkPreparedSource {
          #   name = "REPLACE_ME";
          #   inherit version;
          #   src = lib.cleanSource ./.;
          #   deps = {
          #     "github.com/larsartmann/go-finding" = go-finding;
          #     "github.com/larsartmann/go-filewatcher/v2" = go-filewatcher;
          #   };
          #   # subModules auto-discovered — no manual list needed.
          #   # Build validates that all private requires have replaces.
          # };

          vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          # ^^^ Set to "" for first build, then paste the hash from:
          #     nix build .#packages.default --no-out-link 2>&1 | grep "got:"

          buildGoModule = pkgs.buildGoModule.override { inherit goPkg; };

          sharedAttrs = {
            inherit version;
            src = lib.cleanSource ./.;
            inherit vendorHash;
            proxyVendor = true;
            buildFlagsArray = lib.optional (buildTagsFlag != "") buildTagsFlag;
          };
        in
        {
          # -- Packages -----------------------------------------------------------
          packages = {
            default = config.packages.REPLACE_ME;

            REPLACE_ME = buildGoModule (
              sharedAttrs
              // {
                pname = "REPLACE_ME";
                inherit ldflags;
                subPackages = [ "cmd/REPLACE_ME" ];
                doCheck = true;
                meta = with lib; {
                  description = "REPLACE_ME — short description";
                  homepage = "https://github.com/LarsArtmann/REPLACE_ME";
                  license = licenses.mit;
                  maintainers = [ maintainers.larsartmann ];
                  mainProgram = "REPLACE_ME";
                };
              }
            );
          };

          # -- Apps (nix run .#<name>) --------------------------------------------
          apps = {
            default = {
              type = "app";
              program = lib.getExe config.packages.default;
            };

            test = {
              type = "app";
              program = pkgs.writeShellApplication {
                name = "run-test";
                runtimeInputs = [ goPkg ];
                text = "go test -race -v -coverprofile=coverage.out ./...";
              };
            };

            lint = {
              type = "app";
              program = pkgs.writeShellApplication {
                name = "run-lint";
                runtimeInputs = [ goPkg pkgs.golangci-lint ];
                text = "golangci-lint run ./...";
              };
            };
          };

          # -- Dev Shells ---------------------------------------------------------
          devShells = {
            default = pkgs.mkShell {
              packages = with pkgs; [
                goPkg
                gopls
                gofumpt
                goimports
                golangci-lint
                git
              ];

              inputsFrom = [ config.packages.default ];

              GOWORK = "off";
              GOTOOLCHAIN = "local";

              shellHook = ''
                echo "REPLACE_ME dev shell — Go $(go version | awk '{print $3}')"
              '';
            };

            ci = pkgs.mkShellNoCC {
              packages = [
                goPkg
                pkgs.golangci-lint
              ];

              GOWORK = "off";
            };
          };

          # -- Checks (nix flake check) -------------------------------------------
          # IMPORTANT: Always use a single checks = { ... } attrset.
          # NEVER use dot-notation (checks.X = ...) outside this block.
          # NEVER place checks inside treefmt or other blocks.
          checks = {
            format = config.treefmt.build.check self;
            build = config.packages.default;
            test = config.packages.default.overrideAttrs (_: {
              doCheck = true;
            });
          };

          # -- Formatter (nix fmt) ------------------------------------------------
          # IMPORTANT: Always use programs.X.enable, never bare X.enable.
          treefmt = {
            projectRootFile = "go.mod";
            programs = {
              gofumpt.enable = true;
              goimports.enable = true;
              nixfmt.enable = true;
            };
          };
        };

      # -- Overlay (for other flakes to consume) --------------------------------
      flake.overlays.default = final: _prev: {
        REPLACE_ME = self.packages.${final.stdenv.system}.default;
      };
    };
}
