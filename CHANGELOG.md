# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

This project has not made a tagged release yet; all changes below are in
`[Unreleased]`.

## [Unreleased]

### Added

- `checks.templ-committed` (eval-time) — throws at `nix flake check` when any
  `.templ` file in the flake source lacks its `*_templ.go` sibling. Nix builds
  vendor the source without running `templ generate`, so an untracked
  generated file breaks the build with `undefined: someFragment`. The flake
  source contains only tracked files, so the walk sees exactly the committed
  set. Zero cost for repos without `.templ` files. Covered by 3 module tests.
- `requireDeps` option (default: `{}`) — passes manually injected require
  lines to mkPreparedSource. Needed when sub-modules have explicit version
  requirements not present in go.mod (e.g. PMA's project-discovery-sdk
  sub-modules). Unblocks projects-management-automation migration.
- Migration guide: common migration patterns section — GOEXPERIMENT recipe,
  proxyVendor warning, cobra completions workaround, requireDeps for
  sub-module pins, custom apps with mkForce, dual treefmt setup.
- All 10 Tier A consumer repos migrated to go-standard: go-localsync,
  erraudit, project-meta, oxlint-auto-configure, project-dependency-graph,
  golangci-lint-auto-configure, go-humanize-linter,
  projects-management-automation, standard-bug-tracking-schema,
  go-auto-upgrade. Average flake.nix reduction: 45%. All eval-verified.
- 4 module adopters cleaned (removed dead `systems`/`treefmt-nix` inputs):
  lean-business-plan, storbi, template-arch-lint, terraform-diagrams-aggregator.
- `enableTestCheck` option (default: false) — generates `checks.test`, a
  hermetic derivation that forces `go test` regardless of `enableCheck`.
  Use when skipping tests during normal builds but running them in CI.
- **G2: per-package `extraBuildAttrs`** in the monorepo `packages` submodule.
  Each entry can now carry its own `extraBuildAttrs` for per-binary
  customization (ldflags, build inputs, phases). Same concatenation semantics
  as the top-level `extraBuildAttrs`. Unblocks StopTube, browser-history,
  BuildFlow, go-structure-linter migration.
- `templateEval` check — evaluates the go-standard template's `outputs`
  function with mock inputs to catch unbound-variable bugs (the class of bug
  fixed in `26b7620` that went undetected since `9471741`).
- `docs/consumer-audit-checklist.md` — systematic criteria for auditing
  downstream consumers: module adoption, input minimalism, private deps wiring,
  redundant override detection, verification commands, and a quick triage
  script for fast first-pass assessment.
- `docs/status/2026-08-10_11-02_consumer-fleet-audit.md` — full audit of all
  34 consumer repos: migration tiers, systemic findings, module gaps, and
  per-repo recommendations.
- `goPkgOverride` option — function applied to the Go package from
  `goPkgAttr`, enabling custom toolchains (e.g. newer patch version than
  nixpkgs ships) without changing the attribute name.
- `lintAsCheck` option (default: false) — also exposes golangci-lint as a
  `checks.lint` derivation (hermetic, for `nix flake check`-driven CI), in
  addition to the `apps.lint` app.
- `LICENSE` file (MIT) with copyright Lars Artmann.
- GitHub Actions CI workflow (`.github/workflows/ci.yml`) with format check,
  integration tests, and module tests.
- `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md`.
- `.github/PULL_REQUEST_TEMPLATE.md` with testing and docs checklist.
- `.github/CODEOWNERS`.
- `CONTRIBUTING.md` with development setup, testing, code style, and PR guide.
- `docs/migration-guide.md` covering mkGoFlake, go-flake-parts, and manual
  mkPreparedSource migration to go-standard.
- `docs/architecture.d2` and `docs/architecture.svg` — visual overview of the
  module flow from consumer inputs to flake outputs.
- README FAQ / Troubleshooting section covering SSH errors, vendorHash
  mismatches, GOPRIVATE issues, and validation errors.
- README architecture diagram section with inlined SVG.
- README monorepo usage example.
- `enableCheck` option to control `doCheck` in `buildGoModule` (default: true).
- `enableOverlay` option to toggle `flake.overlays.default` generation
  (default: true).
- `buildFlags` option for passing build tags to `go build` (default: []).
- `version` option to override git-derived version (default: self.rev or "dev").
- `enableGolangciLint` toggle to conditionally include golangci-lint in
  devShells and the lint app (default: true).
- `enableGofumpt` and `enableGoimports` toggles in treefmt programs
  (default: true for both).
- `enableCompletions` option to install shell completions for the default
  binary (default: false). Requires cobra/urfave/cli — emits a clear warning
  if the binary does not support `--completion`. The completion check uses
  `timeout 10` to prevent hanging binaries from blocking the build.
- `privateGlobPattern` option to `go-standard` — makes the GOPRIVATE glob
  pattern configurable for non-LarsArtmann consumers (default: LarsArtmann
  globs). Backward compatible.
- `publicDeps` parameter to `mkPreparedSource` — list of module paths to
  exclude from private validation, solving the false-positive where public
  LarsArtmann repos are served by `proxy.golang.org` but match the private
  dep pattern. Forwarded through `go-standard` and `mkGoFlake.nix`.
  NOTE: `publicDeps` only affects validation, NOT GOPRIVATE.
- `publicDepsTest` in `test.nix` — integration test verifying that a public
  repo listed in `publicDeps` is not flagged as missing by validation.
- Monorepo support via `packages` option — generates separate `buildGoModule`
  per entry with shared source/vendor hash, separate apps and overlay entries.
- `fmt` app (`nix run .#fmt`) as a treefmt wrapper convenience.
- `systems` option to the go-standard module — no longer hardcoded; defaults
  to the standard 4-system list but can be overridden per consumer.
- `test-module.nix` — module-level test suite with 74 assertions covering
  option existence, types, defaults, perSystem outputs, overlay conditional
  generation, monorepo packages/apps, toggle defaults, version override,
  `publicDeps` exclusion, `privateDepPattern` default, `privateGlobPattern`
  default + custom value, nativeBuildInputs concatenation proof, and
  `extraMeta` propagation.
  Wired as `checks.moduleTest` and `checks.moduleTestNoOverlay`.
- Man pages: `docs/man/go-standard.5` and `docs/man/mkPreparedSource.5`
  documenting all options and parameters. Wired into `devShells.default` via
  a `manPages` derivation that installs `.5` files to `share/man/man5/`.
- Dynamic CI badge in README (replaces static shields.io badge).
- MIT license badge in README.
- `FEATURES.md`, `TODO_LIST.md`, `ROADMAP.md`, and `CHANGELOG.md` to document
  feature inventory, actionable work, long-term direction, and release history.
- `mkPreparedSource.nix` — shared helper that copies flake-input Go deps into
  `_local_deps/` and injects `replace` directives for Nix sandbox builds
  (`775a540`).
- Recursive sub-module auto-discovery; scans dep sources at any depth and skips
  `example`/`examples`/`testdata`/`vendor`/`.git`/`node_modules` directories
  (`befd406`, `7fdb95c`).
- Build-time validation that every private `require` in `go.mod` has a matching
  `replace` directive, producing a clear error instead of the cryptic SSH proxy
  failure (`befd406`).
- `/v2+` major-version suffix handling in `mkPreparedSource` so repos like
  `go-filewatcher/v2` unpack to `_local_deps/go-filewatcher` rather than
  `_local_deps/v2` (`532752a`).
- `/vN` suffix handling in `subModules` replace directives: the version suffix
  is stripped from the local directory path while kept in the module path
  (`7b69382`).
- Generic stale local-replace stripping covering absolute (`/...`), relative
  (`./...`), and sibling (`../...`) paths (`7fdb95c`).
- `go-standard.nix` flake-parts module for one-line adoption via
  `imports = [ inputs.go-nix-helpers.flakeModules.go-standard ]`
  (`3c9426a`, `121eb91`).
- Composite `flakeModules.go-standard` that bundles `treefmt-nix` internally,
  reducing required consumer inputs from five to three
  (`927c924`, `9471741`).
- Self-hosting `flake.nix` with `nix flake check`, `nix fmt`, devShell, lint
  dashboard apps, and `flake.lib.mkPreparedSource` export (`3c22ce4`).
- Integration test suite in `test.nix` covering auto-discovery, explicit-only
  sub-modules, validation of missing deps, publicDeps exclusion, requireDeps
  dedup, and multi-deps monorepo simulation (6 scenarios) (`befd406`, `a31fec9`).
- `scripts/dashboard.sh` for flake-status overview across projects
  (`bc2dfb1`).
- `scripts/nix-lint.sh` for linting `flake.nix` files (`dbb76a0`).
- `scripts/generate-flake.sh` for bootstrapping new Go projects from the
  template (`670b5b6`).
- `templates/go-standard/flake.nix` minimal 3-input template and
  `templates/go-flake-parts/flake.nix` full manual template (`9ebf00d`).
- `docs/flake-patterns.md` and `docs/flake-standard.md` pattern references
  (`dbb76a0`, `d740b3b`).
- `docs/ci-workflow.yml` drop-in GitHub Actions workflow for consumers
  (`dbb76a0`).
- `GOTOOLCHAIN = "local"` set by default in all devShells to prevent Go from
  downloading newer toolchains. Override via `shellExtraEnv.GOTOOLCHAIN`.
- `enableShfmt` option to `go-standard` — enables shell script formatting via
  shfmt in treefmt programs (default: false). Enabled by default in this
  repo's own treefmt config.
- `vendorHash` placeholder detection in `go-standard` — emits a
  `builtins.trace` warning at evaluation time when `vendorHash` matches the
  `sha256-AAA...` placeholder pattern, prompting the consumer to set the
  real hash after the first build.
- `pure-functions.nix` — extracted `stripVersionSuffix` and `repoName` from
  `mkPreparedSource.nix` into a standalone, testable module. Wired as
  `checks.pureFunctions` with 22 assertions covering idempotence,
  no-`/vN`-in-output, determinism, no-slash, and edge cases (`v1`, `v100`,
  empty string, single segment, non-version `v`-prefixes).
- `checks.structural` — derivation verifying that `flakeModules.go-standard`,
  `lib.mkPreparedSource`, and `lib.mkGoFlake` all exist in flake outputs.
- `--dry-run` flag to `generate-flake.sh` — previews file creation without
  writing to disk.
- `--verbose` flag to `generate-flake.sh` — lists all created files after
  generation.
- `--list-templates` flag to `generate-flake.sh` — prints available
  templates and exits.
- Behavioral tests for `buildFlags`, `ldflags` (with version injection),
  custom `ldflags`, and `proxyVendor` propagation in `test-module.nix` —
  proves consumer config reaches the derivation, not just eval.
- Behavioral test for GOPRIVATE injection into devShell — 4 assertions:
  GOPRIVATE present when `deps` set, uses default `privateGlobPattern`,
  uses custom pattern, NOT set when `deps` empty.
- Negative test for `enableCompletions` warning — verifies the "does not
  support the --completion subcommand" message is present in `postInstall`.
- treefmt config inspection test — verifies enabled programs produce
  correct treefmt configuration (3 programs with defaults, 0 when disabled).
- Integration Test 7: `publicDeps` with `/v2` versioned module path in
  `test.nix`.
- FAQ entry in README: "How do I use deps with non-LarsArtmann repos?"
  with code example for overriding `privateDepPattern` and
  `privateGlobPattern`.
- `AGENTS.md` with enduring project context for AI sessions (`3c22ce4`).


- `modules/go-standard.nix`: New `enableNixfmt` option — controls whether
  nixfmt is included in treefmt programs (default: true). Was previously
  hardcoded.
- `modules/go-standard.nix`: `apps.fmt` is now conditional — only generated
  when at least one formatter is enabled (`enableGofumpt`, `enableGoimports`,
  `enableNixfmt`, or `enableTempl`).
- `modules/go-standard.nix`: `enableCompletions` now checks whether the binary
  supports `--completion` before installing, emitting a clear stderr warning
  with remediation options instead of silently doing nothing. The check uses
  `timeout 10` to prevent hanging binaries.
- `modules/go-standard.nix`: `publicDeps` option description now explicitly
  states it only affects validation, not GOPRIVATE.
- `modules/go-standard.nix`: `extraBuildAttrs` option description now
  documents which attributes concatenate vs override.
- `modules/go-standard.nix`: `autoGoPrivateEnv` now uses `cfg.privateGlobPattern`
  instead of a hardcoded glob string.
- `modules/go-standard.nix`: `userExtraBuildAttrs.nativeBuildInputs` is now
  concatenated to the module's list (templ, installShellFiles) rather than
  overriding it.
- `mkPreparedSource.nix`: `requireDeps` entries are now deduped against
  existing `require` lines in go.mod to avoid duplicate entries.
- `mkPreparedSource.nix`: Simplified requireDeps dedup escaping — uses a temp
  file instead of shell variable string manipulation.
- `mkGoFlake.nix`: Deprecation warning now states removal target (v1.0.0).
- `.github/workflows/ci.yml`: Fixed format check to use `--ci` flag (treefmt
  2.x) instead of unsupported `--check`.
- `.github/workflows/ci.yml`: Added macOS runner to check matrix.
- `.github/workflows/ci.yml`: Added smoke-test job for `generate-flake.sh`.
- `.github/workflows/ci.yml`: Added `flake.lock` freshness check job.
- `scripts/generate-flake.sh`: Added `--go-mod` flag (creates go.mod + main.go
  skeleton) and `--private-deps` support for go-standard template. Fixed
  placeholder mismatch bug (`YOUR-PROJECT-NAME` was never replaced).
- `modules/go-standard.nix`: Refactored package building into reusable
  `mkGoPackage` function to support monorepo (multiple packages per repo).
- `modules/go-standard.nix`: `config.systems` now uses `cfg.systems` instead
  of hardcoded `lib.mkDefault defaultSystems`.
- `modules/go-standard.nix`: `version` derivation now uses `cfg.version`
  instead of hardcoded `self.rev or self.dirtyRev or "dev"`.
- `modules/go-standard.nix`: Wired `enableCompletions` `postInstall` properly
  into `mkGoPackage` using per-package name (was dead code).
- `modules/go-standard.nix`: Fixed monorepo overlay to map each package to its
  own derivation instead of the default.
- `modules/go-standard.nix`: `userExtraBuildAttrs` now strips both `preBuild`
  and `postInstall` to avoid double-application when merging consumer overrides.
- `mkPreparedSource.nix`: Validation error message improved — now says
  "modules without local replace" (not "private modules") and offers three
  resolution paths (add as dep, set `validatePrivateDeps = false`, or add
  to `publicDeps`).
- `mkGoFlake.nix`: Now forwards `validatePrivateDeps`, `privateDepPattern`,
  and `publicDeps` to `mkPreparedSource` (previously these escape hatches
  were unreachable through `mkGoFlake`).
- `flake.nix`: `lib.mkGoFlake` export now wraps with `builtins.trace`
  deprecation warning.
- `scripts/generate-flake.sh`: Fully rewritten with `--dir`, `--template`,
  `--no-push` (default), proper `--help`, configurable `PROJECTS_DIR`,
  and support for both `go-standard` and `go-flake-parts` templates.
- `scripts/generate-flake.sh`: Fixed `--templ` flag for go-standard template
  (was a no-op; now uncomments the `enableTempl` line).
- README: Options table expanded with `privateGlobPattern`, `publicDeps`,
  `privateDepPattern` and `extraBuildAttrs` merge rules documentation.
- README: Templates section marks go-flake-parts as deprecated.
- README rewritten as a product-style quickstart with badges, copy-paste
  `flake.nix`, feature tables, and before/after comparison (`0ef8c34`).
- `go-standard` forwarding into `mkPreparedSource` changed from
  `src = cfg.src;` to `inherit (cfg) src;` for internal consistency
  (`00ea4e9`).
- `modules/go-standard.nix`: `extraBuildAttrs` concatenation extended to
  `buildInputs`, `checkInputs`, and `configureFlags` (in addition to the
  existing `nativeBuildInputs`, `preBuild`, `postInstall`). Consumer values
  are now appended rather than overriding.
- `modules/go-standard.nix`: Module test suite deepened from 92 to 99
  assertions — added disabled-state tests for enableTempl=false (alone),
  enableGopls=false, enableGovulncheck=false, and monorepo version
  propagation.
- `mkPreparedSource.nix`: Added `trap 'rm -f go.mod.requires.tmp' EXIT`
  around the temp file lifecycle in `postPatch` for cleanup safety.
- `mkPreparedSource.nix`: `stripVersionSuffix` and `repoName` extracted to
  `pure-functions.nix` and imported, making them independently testable.
- `.github/workflows/ci.yml`: Extended integration-tests job to a matrix
  of `[ubuntu-latest, macos-latest]` with dynamic system detection via
  `nix eval --raw --impure --expr 'builtins.currentSystem'`.
- `.github/workflows/ci.yml`: Added smoke-test steps for `--go-mod`,
  `--private-deps`, and combined `--go-mod --private-deps --templ` variants.
- `docs/architecture.d2` / `.svg`: Updated to show `privateGlobPattern`,
  `enableNixfmt`, `enableShfmt` options (was showing "+20 more").
- `scripts/dashboard.sh`, `scripts/generate-flake.sh`, `scripts/nix-lint.sh`:
  Reformatted with shfmt for consistent style. Fixed unused `CYAN` variable
  in `dashboard.sh`.
- `go-standard` hardcodes the default systems list so consumers do not need a
  `systems` input (`9471741`).
- `docs/migration-guide.md`: Added `enableShfmt`, `enableTempl`, `enableGopls`,
  `enableGovulncheck` to the parameter mapping table. Updated `extraBuildAttrs`
  note to document the 6-attr concatenation semantics.
- `docs/flake-patterns.md`: Added `extraBuildAttrs Merge Rules` section
  documenting all 6 concatenated attributes (nativeBuildInputs, buildInputs,
  checkInputs, configureFlags, preBuild, postInstall) with correct/wrong examples.
- `docs/architecture.d2` / `.svg`: Added `pure-functions.nix` node showing
  `stripVersionSuffix` and `repoName` functions and their import relationship
  to `mkPreparedSource`.
- Pareto plan: Updated P9 from ◑ (partially done) to ✅ (shipped) — CI
  smoke-test coverage for `--dry-run` and `--verbose` flags closes the gap.

### Changed

- `templates/go-standard/flake.nix`: Added monorepo, `goPkgOverride`, and
  `lintAsCheck` examples (in addition to the existing private deps example).
- `templates/go-standard/flake.nix`: Fixed output-fn destructuring bug —
  `inputs@{ self, ... }` referenced unbound `flake-parts`; now destructures
  `flake-parts` explicitly. Generated projects previously failed to evaluate
  (`undefined variable 'flake-parts'`).
- `docs/man/go-standard.5`: Documented `goPkgOverride`, `lintAsCheck`, and
  `checks.lint` output.
- `docs/consumer-audit-checklist.md`: Fixed triage script POSIX-grep portability
  bug (`\s` → `[[:space:]]`) and the fragile two-pass awk flake-false detection
  (now a single awk pass with an explicit WARN marker), tested against
  go-nix-helpers' own flake.nix.
- `docs/migration-guide.md`, `AGENTS.md`: Cross-linked the consumer audit
  checklist for post-migration verification.
- `templates/go-standard/flake.nix`: Added private deps example (flake input
  with `flake = false` + `deps` attrset), `publicDeps` example, and fixed
  misleading `shellExtraEnv.GOPRIVATE` comment (GOPRIVATE is auto-injected
  when `deps` is set; replaced with a `GOTOOLCHAIN` example instead).
- `mkPreparedSource.nix`: `publicDeps` now uses versioned-path-aware matching.
  Listing `github.com/foo/bar` in `publicDeps` also excludes
  `github.com/foo/bar/v2`, `/v3`, etc. from validation. Previously required
  exact-match including the `/vN` suffix.
- `.github/workflows/ci.yml`: Added comments documenting why `--all-systems`
  is not used (Linux cannot evaluate darwin; matrix approach is the workaround)
  and what is needed to enable the private-deps test job.
- `docs/man/mkPreparedSource.5`: Added missing `excludeSubModuleDirs` parameter
  entry — all mkPreparedSource parameters are now documented.
- `TODO_LIST.md`: L10 updated from "theoretical skip" to "empirically rejected"
  after prototyping the extraction (all tests pass, but result adds 11 env vars,
  8 eval calls, and splits logic across 2 files).
- README: Updated `publicDeps` description to reflect versioned-path-aware
  matching (was documented as exact-match only).

### Deprecated

- `mkGoFlake.nix` now emits `builtins.trace` warning directing to migration
  guide. Will be removed in a future release.
- `templates/go-flake-parts/` marked deprecated with banner in README.md
  and deprecation comment in flake.nix header.

### Fixed

- Removed committed `test-result` symlink from git tracking and added it to
  `.gitignore`.
- `repoName` extraction for versioned deps to avoid `_local_deps/v2` collisions
  (`532752a`).
- `subModuleReplace` local directory path for versioned sub-modules such as
  `codec/v2` (`7b69382`).
- `discoverSubModules` recursion and directory exclusion list (`7fdb95c`).
- `stripLocalReplacesScript` missing `../` sibling-directory replaces
  (`7fdb95c`).
- `maintainers.larsartmann` handle in the `go-flake-parts` template, which is
  not registered in nixpkgs and caused evaluation failures (`a31fec9`).
- `nix-lint.sh` `grep -c` counting bug that could emit `0\n0` (`a31fec9`).
- `test.nix` `verify` derivation incorrectly depending on the deliberately
  failing `validationTest` derivation (`a31fec9`).
- Hardcoded `/home/lars/projects` path in `dashboard.sh`; now configurable via
  `PROJECTS_DIR` (`a31fec9`).
- `GOPRIVATE` auto-injection, `validatePrivateDeps`, and `proxyVendor` wiring
  in `go-standard` (`4c9b53c`).
- `docs/man/go-standard.5`: Added missing `postPatchExtra` option entry —
  all 35 module options now documented (was absent since the unified
  pipeline work).
- `docs/man/go-standard.5`: Fixed `extraBuildAttrs` description — stated only
  3 attrs concatenate (`nativeBuildInputs`, `preBuild`, `postInstall`) when all
  6 do since P1 shipped (`buildInputs`, `checkInputs`, `configureFlags` also
  concatenate).

### Removed

- Auto-generated `require` lines for sub-modules, which caused inconsistent
  vendoring errors; replaced by optional `requireDeps` (`89f5236`).
