# go-standard-template — Minimal flake.nix using the go-standard module
#
# Only 3 flake inputs needed! treefmt-nix and systems are bundled internally.
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

    go-nix-helpers = {
      url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Optional: private deps (must be `flake = false`)
    # go-cqrs-lite = {
    #   url = "git+ssh://git@github.com/LarsArtmann/go-cqrs-lite?ref=master";
    #   flake = false;
    # };
  };

  outputs =
    inputs@{ self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];

      go-standard = {
        pname = "YOUR-PROJECT-NAME";
        vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # nix build to compute
        description = "One-line description of the project";

        # Optional: private Go deps (LarsArtmann repos).
        # When set, GOPRIVATE is auto-injected into devShells and
        # mkPreparedSource wires local replace directives automatically.
        # Add matching flake inputs (see below) with `flake = false`.
        # deps = {
        #   "github.com/larsartmann/go-cqrs-lite" = inputs.go-cqrs-lite;
        # };

        # Optional: repos that match the private pattern but are actually
        # public (served by proxy.golang.org). Excludes them from validation.
        # publicDeps = [ "github.com/larsartmann/go-atomic-write" ];

        # Optional: enable templ support
        # enableTempl = true;

        # Optional: custom ldflags
        # ldflags = [ "-s" "-w" ];

        # Optional: extra build attrs (preBuild, etc.)
        # extraBuildAttrs.preBuild = "templ generate";

        # Optional: extra devShell packages
        # devShellExtraPackages = pkgs: [ pkgs.delve pkgs.gotools ];

        # Optional: extra shell env vars (GOPRIVATE is auto-set when deps is set)
        # shellExtraEnv = { GOTOOLCHAIN = "local"; };
      };
    };
}
