# test-module.nix — Tests for the go-standard flake-parts module
#
# Verifies that:
# - All options exist with correct types and defaults
# - Config.systems uses cfg.systems
# - perSystem generates expected outputs (packages, apps, devShells, checks, treefmt)
# - Overlay is conditionally generated
#
# Wired into flake.nix checks.
{
  pkgs,
  lib,
  self,
  inputs,
}:
let
  # Minimal mock source: a Go project with just go.mod and main.go
  mockSrc = pkgs.runCommandLocal "mock-go-src" { } ''
    mkdir -p $out
    cat > $out/go.mod <<'EOF'
    module github.com/larsartmann/mock-go-project
    go 1.26
    EOF
    mkdir -p $out
    cat > $out/main.go <<'EOF'
    package main
    func main() {}
    EOF
  '';

  # Evaluate just the module's options using lib.evalModules
  # This lets us verify option definitions, types, and defaults
  moduleEval = lib.evalModules {
    modules = [
      ./modules/go-standard.nix
      {
        go-standard = {
          pname = "test-project";
          vendorHash = null;
          description = "Test project";
        };
      }
    ];
    specialArgs = {
      inputs = inputs;
      self = {
        outPath = mockSrc;
      };
    };
  };

  cfg = moduleEval.config.go-standard;

  # Simulate calling the perSystem function with mock perSystem args
  # We extract the perSystem value from the evaluated config
  perSystemFn = moduleEval.config.perSystem;

  # Mock perSystem arguments
  mockPkgs = pkgs;
  mockPerSystemArgs = {
    config = moduleEval.config;
    pkgs = mockPkgs;
    lib = mockPkgs.lib;
    system = "x86_64-linux";
  };

  # Evaluate perSystem outputs
  perSystemOutput =
    if builtins.isFunction perSystemFn then
      perSystemFn mockPerSystemArgs
    else
      perSystemFn;

  # Check helper: assert a condition and return a message
  assertCheck =
    name: condition: expected:
    if condition then
      "PASS: ${name}"
    else
      throw "FAIL: ${name} — expected ${expected}";

  # All option checks
  optionChecks = [
    (assertCheck "pname option exists" (cfg ? pname) "pname attr")
    (assertCheck "vendorHash option exists" (cfg ? vendorHash) "vendorHash attr")
    (assertCheck "vendorHash default is null" (cfg.vendorHash == null) "null")
    (assertCheck "src option exists" (cfg ? src) "src attr")
    (assertCheck "description option exists" (cfg ? description) "description attr")
    (assertCheck "subPackages default is [\".\"]" (cfg.subPackages == [ "." ]) "[\".\"]")
    (assertCheck "goPkgAttr default is go_1_26" (cfg.goPkgAttr == "go_1_26") "go_1_26")
    (assertCheck "enableTempl default is false" (cfg.enableTempl == false) "false")
    (assertCheck "enableGovulncheck default is true" (cfg.enableGovulncheck == true) "true")
    (assertCheck "enableGopls default is true" (cfg.enableGopls == true) "true")
    (assertCheck "deps default is empty" (cfg.deps == { }) "{}")
    (assertCheck "enableCheck default is true" (cfg.enableCheck == true) "true")
    (assertCheck "enableOverlay default is true" (cfg.enableOverlay == true) "true")
    (assertCheck "buildFlags default is empty" (cfg.buildFlags == [ ]) "[]")
    (assertCheck "version default is dev" (cfg.version == "dev") "dev")
    (assertCheck "enableGolangciLint default is true" (cfg.enableGolangciLint == true) "true")
    (assertCheck "enableGofumpt default is true" (cfg.enableGofumpt == true) "true")
    (assertCheck "enableGoimports default is true" (cfg.enableGoimports == true) "true")
    (assertCheck "autoGoPrivate default is true" (cfg.autoGoPrivate == true) "true")
    (assertCheck "validatePrivateDeps default is true" (cfg.validatePrivateDeps == true) "true")
    (assertCheck "proxyVendor default is true" (cfg.proxyVendor == true) "true")
    (assertCheck "systems default is 4-element list" (
      builtins.length cfg.systems == 4
    ) "4 systems")
    (assertCheck "systems includes x86_64-linux" (
      builtins.elem "x86_64-linux" cfg.systems
    ) "x86_64-linux in list")
    (assertCheck "ldflags default is null" (cfg.ldflags == null) "null")
    (assertCheck "extraMeta default is empty" (cfg.extraMeta == { }) "{}")
    (assertCheck "extraBuildAttrs default is empty" (cfg.extraBuildAttrs == { }) "{}")
    (assertCheck "shellExtraEnv default is empty" (cfg.shellExtraEnv == { }) "{}")
  ];

  perSystemChecks =
    let
      has = path: builtins.hasAttrByPath path perSystemOutput;
    in
    [
      (assertCheck "packages.default exists" (has [ "packages" "default" ]) "packages.default")
      (assertCheck "packages.test-project exists" (
        has [ "packages" "test-project" ]
      ) "packages.test-project")
      (assertCheck "apps.default exists" (has [ "apps" "default" ]) "apps.default")
      (assertCheck "apps.test exists" (has [ "apps" "test" ]) "apps.test")
      (assertCheck "apps.lint exists" (has [ "apps" "lint" ]) "apps.lint")
      (assertCheck "apps.fmt exists" (has [ "apps" "fmt" ]) "apps.fmt")
      (assertCheck "devShells.default exists" (has [ "devShells" "default" ]) "devShells.default")
      (assertCheck "devShells.ci exists" (has [ "devShells" "ci" ]) "devShells.ci")
      (assertCheck "checks.format exists" (has [ "checks" "format" ]) "checks.format")
      (assertCheck "checks.build exists" (has [ "checks" "build" ]) "checks.build")
      (assertCheck "treefmt exists" (has [ "treefmt" ]) "treefmt")
      (assertCheck "treefmt.programs.gofumpt.enabled" (
        has [ "treefmt" "programs" "gofumpt" "enable" ]
      ) "gofumpt.enable")
      (assertCheck "treefmt.programs.goimports.enabled" (
        has [ "treefmt" "programs" "goimports" "enable" ]
      ) "goimports.enable")
      (assertCheck "treefmt.programs.nixfmt.enabled" (
        has [ "treefmt" "programs" "nixfmt" "enable" ]
      ) "nixfmt.enable")
    ];

  overlayCheck =
    let
      overlay = moduleEval.config.flake.overlays.default;
      isOverlay = builtins.isFunction overlay;
    in
    assertCheck "flake.overlays.default exists" isOverlay "function";

  allChecks = optionChecks ++ perSystemChecks ++ [ overlayCheck ];
in
{
  # Run all checks in a single derivation
  moduleTest = pkgs.runCommand "test-module-go-standard" { } ''
    ${builtins.concatStringsSep "\n" allChecks}

    echo ""
    echo "==========================================="
    echo "MODULE TESTS PASSED (${toString (builtins.length allChecks)} checks)"
    echo "==========================================="

    mkdir $out
    echo "all module tests passed" > $out/result.txt
  '';

  # Test enableOverlay=false removes overlay
  moduleTestNoOverlay =
    let
      eval = lib.evalModules {
        modules = [
          ./modules/go-standard.nix
          {
            go-standard = {
              pname = "test-project";
              vendorHash = null;
              enableOverlay = false;
            };
          }
        ];
        specialArgs = {
          inputs = inputs;
          self = { outPath = mockSrc; };
        };
      };
    in
    pkgs.runCommand "test-module-no-overlay" { } ''
      ${
        if !eval.config.flake ? overlays then
          "echo 'PASS: overlay not generated when enableOverlay=false'"
        else
          throw "FAIL: overlay still generated when enableOverlay=false"
      }

      echo "PASS: enableOverlay=false test passed"
      mkdir $out
    '';
}
