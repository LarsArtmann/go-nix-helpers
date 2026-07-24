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
    cat > $out/main.go <<'EOF'
    package main
    func main() {}
    EOF
  '';

  mockSelf = {
    outPath = mockSrc;
  };

  # Minimal flake-parts infrastructure stubs for module evaluation.
  flakePartsStub = {
    options = {
      systems = lib.mkOption {
        type = lib.types.anything;
        default = [ ];
      };
      perSystem = lib.mkOption {
        type = lib.types.anything;
        default = { };
      };
      flake = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
    };
  };

  # PerSystem stub options (packages, apps, devShells, checks, treefmt)
  perSystemStubOptions = {
    options = {
      packages = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
      apps = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
      devShells = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
      checks = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
      treefmt = {
        projectRootFile = lib.mkOption {
          type = lib.types.str;
          default = "flake.nix";
        };
        programs = lib.mkOption {
          type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
          default = { };
        };
        build = {
          wrapper = lib.mkOption {
            type = lib.types.package;
            default = pkgs.hello;
          };
          check = lib.mkOption {
            type = lib.types.anything;
            default = _: pkgs.emptyDirectory;
          };
        };
      };
    };
  };

  # Evaluate the go-standard module to extract options and the perSystem function
  moduleEval = lib.evalModules {
    modules = [
      flakePartsStub
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
      self = mockSelf;
    };
  };

  cfg = moduleEval.config.go-standard;

  # The perSystem function from go-standard, evaluated as a proper module
  perSystemFn = moduleEval.config.perSystem;

  perSystemEval = lib.evalModules {
    modules = [
      perSystemStubOptions
      (if builtins.isFunction perSystemFn then perSystemFn else { config, ... }: perSystemFn)
    ];
    specialArgs = {
      inherit pkgs lib;
      config = perSystemEval.config or { };
    };
  };

  psCfg = perSystemEval.config;

  # Check helper: assert a condition and return a message
  assertCheck =
    name: condition: expected:
    if condition then
      "echo 'PASS: ${name}'"
    else
      "echo 'FAIL: ${name} — expected ${expected}' && exit 1";

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
    (assertCheck "systems default is 4-element list" (builtins.length cfg.systems == 4) "4 systems")
    (assertCheck "systems includes x86_64-linux" (builtins.elem "x86_64-linux" cfg.systems)
      "x86_64-linux in list"
    )
    (assertCheck "ldflags default is null" (cfg.ldflags == null) "null")
    (assertCheck "extraMeta default is empty" (cfg.extraMeta == { }) "{}")
    (assertCheck "extraBuildAttrs default is empty" (cfg.extraBuildAttrs == { }) "{}")
    (assertCheck "shellExtraEnv default is empty" (cfg.shellExtraEnv == { }) "{}")
  ];

  perSystemChecks = [
    (assertCheck "packages.default exists" (psCfg.packages ? default) "packages.default")
    (assertCheck "packages.test-project exists" (psCfg.packages ? test-project) "packages.test-project")
    (assertCheck "apps.default exists" (psCfg.apps ? default) "apps.default")
    (assertCheck "apps.test exists" (psCfg.apps ? test) "apps.test")
    (assertCheck "apps.lint exists" (psCfg.apps ? lint) "apps.lint")
    (assertCheck "apps.fmt exists" (psCfg.apps ? fmt) "apps.fmt")
    (assertCheck "devShells.default exists" (psCfg.devShells ? default) "devShells.default")
    (assertCheck "devShells.ci exists" (psCfg.devShells ? ci) "devShells.ci")
    (assertCheck "checks.format exists" (psCfg.checks ? format) "checks.format")
    (assertCheck "checks.build exists" (psCfg.checks ? build) "checks.build")
    (assertCheck "treefmt.programs.gofumpt.enabled" (
      psCfg.treefmt.programs.gofumpt.enable or false == true
    ) "gofumpt.enable = true")
    (assertCheck "treefmt.programs.goimports.enabled" (
      psCfg.treefmt.programs.goimports.enable or false == true
    ) "goimports.enable = true")
    (assertCheck "treefmt.programs.nixfmt.enabled" (
      psCfg.treefmt.programs.nixfmt.enable or false == true
    ) "nixfmt.enable = true")
  ];

  overlayCheck =
    let
      rawOverlay = moduleEval.config.flake.overlays.default or null;
      # lib.mkIf wraps the value in { _type = "if"; condition = true; content = fn; }
      overlay =
        if rawOverlay ? _type && rawOverlay._type == "if" then
          (if rawOverlay.condition then rawOverlay.content else null)
        else
          rawOverlay;
      isOverlay = overlay != null && builtins.isFunction overlay;
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
          flakePartsStub
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
          self = mockSelf;
        };
      };
      rawOverlay = eval.config.flake.overlays.default or null;
      # When enableOverlay=false, mkIf wraps with condition=false
      # The overlay attr still exists but condition is false
      hasOverlay =
        if rawOverlay ? _type && rawOverlay._type == "if" then rawOverlay.condition else rawOverlay != null;
    in
    pkgs.runCommand "test-module-no-overlay" { } ''
      ${
        if !hasOverlay then
          "echo 'PASS: overlay not generated when enableOverlay=false'"
        else
          "echo 'FAIL: overlay still generated when enableOverlay=false' && exit 1"
      }

      echo "PASS: enableOverlay=false test passed"
      mkdir $out
    '';
}
