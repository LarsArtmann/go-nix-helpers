# go-nix-helpers — AGENTS.md

Shared Nix helpers for LarsArtmann Go repositories. This is a **Nix library**, not a Go application — it contains no Go code.

## What this project does

This repo provides Nix helpers for LarsArtmann Go projects:

1. **`modules/go-standard.nix`** (RECOMMENDED) — A flake-parts module exposed as `flakeModules.go-standard`. Provides standard flake outputs (packages, apps, devShells, checks, treefmt, overlay) via typed options. **Bundles `treefmt-nix` internally** — consumers need only 3 inputs (nixpkgs, flake-parts, go-nix-helpers). No `treefmt-nix` or `systems` input required. One-line adoption: `imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];`. Requires go-nix-helpers as a **real flake** input (not `flake = false`).

2. **`mkPreparedSource.nix`** — Solves private Go dependency injection for Nix sandbox builds. Go repos with private dependencies can't fetch them inside the Nix sandbox (no SSH, no network). This helper copies flake-input deps into `_local_deps/` and injects `replace` directives into `go.mod`. Used automatically by go-standard when `deps = { ... }` is set.

3. **`mkGoFlake.nix`** (DEPRECATED) — Function-based predecessor to go-standard. Use the module instead.

## Consumption pattern

### Recommended: go-standard module (3 inputs)

```nix
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
};

outputs = inputs@{ self, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];
    go-standard = {
      pname = "my-project";
      vendorHash = "sha256-...";
      description = "What it does";
    };
  };
```

treefmt-nix and systems are bundled internally by the composite module — no need to declare them as inputs.

### Lower-level: raw import (flake = false)

For projects that only need mkPreparedSource without the full module:

```nix
inputs.go-nix-helpers = {
  url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
  flake = false;
};
# ...
mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
  inherit pkgs lib;
  goPkg = pkgs.go_1_26;
};
```

7+ downstream consumers exist (BuildFlow, mr-sync, PMA, go-structure-linter, branching-flow, Standup-Killer, library-policy).

## Build / test commands

```bash
nix flake check                    # runs all checks (autoDiscovery, explicitOnly, verify, moduleTest, moduleTestNoOverlay, pureFunctions, structural, treefmt)
nix fmt                            # format all .nix files with nixfmt
nix-build test.nix -A verify       # success-path integration test
nix run .#verifyValidation         # negative-case validation test (run outside sandbox)
nix build .#checks.x86_64-linux.moduleTest  # module-level test (106 assertions)
nix build .#checks.x86_64-linux.pureFunctions  # pure function property tests (22 assertions)
nix build .#checks.x86_64-linux.structural     # structural output verification
```

## Architecture

- **`mkPreparedSource.nix`** — the core helper. Takes `{pkgs, lib, goPkg}` then `{name, src, deps, ...}`. Returns a derivation that produces a patched source tree.
- **`mkGoFlake.nix`** (DEPRECATED) — shared flake-parts module. Superseded by go-standard module. Takes a config attrset with `{inputs, self, pname, version, vendorHash, description, src, deps, ...}`. Returns a flake-parts module attrset with packages, apps, devShells, checks, treefmt, and overlay.
- **Composite module** — `flake.flakeModules.go-standard` in `flake.nix` is a composite module `{ imports = [ treefmt-nix.flakeModule ./modules/go-standard.nix ]; }`. This bundles treefmt-nix so consumers don't need it as a separate input. treefmt-nix's flakeModule only uses `pkgs` from the consuming context, so re-exporting via a composite is seamless.
- **`systems` is now configurable** — go-standard exposes a `systems` option (default = `[ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]` matching `nix-systems/default`). Consumers can override via `go-standard.systems = [...]` or `go-standard.systems = import inputs.systems;`.
- **Module options (37 total)** — go-standard supports: `enableCheck`, `enableOverlay`, `buildFlags`, `version`, `enableGolangciLint`, `enableGofumpt`, `enableGoimports`, `enableNixfmt`, `enableShfmt`, `enableTempl`, `enableGopls`, `enableGovulncheck`, `enableCompletions`, `packages` (monorepo), `validatePrivateDeps`, `privateDepPattern`, `publicDeps`, `privateGlobPattern`, `goPkgOverride`, `lintAsCheck`. All with sensible defaults, tested by `test-module.nix` (110 assertions).
- **Monorepo support** — the `packages` option generates separate `buildGoModule` per entry, each with its own `subPackages` and `description`. Shared config (vendorHash, deps, goPkg) comes from the top-level go-standard config. Backward compatible — when `packages` is empty (default), single-package behavior is unchanged.
- **Recursive auto-discovery** — walks each dep source recursively to find ALL `go.mod` files at any depth (not just top-level), reads the module path, and generates replace directives automatically. Excludes example/testdata/vendor directories.
- **Unified sub-module pipeline** — explicit `subModules` entries are mapped into the same `{modulePath, localDir}` shape as auto-discovered ones, then a single replace generator and single version normalizer process both. (Unified 2026-06-19; previously was a split brain with 4 duplicate code paths.)
- **`/vN` handling** — `stripVersionSuffix` filters ALL `/vN` segments from local directory paths (e.g. `event/v3/eventtest` → `event/eventtest`), while keeping the full versioned module path in replace directives.
- **Local-path stripping** — `stripLocalReplacesScript` strips all absolute (`/home/...`) and relative (`./...`, `../...`) replace directives before appending fresh `./_local_deps/` replaces.
- **Build-time validation** — verifies every private module require has a matching replace directive, failing with a clear message instead of the cryptic SSH error.

## Gotchas

- **`maintainers.larsartmann` is NOT registered in nixpkgs** — but works in `meta.maintainers` because Nix evaluation is lazy enough that `nix flake check` and builds pass. The attribute is never deeply evaluated during normal operations. Register in nixpkgs for full correctness (nix-env --maintainer queries).
- **`goPkg` parameter is dead weight** — the derivation has `dontBuild = true` and never invokes `go`. Kept for API compatibility.
- **`privateDepPattern` default is LarsArtmann-specific** — `validatePrivateDeps` only validates modules matching `github\.com/[Ll]ars[Aa]rtmann/` by default. Override for other orgs. Use `publicDeps` to exclude specific public repos that match the pattern but resolve via proxy.golang.org (e.g. go-atomic-write, go-ndjson, go-sse).
- **Six `extraBuildAttrs` keys are concatenated** — `nativeBuildInputs`, `buildInputs`, `checkInputs`, `configureFlags`, `preBuild`, `postInstall`: consumer values are appended to the module's list rather than overriding. All other keys use `//` override.
- **`validationTest` is a deliberately-failing derivation** — it cannot be a Nix dependency of a passing derivation. The `verify` check only tests success paths; `verifyValidation` is a separate shell script run outside the sandbox.
- **`apps.fmt` is conditional** — only generated when at least one treefmt program is enabled (`enableGofumpt`, `enableGoimports`, `enableNixfmt`, `enableTempl`).
- **`enableCompletions` warns instead of silently no-op** — when the binary doesn't support `--completion`, a clear warning is printed to stderr during the build instead of silently installing empty completions.
- **`requireDeps` deduplicates** — manually injected require lines are checked against existing entries in go.mod to avoid duplicates.
- **Composite module eliminates treefmt-nix + systems inputs** — consumers declaring these inputs won't break (harmless unused inputs), but they're no longer required. The `systems` input can still be used by setting `go-standard.systems = import inputs.systems;`.
- **`postPatchExtra` runs BEFORE replace directives are injected** — consumers needing to read the generated replaces must account for this ordering.
- **`GOTOOLCHAIN = "local"` is set by default** in all devShells — prevents Go from downloading newer toolchains. Override via `shellExtraEnv.GOTOOLCHAIN` if needed.
- **`mkGoFlake.nix` emits `builtins.trace` deprecation warning** — the flake.nix export wraps with a trace message directing to the migration guide. Will be removed in a future release.
- **`templates/go-flake-parts/` is deprecated** — marked with banner in README and deprecation comment in flake.nix header. Use `templates/go-standard/` instead.
- **Module tests use `lib.evalModules` with stub options** — `test-module.nix` evaluates the go-standard module in isolation by providing flake-parts infrastructure stubs (`systems`, `perSystem`, `flake`, `packages`, `apps`, `devShells`, `checks`, `treefmt`). The `perSystem` function is then evaluated as its own module to check outputs.
- **`lib.mkIf` returns a wrapped value, not a plain function** — when testing overlays conditional on `enableOverlay`, you must unwrap the `{ _type = "if"; condition = bool; content = fn; }` structure. See `test-module.nix` `overlayCheck` for the pattern.

## Key files

| File                                 | Purpose                                                                                                               |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `mkPreparedSource.nix`               | Core helper — solves private Go dep injection for Nix sandbox builds                                                  |
| `pure-functions.nix`                 | Extracted `stripVersionSuffix` and `repoName` — standalone, testable pure functions used by mkPreparedSource          |
| `test-pure-functions.nix`            | 22 assertions: idempotence, no-`/vN`-in-output, determinism, edge cases — wired as `checks.pureFunctions`              |
| `mkGoFlake.nix`                      | DEPRECATED — function-based predecessor to go-standard module; emits trace warning                                    |
| `modules/go-standard.nix`            | Proper flake-parts module (exposed as `flakeModules.go-standard`) — 37 options, monorepo support, bundles treefmt-nix |
| `flake.nix`                          | Self-hosting: checks, formatter, devShell, lib export, flakeModules export                                            |
| `test.nix`                           | Integration tests (auto-discovery, explicit, validation, publicDeps, requireDeps dedup, multi-deps monorepo, publicDeps /v2 — 7 scenarios) |
| `test-module.nix`                    | Module-level tests for go-standard options and outputs (106 assertions)                                                |
| `templates/go-flake-parts/flake.nix` | DEPRECATED — old manual template; marked with deprecation banner                                                      |
| `templates/go-standard/flake.nix`    | Minimal template using go-standard module (recommended for new projects)                                              |
| `scripts/nix-lint.sh`                | Lints flake.nix files across all projects for common errors                                                           |
| `scripts/dashboard.sh`               | Overview of flake check status across all projects                                                                    |
| `scripts/generate-flake.sh`          | Bootstrap new projects; configurable with `--dir`, `--template`, `--no-push`, `--dry-run`, `--verbose`, `--list-templates` |
| `docs/migration-guide.md`            | Migration guide: mkGoFlake/go-flake-parts/manual → go-standard                                                        |
| `docs/architecture.d2` / `.svg`      | Architecture diagram: consumer inputs → module → outputs                                                              |
| `docs/man/go-standard.5`             | Man page documenting all go-standard module options                                                                   |
| `docs/man/mkPreparedSource.5`        | Man page documenting all mkPreparedSource parameters                                                                  |
| `docs/flake-patterns.md`             | Reference: correct patterns and anti-patterns                                                                         |
| `docs/consumer-audit-checklist.md`  | 8-section audit criteria + triage script for verifying consumer repos use go-standard superbly                          |
| `.github/workflows/ci.yml`           | GitHub Actions CI: format check, integration tests, module tests, smoke tests, flake.lock freshness — ubuntu + macOS matrix |
