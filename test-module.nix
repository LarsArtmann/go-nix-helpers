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
      inherit inputs;
      self = mockSelf;
    };
  };

  cfg = moduleEval.config.go-standard;

  # The perSystem function from go-standard, evaluated as a proper module
  perSystemFn = moduleEval.config.perSystem;

  perSystemEval = lib.evalModules {
    modules = [
      perSystemStubOptions
      (if builtins.isFunction perSystemFn then perSystemFn else _: perSystemFn)
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
    (assertCheck "goPkgOverride default is identity" (
      (cfg.goPkgOverride pkgs.go_1_26) == pkgs.go_1_26
    ) "identity function")
    (assertCheck "lintAsCheck default is false" (cfg.lintAsCheck == false) "false")
    (assertCheck "enableTestCheck default is false" (cfg.enableTestCheck == false) "false")
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
    (assertCheck "enableCompletions default is false" (cfg.enableCompletions == false) "false")
    (assertCheck "packages default is empty" (cfg.packages == { }) "{}")
    (assertCheck "autoGoPrivate default is true" (cfg.autoGoPrivate == true) "true")
    (assertCheck "privateGlobPattern default is LarsArtmann glob" (
      cfg.privateGlobPattern == "github.com/larsartmann/*,github.com/LarsArtmann/*"
    ) "LarsArtmann glob")
    (assertCheck "validatePrivateDeps default is true" (cfg.validatePrivateDeps == true) "true")
    (assertCheck "privateDepPattern default is LarsArtmann regex" (
      cfg.privateDepPattern == "github\\.com/[Ll]ars[Aa]rtmann/"
    ) "LarsArtmann regex")
    (assertCheck "publicDeps default is empty" (cfg.publicDeps == [ ]) "[]")
    (assertCheck "proxyVendor default is true" (cfg.proxyVendor == true) "true")
    (assertCheck "systems default is 4-element list" (builtins.length cfg.systems == 4) "4 systems")
    (assertCheck "systems includes x86_64-linux" (builtins.elem "x86_64-linux" cfg.systems)
      "x86_64-linux in list"
    )
    (assertCheck "ldflags default is null" (cfg.ldflags == null) "null")
    (assertCheck "extraMeta default is empty" (cfg.extraMeta == { }) "{}")
    (assertCheck "extraBuildAttrs default is empty" (cfg.extraBuildAttrs == { }) "{}")
    (assertCheck "shellExtraEnv default is empty" (cfg.shellExtraEnv == { }) "{}")
    (assertCheck "enableNixfmt default is true" (cfg.enableNixfmt == true) "true")
    (assertCheck "enableShfmt default is false" (cfg.enableShfmt == false) "false")
    (assertCheck "devShellExtraPackages default returns empty list" (
      builtins.length (cfg.devShellExtraPackages pkgs) == 0
    ) "empty list when called")
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

  # Helper: evaluate perSystem output with a custom go-standard config.
  mkPerSystemConfig =
    extraConfig:
    let
      modEval = lib.evalModules {
        modules = [
          flakePartsStub
          ./modules/go-standard.nix
          {
            go-standard = {
              pname = "test-project";
              vendorHash = null;
            }
            // extraConfig;
          }
        ];
        specialArgs = {
          inherit inputs;
          self = mockSelf;
        };
      };
      perSysEval = lib.evalModules {
        modules = [
          perSystemStubOptions
          (
            let
              fn = modEval.config.perSystem;
            in
            if builtins.isFunction fn then fn else _: fn
          )
        ];
        specialArgs = {
          inherit pkgs lib;
          config = perSysEval.config or { };
        };
      };
    in
    perSysEval.config;

  # --- Monorepo tests ------------------------------------------------------
  monorepoCfg = mkPerSystemConfig {
    packages.worker.subPackages = [ "cmd/worker" ];
    packages.worker.description = "Worker binary";
  };

  # --- Per-package extraBuildAttrs (G2) test --------------------------------
  perPackageExtraCfg = mkPerSystemConfig {
    packages.worker.subPackages = [ "cmd/worker" ];
    packages.worker.extraBuildAttrs.passthru.g2test = "per-pkg-override-works";
  };

  # --- Per-package + top-level extraBuildAttrs merge (G2 concat test) -------
  perPackageMergeCfg = mkPerSystemConfig {
    extraBuildAttrs.nativeBuildInputs = [ pkgs.git ];
    packages.worker.subPackages = [ "cmd/worker" ];
    packages.worker.extraBuildAttrs.nativeBuildInputs = [ pkgs.makeWrapper ];
  };

  # --- No-lint tests -------------------------------------------------------
  noLintCfg = mkPerSystemConfig { enableGolangciLint = false; };

  # --- Formatter toggle tests ----------------------------------------------
  noFmtCfg = mkPerSystemConfig {
    enableGofumpt = false;
    enableGoimports = false;
  };

  # --- Version override test -----------------------------------------------
  versionCfg = mkPerSystemConfig { version = "1.0.0-test"; };

  # --- Completions test ----------------------------------------------------
  completionsCfg = mkPerSystemConfig { enableCompletions = true; };

  # --- buildFlags test -----------------------------------------------------
  buildFlagsCfg = mkPerSystemConfig {
    buildFlags = [
      "-tags"
      "integration"
    ];
  };

  # --- publicDeps test ------------------------------------------------------
  publicDepsCfg = mkPerSystemConfig {
    publicDeps = [
      "github.com/larsartmann/go-atomic-write"
      "github.com/larsartmann/go-ndjson"
    ];
  };

  # --- privateGlobPattern custom value test ---------------------------------
  customGlobCfg = mkPerSystemConfig {
    privateGlobPattern = "github.com/myorg/*,github.com/MyOrg/*";
  };

  # --- GOPRIVATE behavioral test: deps triggers GOPRIVATE injection --------
  # When deps is non-empty, GOPRIVATE should be injected into the devShell.
  # We use a mock dep path — the devShell doesn't trigger mkPreparedSource
  # (lazy evaluation), so no real dep source is needed.
  goprivateCfg = mkPerSystemConfig {
    deps = {
      "github.com/larsartmann/mock-dep" = mockSrc;
    };
  };

  # --- GOPRIVATE with custom privateGlobPattern + deps --------------------
  goprivateCustomGlobCfg = mkPerSystemConfig {
    deps = {
      "github.com/larsartmann/mock-dep" = mockSrc;
    };
    privateGlobPattern = "github.com/myorg/*,github.com/MyOrg/*";
  };

  # --- enableNixfmt toggle test ---------------------------------------------
  noNixfmtCfg = mkPerSystemConfig { enableNixfmt = false; };

  # --- enableShfmt toggle test ----------------------------------------------
  shfmtCfg = mkPerSystemConfig { enableShfmt = true; };

  # --- enableTempl=false alone (other formatters still on) -------------------
  noTemplCfg = mkPerSystemConfig { enableTempl = false; };

  # --- enableGopls=false -----------------------------------------------------
  noGoplsCfg = mkPerSystemConfig { enableGopls = false; };

  # --- enableGovulncheck=false -----------------------------------------------
  noVulncheckCfg = mkPerSystemConfig { enableGovulncheck = false; };

  # --- Monorepo + version propagation ----------------------------------------
  monorepoVersionCfg = mkPerSystemConfig {
    version = "2.0.0-mono";
    packages.worker.subPackages = [ "cmd/worker" ];
    packages.worker.description = "Worker";
  };

  # --- All formatters disabled (apps.fmt should disappear) ------------------
  noAllFmtCfg = mkPerSystemConfig {
    enableGofumpt = false;
    enableGoimports = false;
    enableNixfmt = false;
    enableTempl = false;
  };

  # --- enableTempl test -----------------------------------------------------
  templCfg = mkPerSystemConfig { enableTempl = true; };

  # --- goPkgOverride test ---------------------------------------------------
  goPkgOverrideCfg = mkPerSystemConfig {
    goPkgOverride =
      pkg:
      pkg.overrideAttrs (_: {
        version = "1.26.4-custom";
      });
  };

  # --- lintAsCheck test ------------------------------------------------------
  lintAsCheckCfg = mkPerSystemConfig { lintAsCheck = true; };

  # --- enableTestCheck test --------------------------------------------------
  enableTestCheckCfg = mkPerSystemConfig { enableTestCheck = true; };

  # --- nativeBuildInputs merge test (user inputs appended, not overridden) ---
  nativeBuildInputsMergeCfg = mkPerSystemConfig {
    enableTempl = true;
    extraBuildAttrs.nativeBuildInputs = [ pkgs.git ];
  };

  # --- buildInputs merge test (concatenation, not override) ---
  buildInputsMergeCfg = mkPerSystemConfig {
    extraBuildAttrs.buildInputs = [ pkgs.sqlite ];
  };

  # --- checkInputs merge test (concatenation, not override) ---
  checkInputsMergeCfg = mkPerSystemConfig {
    extraBuildAttrs.checkInputs = [ pkgs.sqlite ];
  };

  # --- configureFlags merge test (concatenation, not override) ---
  configureFlagsMergeCfg = mkPerSystemConfig {
    extraBuildAttrs.configureFlags = [ "--with-feature" ];
  };

  # --- vendorHash placeholder test (M3) — evaluates with placeholder hash ---
  vendorHashPlaceholderCfg = mkPerSystemConfig {
    vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # --- Custom ldflags test --------------------------------------------------
  customLdflagsCfg = mkPerSystemConfig {
    ldflags = [ "-X main.version=custom" ];
  };

  # --- Extra meta propagation test ------------------------------------------
  extraMetaCfg = mkPerSystemConfig {
    extraMeta = {
      homepage = "https://example.com";
    };
  };

  # --- Custom shellExtraEnv test --------------------------------------------
  customEnvCfg = mkPerSystemConfig {
    shellExtraEnv = {
      CUSTOM_ENV = "test-value";
    };
  };

  # --- Systems override test (module-level) ---------------------------------
  systemsOverrideCheck =
    let
      sysEval = lib.evalModules {
        modules = [
          flakePartsStub
          ./modules/go-standard.nix
          {
            go-standard = {
              pname = "test-project";
              vendorHash = null;
              systems = [ "x86_64-linux" ];
            };
          }
        ];
        specialArgs = {
          inherit inputs;
          self = mockSelf;
        };
      };
    in
    assertCheck "systems override propagates to config.systems" (
      sysEval.config.systems == [ "x86_64-linux" ]
    ) "systems = [x86_64-linux]";

  # --- Monorepo overlay test (verifies D1 fix) -----------------------------
  monorepoOverlayCheck =
    let
      mockSelfMono = {
        outPath = mockSrc;
        packages.x86_64-linux = {
          default = "mock-default-derivation";
          test-project = "mock-default-derivation";
          worker = "mock-worker-derivation";
        };
      };
      modEval = lib.evalModules {
        modules = [
          flakePartsStub
          ./modules/go-standard.nix
          {
            go-standard = {
              pname = "test-project";
              vendorHash = null;
              packages.worker.subPackages = [ "cmd/worker" ];
              packages.worker.description = "Worker binary";
            };
          }
        ];
        specialArgs = {
          inherit inputs;
          self = mockSelfMono;
        };
      };
      rawOverlay = modEval.config.flake.overlays.default or null;
      overlay =
        if rawOverlay ? _type && rawOverlay._type == "if" then
          (if rawOverlay.condition then rawOverlay.content else null)
        else
          rawOverlay;
      overlayResult =
        if overlay != null && builtins.isFunction overlay then
          overlay { stdenv.system = "x86_64-linux"; } { }
        else
          null;
      workerMapsCorrectly =
        overlayResult != null && overlayResult ? worker && overlayResult.worker == "mock-worker-derivation";
    in
    assertCheck "monorepo overlay maps worker to its own derivation" workerMapsCorrectly
      "overlayResult.worker = mock-worker-derivation";

  additionalChecks = [
    (assertCheck "monorepo: packages.worker exists" (monorepoCfg.packages ? worker) "packages.worker")
    (assertCheck "monorepo: apps.worker exists" (monorepoCfg.apps ? worker) "apps.worker")
    (assertCheck "enableGolangciLint=false removes lint app" (!(noLintCfg.apps ? lint)) "no apps.lint")
    (assertCheck "enableGofumpt=false disables gofumpt" (
      noFmtCfg.treefmt.programs.gofumpt.enable or true == false
    ) "gofumpt.enable = false")
    (assertCheck "enableGoimports=false disables goimports" (
      noFmtCfg.treefmt.programs.goimports.enable or true == false
    ) "goimports.enable = false")
    (assertCheck "version override propagates to package name" (
      versionCfg.packages.default ? name && lib.hasInfix "1.0.0-test" versionCfg.packages.default.name
    ) "version in package name")
    (assertCheck "enableCompletions=true evaluates successfully" (
      completionsCfg.packages ? default
    ) "packages.default with completions")
    # --- M8: enableCompletions warning text in postInstall ----------------
    # The warning message must be present in the derivation's postInstall
    # script so it fires at build time when the binary lacks --completion.
    (assertCheck "enableCompletions: warning text present in postInstall" (
      let
        pkg = completionsCfg.packages.default;
        postInstall = pkg.postInstall or pkg.drvAttrs.postInstall or "";
      in
      lib.hasInfix "does not support the --completion subcommand" postInstall
    ) "warning text in postInstall")
    (assertCheck "enableCompletions: installShellFiles in nativeBuildInputs" (
      let
        pkg = completionsCfg.packages.default;
        inputs = pkg.nativeBuildInputs or pkg.drvAttrs.nativeBuildInputs or [ ];
        hasInstallShellFiles = builtins.any (
          x:
          x.pname or x.name or "" == "install-shell-files"
          || lib.hasInfix "install-shell-files" (x.name or "")
          || lib.hasInfix "installShellFiles" (x.name or "")
        ) inputs;
      in
      hasInstallShellFiles
    ) "installShellFiles in nativeBuildInputs")
    (assertCheck "buildFlags accepts custom flags" (
      buildFlagsCfg.packages ? default
    ) "packages.default with custom buildFlags")
    # --- Behavioral: buildFlags reaches derivation (M7) -------------------
    (assertCheck "buildFlags reaches derivation" (
      let
        pkg = buildFlagsCfg.packages.default;
        flags = pkg.buildFlags or pkg.drvAttrs.buildFlags or [ ];
      in
      flags == [
        "-tags"
        "integration"
      ]
    ) "[-tags integration] in .buildFlags")
    # --- Behavioral: ldflags reaches derivation with version (M7) ---------
    (assertCheck "ldflags reaches derivation with version injection" (
      let
        pkg = versionCfg.packages.default;
        flags = pkg.ldflags or pkg.drvAttrs.ldflags or [ ];
        hasVersionFlag = builtins.any (f: lib.hasInfix "-X main.version=" f) flags;
      in
      hasVersionFlag
    ) "-X main.version= in .ldflags")
    # --- Behavioral: custom ldflags reach derivation (M7) -----------------
    (assertCheck "custom ldflags reach derivation" (
      let
        pkg = customLdflagsCfg.packages.default;
        flags = pkg.ldflags or pkg.drvAttrs.ldflags or [ ];
      in
      builtins.elem "-X main.version=custom" flags
    ) "-X main.version=custom in .ldflags")
    # --- Behavioral: proxyVendor reaches derivation (M7) ------------------
    (assertCheck "proxyVendor=true reaches derivation" (
      let
        pkg = psCfg.packages.default;
        pv = pkg.proxyVendor or pkg.drvAttrs.proxyVendor or null;
      in
      pv == true
    ) "proxyVendor = true in derivation")
    (assertCheck "publicDeps accepts list of module paths" (
      publicDepsCfg.packages ? default
    ) "packages.default with publicDeps")
    (assertCheck "privateGlobPattern accepts custom value" (
      customGlobCfg.packages ? default
    ) "packages.default with custom privateGlobPattern")
    # --- Behavioral: nativeBuildInputs concatenation (D5) ------------------
    # Verify that BOTH module inputs (templ) AND user inputs (git) appear
    # in the final derivation's nativeBuildInputs, proving concatenation
    # rather than silent override.
    (assertCheck "nativeBuildInputs merge: templ present in derivation" (
      let
        pkg = nativeBuildInputsMergeCfg.packages.default;
        inputs = pkg.nativeBuildInputs or pkg.drvAttrs.nativeBuildInputs or [ ];
        hasTempl = builtins.any (
          x: x.pname or x.name or "" == "templ" || lib.hasInfix "templ" (x.name or "")
        ) inputs;
      in
      hasTempl
    ) "templ in nativeBuildInputs")
    (assertCheck "nativeBuildInputs merge: git present in derivation" (
      let
        pkg = nativeBuildInputsMergeCfg.packages.default;
        inputs = pkg.nativeBuildInputs or pkg.drvAttrs.nativeBuildInputs or [ ];
        hasGit = builtins.any (
          x: x.pname or x.name or "" == "git" || lib.hasInfix "git" (x.name or "")
        ) inputs;
      in
      hasGit
    ) "git in nativeBuildInputs")
    # --- Behavioral: buildInputs concatenation (H3) -----------------------
    # Verify user buildInputs appear in the final derivation, proving
    # concatenation works (not silent override via //).
    (assertCheck "buildInputs merge: sqlite present in derivation" (
      let
        pkg = buildInputsMergeCfg.packages.default;
        inputs = pkg.buildInputs or pkg.drvAttrs.buildInputs or [ ];
        hasSqlite = builtins.any (
          x: x.pname or x.name or "" == "sqlite" || lib.hasInfix "sqlite" (x.name or "")
        ) inputs;
      in
      hasSqlite
    ) "sqlite in buildInputs")
    # --- Behavioral: checkInputs concatenation (H3) -----------------------
    # checkInputs are processed by mkDerivation internally (added to
    # nativeBuildInputs during check phase), so we verify at eval level.
    # The extraction code path is identical to buildInputs/configureFlags,
    # which ARE tested behaviorally above.
    (assertCheck "checkInputs merge: evaluates with user inputs" (
      checkInputsMergeCfg.packages ? default
    ) "packages.default with merged checkInputs")
    # --- Behavioral: configureFlags concatenation (H3) --------------------
    (assertCheck "configureFlags merge: flag present in derivation" (
      let
        pkg = configureFlagsMergeCfg.packages.default;
        flags = pkg.configureFlags or pkg.drvAttrs.configureFlags or [ ];
      in
      builtins.elem "--with-feature" flags
    ) "--with-feature in configureFlags")
    # --- vendorHash placeholder evaluates with warning (M3) ----------------
    (assertCheck "vendorHash placeholder evaluates successfully" (
      vendorHashPlaceholderCfg.packages ? default
    ) "packages.default with placeholder vendorHash")
    # --- Behavioral: meta propagation (H2) ---------------------------------
    (assertCheck "meta.description matches config" (
      psCfg.packages.default ? meta && psCfg.packages.default.meta.description == "Test project"
    ) "description='Test project' in meta")
    (assertCheck "meta.mainProgram matches pname" (
      psCfg.packages.default ? meta && psCfg.packages.default.meta.mainProgram == "test-project"
    ) "mainProgram='test-project'")
    (assertCheck "meta.license is MIT" (
      psCfg.packages.default ? meta && psCfg.packages.default.meta.license.spdxId or "" == "MIT"
    ) "MIT license")
    (assertCheck "meta.maintainers includes LarsArtmann" (
      let
        maintainers = psCfg.packages.default.meta.maintainers or [ ];
        hasLars = builtins.any (m: m.github or "" == "LarsArtmann") maintainers;
      in
      hasLars
    ) "LarsArtmann in maintainers")
    (assertCheck "extraMeta propagates to package meta" (
      extraMetaCfg.packages.default ? meta && extraMetaCfg.packages.default.meta ? homepage
    ) "homepage in meta from extraMeta")
    (assertCheck "monorepo: worker has correct description in meta" (
      monorepoCfg.packages.worker ? meta
      && monorepoCfg.packages.worker.meta.description == "Worker binary"
    ) "worker description='Worker binary'")
    # --- Toggle and conditional tests (L1) ---------------------------------
    (assertCheck "enableNixfmt=false disables nixfmt" (
      noNixfmtCfg.treefmt.programs.nixfmt.enable or true == false
    ) "nixfmt.enable = false")
    (assertCheck "enableShfmt=true enables shfmt in treefmt" (
      shfmtCfg.treefmt.programs.shfmt.enable or false == true
    ) "shfmt.enable = true")
    # --- M10: Treefmt config inspection (all defaults) --------------------
    (assertCheck "treefmt.programs has 3 default programs" (
      let
        allPrograms = builtins.attrValues psCfg.treefmt.programs;
        enabledPrograms = lib.filter (cfg: cfg.enable or false == true) allPrograms;
      in
      builtins.length enabledPrograms == 3
    ) "3 enabled programs (gofumpt, goimports, nixfmt)")
    # --- M10: Treefmt config inspection (all disabled) --------------------
    (assertCheck "treefmt: no programs when all disabled" (
      let
        allPrograms = builtins.attrValues noAllFmtCfg.treefmt.programs;
        enabledPrograms = lib.filter (cfg: cfg.enable or false == true) allPrograms;
      in
      builtins.length enabledPrograms == 0
    ) "0 enabled programs")
    (assertCheck "apps.fmt removed when all formatters disabled" (
      !(noAllFmtCfg.apps ? fmt)
    ) "no apps.fmt when no formatters")
    (assertCheck "enableTempl=true enables templ in treefmt" (
      templCfg.treefmt.programs.templ.enable or false == true
    ) "templ.enable = true")
    # --- enableTempl=false alone (other formatters still on) -----------------
    (assertCheck "enableTempl=false disables templ in treefmt" (
      noTemplCfg.treefmt.programs.templ.enable or true == false
    ) "templ.enable = false")
    (assertCheck "enableTempl=false keeps gofumpt enabled" (
      noTemplCfg.treefmt.programs.gofumpt.enable or false == true
    ) "gofumpt.enable = true")
    (assertCheck "enableTempl=false keeps apps.fmt (other formatters on)" (
      noTemplCfg.apps ? fmt
    ) "apps.fmt exists")
    # --- enableGopls=false evaluates successfully ---------------------------
    (assertCheck "enableGopls=false evaluates without error" (
      noGoplsCfg.devShells ? default
    ) "devShell evaluates")
    # --- enableGovulncheck=false evaluates successfully ----------------------
    (assertCheck "enableGovulncheck=false evaluates without error" (
      noVulncheckCfg.devShells ? default
    ) "devShell evaluates")
    # --- Monorepo + version propagation --------------------------------------
    (assertCheck "monorepo: version propagates to default package" (
      monorepoVersionCfg.packages.default ? name
      && lib.hasInfix "2.0.0-mono" monorepoVersionCfg.packages.default.name
    ) "version 2.0.0-mono in default package name")
    (assertCheck "monorepo: version propagates to worker package" (
      monorepoVersionCfg.packages.worker ? name
      && lib.hasInfix "2.0.0-mono" monorepoVersionCfg.packages.worker.name
    ) "version 2.0.0-mono in worker package name")
    (assertCheck "nativeBuildInputs merge: package evaluates with user inputs" (
      nativeBuildInputsMergeCfg.packages ? default
    ) "packages.default with merged nativeBuildInputs")
    (assertCheck "custom ldflags evaluate successfully" (
      customLdflagsCfg.packages ? default
    ) "packages.default with custom ldflags")
    (assertCheck "shellExtraEnv evaluates with custom vars" (
      customEnvCfg.devShells ? default
    ) "devShell with custom env")
    # --- Behavioral: GOPRIVATE injection into devShell (H2) ----------------
    # With deps set, GOPRIVATE should be injected with the default glob.
    (assertCheck "GOPRIVATE injected into devShell when deps set" (
      goprivateCfg.devShells.default ? GOPRIVATE
    ) "GOPRIVATE in devShell")
    (assertCheck "GOPRIVATE uses default privateGlobPattern" (
      goprivateCfg.devShells.default.GOPRIVATE or ""
      == "github.com/larsartmann/*,github.com/LarsArtmann/*"
    ) "default glob in GOPRIVATE")
    (assertCheck "GOPRIVATE uses custom privateGlobPattern" (
      goprivateCustomGlobCfg.devShells.default.GOPRIVATE or "" == "github.com/myorg/*,github.com/MyOrg/*"
    ) "custom glob in GOPRIVATE")
    # Without deps, GOPRIVATE should NOT be set
    (assertCheck "GOPRIVATE not set when deps empty" (
      !(psCfg.devShells.default ? GOPRIVATE)
    ) "no GOPRIVATE without deps")
    # --- Behavioral: goPkgOverride applies to the package Go version ---
    (assertCheck "goPkgOverride applies to packages.default" (
      let
        # goDrv is the actual derivation; compare version attr if available
        goDrv = goPkgOverrideCfg.packages.default.go or null;
        hasCustomVersion =
          goDrv != null
          && ((goDrv.version or "") == "1.26.4-custom" || lib.hasInfix "1.26.4-custom" (goDrv.name or ""));
      in
      hasCustomVersion
    ) "go version 1.26.4-custom in derivation")
    (assertCheck "goPkgOverride applies to devShell" (
      let
        shell = goPkgOverrideCfg.devShells.default;
        inputs = shell.nativeBuildInputs or shell.buildInputs or [ ];
        hasCustomGo = builtins.any (x: lib.hasInfix "1.26.4-custom" (x.name or "")) inputs;
      in
      hasCustomGo
    ) "custom go in devShell nativeBuildInputs")
    # --- Behavioral: lintAsCheck exposes checks.lint ---------------------
    (assertCheck "lintAsCheck=false has no checks.lint" (
      !(psCfg.checks ? lint)
    ) "no checks.lint by default")
    (assertCheck "lintAsCheck=true exposes checks.lint" (
      lintAsCheckCfg.checks ? lint
    ) "checks.lint exists")
    (assertCheck "lintAsCheck=true keeps apps.lint" (
      lintAsCheckCfg.apps ? lint
    ) "apps.lint still exists")
    (assertCheck "lintAsCheck gated on enableGolangciLint" (
      !(
        (mkPerSystemConfig {
          lintAsCheck = true;
          enableGolangciLint = false;
        }).checks ? lint
      )
    ) "no checks.lint when enableGolangciLint=false")
    # --- G2: per-package extraBuildAttrs ----------------------------------
    (assertCheck "packages.<name>.extraBuildAttrs option default is {}" (
      let
        testEval = lib.evalModules {
          modules = [
            flakePartsStub
            ./modules/go-standard.nix
            {
              go-standard = {
                pname = "test";
                vendorHash = null;
                packages.foo.subPackages = [ "." ];
              };
            }
          ];
          specialArgs = {
            inherit inputs;
            self = mockSelf;
          };
        };
      in
      testEval.config.go-standard.packages.foo.extraBuildAttrs or "MISSING" == { }
    ) "empty default")
    (assertCheck "G2: per-package extraBuildAttrs evaluates without error" (
      perPackageExtraCfg.packages ? worker
    ) "worker package exists")
    (assertCheck "G2: per-package override key flows through" (
      perPackageExtraCfg.packages.worker.passthru.g2test or "MISSING" == "per-pkg-override-works"
    ) "passthru value visible in worker package")
    (assertCheck "G2: per-package + top-level concat evaluates" (
      perPackageMergeCfg.packages ? worker
    ) "worker package with merged attrs exists")
    # --- Behavioral: enableTestCheck exposes checks.test ----------------------
    (assertCheck "enableTestCheck=false has no checks.test" (
      !(psCfg.checks ? test)
    ) "no checks.test by default")
    (assertCheck "enableTestCheck=true exposes checks.test" (
      enableTestCheckCfg.checks ? test
    ) "checks.test exists")
    systemsOverrideCheck
    monorepoOverlayCheck
  ];

  allChecks = optionChecks ++ perSystemChecks ++ [ overlayCheck ] ++ additionalChecks;
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
          inherit inputs;
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
