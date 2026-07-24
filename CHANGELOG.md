# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

This project has not made a tagged release yet; all changes below are in
`[Unreleased]`.

## [Unreleased]

### Added

- `FEATURES.md`, `TODO_LIST.md`, `ROADMAP.md`, and `CHANGELOG.md` to document
  feature inventory, actionable work, long-term direction, and release history.

### Fixed

- Removed committed `test-result` symlink from git tracking and added it to
  `.gitignore`.

### Added

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
- `AGENTS.md` with enduring project context for AI sessions (`3c22ce4`).

### Changed

- README rewritten as a product-style quickstart with badges, copy-paste
  `flake.nix`, feature tables, and before/after comparison (`0ef8c34`).
- `go-standard` forwarding into `mkPreparedSource` changed from
  `src = cfg.src;` to `inherit (cfg) src;` for internal consistency
  (`00ea4e9`).
- `go-standard` hardcodes the default systems list so consumers do not need a
  `systems` input (`9471741`).

### Deprecated

- `mkGoFlake.nix` function-based predecessor superseded by the `go-standard`
  flake-parts module (`ee8c5b3`).

### Fixed

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
