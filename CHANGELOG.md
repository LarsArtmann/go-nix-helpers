# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

This project has not made a tagged release yet; all changes below are in
`[Unreleased]`.

## [Unreleased]

### Added

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
  binary (default: false). Requires cobra/urfave/cli — silently does nothing
  if the binary does not support `--completion`.
- `publicDeps` parameter to `mkPreparedSource` — list of module paths to
  exclude from private validation, solving the false-positive where public
  LarsArtmann repos are served by `proxy.golang.org` but match the private
  dep pattern. Forwarded through `go-standard` and `mkGoFlake.nix`.
- `publicDepsTest` in `test.nix` — integration test verifying that a public
  repo listed in `publicDeps` is not flagged as missing by validation.
- Monorepo support via `packages` option — generates separate `buildGoModule`
  per entry with shared source/vendor hash, separate apps and overlay entries.
- `fmt` app (`nix run .#fmt`) as a treefmt wrapper convenience.
- `systems` option to the go-standard module — no longer hardcoded; defaults
  to the standard 4-system list but can be overridden per consumer.
- `test-module.nix` — module-level test suite with 57 assertions covering
  option existence, types, defaults, perSystem outputs, overlay conditional
  generation, monorepo packages/apps, toggle defaults, version override,
  `publicDeps` exclusion, and `privateDepPattern` default.
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
  sub-modules, and validation of missing deps (`befd406`, `a31fec9`).
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
- `AGENTS.md` with enduring project context for AI sessions (`3c22ce4`).

### Changed

- `modules/go-standard.nix`: New `enableNixfmt` option — controls whether
  nixfmt is included in treefmt programs (default: true). Was previously
  hardcoded.
- `modules/go-standard.nix`: `apps.fmt` is now conditional — only generated
  when at least one formatter is enabled (`enableGofumpt`, `enableGoimports`,
  `enableNixfmt`, or `enableTempl`).
- `modules/go-standard.nix`: `enableCompletions` now checks whether the binary
  supports `--completion` before installing, emitting a clear stderr warning
  with remediation options instead of silently doing nothing.
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
- README: Options table expanded with all new options.
- README: Templates section marks go-flake-parts as deprecated.
- README rewritten as a product-style quickstart with badges, copy-paste
  `flake.nix`, feature tables, and before/after comparison (`0ef8c34`).
- `go-standard` forwarding into `mkPreparedSource` changed from
  `src = cfg.src;` to `inherit (cfg) src;` for internal consistency
  (`00ea4e9`).
- `go-standard` hardcodes the default systems list so consumers do not need a
  `systems` input (`9471741`).

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

### Removed

- Auto-generated `require` lines for sub-modules, which caused inconsistent
  vendoring errors; replaced by optional `requireDeps` (`89f5236`).
