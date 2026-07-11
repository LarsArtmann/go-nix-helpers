# go-standard-template — Minimal flake.nix using go-standard module
#
# Copy this file as flake.nix, replace YOUR-PROJECT-NAME and vendorHash.
# Run: nix build && nix flake check
{
  description = "YOUR-PROJECT-NAME — One-line description";

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
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];

      go-standard = {
        pname = "YOUR-PROJECT-NAME";
        vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # nix build to compute
        description = "One-line description of the project";

        # Optional: enable templ support
        # enableTempl = true;

        # Optional: custom ldflags
        # ldflags = [ "-s" "-w" ];

        # Optional: extra build attrs (preBuild, etc.)
        # extraBuildAttrs.preBuild = "templ generate";

        # Optional: extra devShell packages
        # devShellExtraPackages = pkgs: [ pkgs.delve pkgs.gotools ];

        # Optional: extra shell env vars
        # shellExtraEnv = { GOPRIVATE = "github.com/larsartmann/*"; };
      };
    };
}
