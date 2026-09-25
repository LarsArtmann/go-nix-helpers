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
  goPkg = pkgs.go_1_27;
};
```

7+ downstream consumers exist (BuildFlow, mr-sync, PMA, go-structure-linter, branching-flow, Standup-Killer, library-policy).

## Build / test commands

```bash
scripts/nix-health.sh               # pre-flight canary: run BEFORE local build verification batches
nix flake check                    # runs all checks (autoDiscovery, explicitOnly, verify, moduleTest, moduleTestNoOverlay, pureFunctions, structural, templateEval, templFixtureGuard, docsAnnotations, treefmt)
nix fmt                            # format all .nix files with nixfmt
nix-build test.nix -A verify       # success-path integration test
nix run .#verifyValidation         # negative-case validation test (run outside sandbox)
nix build .#checks.x86_64-linux.moduleTest  # module-level test (139 assertions)
nix build .#checks.x86_64-linux.pureFunctions  # pure function property tests (61 checks)
nix build .#checks.x86_64-linux.structural     # structural output verification
```

## Architecture

- **`mkPreparedSource.nix`** — the core helper. Takes `{pkgs, lib, goPkg}` then `{name, src, deps, ...}`. Returns a derivation that produces a patched source tree.
- **`mkGoFlake.nix`** (DEPRECATED) — shared flake-parts module. Superseded by go-standard module. Takes a config attrset with `{inputs, self, pname, version, vendorHash, description, src, deps, ...}`. Returns a flake-parts module attrset with packages, apps, devShells, checks, treefmt, and overlay.
- **Composite module** — `flake.flakeModules.go-standard` in `flake.nix` is a composite module (function of `{config}`) importing `[ treefmt-nix.flakeModule ./modules/go-standard.nix ]` PLUS mapping `config.systems = config.go-standard.systems`, so the go-standard `systems` option is the single systems knob. This bundles treefmt-nix so consumers don't need it as a separate input. treefmt-nix's flakeModule only uses `pkgs` from the consuming context, so re-exporting via a composite is seamless.
- **`systems` is configurable and WIRED** — go-standard exposes a `systems` option (default = `[ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ]`, i.e. `nix-systems/default` minus `x86_64-darwin`, which nixpkgs 26.11 dropped); the composite maps it onto flake-parts' `systems`, which actually gates output generation. (Until 2026-09-25 the option was documented but never consumed — flake-parts' own default silently won.) Consumers override via `go-standard.systems = [...]` or `go-standard.systems = import inputs.systems;`.
- **`goPkgAttr` defaults to auto (null)** — resolves to the newest packaged `go_1_XX` branch in the consumer's nixpkgs via `pure-functions.nix`'s `newestGoAttrName` (numeric compare; falls back to `pkgs.go`). Replaces the hardcoded `go_1_26` default, which lagged every Go release and silently broke builds when a repo's go.mod floor moved past it (GOTOOLCHAIN=local forbids toolchain downloads in the sandbox). When even the newest nixpkgs branch is too old, `goTarballVersion`/`goTarballHash` builds Go from the go.dev source tarball.
- **Module options (44 total)** — go-standard supports: `enableCheck`, `enableTestCheck`, `enableOverlay`, `buildFlags`, `version`, `enableGolangciLint`, `enableGofumpt`, `enableGoimports`, `enableNixfmt`, `enableShfmt`, `enableTempl`, `enableGopls`, `enableGovulncheck`, `enableCompletions`, `completionStyle`, `goExperiment`, `cgoEnabled`, `packages` (monorepo, with per-package `extraBuildAttrs`), `validatePrivateDeps`, `privateDepPattern`, `publicDeps`, `privateGlobPattern`, `goPkgOverride`, `goTarballVersion`, `goTarballHash`, `lintAsCheck`, `requireDeps`. tested by `test-module.nix` (139 assertions). `cgoEnabled` emits Go's canonical `0`/`1` for CGO_ENABLED (Nix's `toString false` is `""`, which Go treats as unset).
- **Monorepo support** — the `packages` option generates separate `buildGoModule` per entry, each with its own `subPackages` and `description`. Shared config (vendorHash, deps, goPkg) comes from the top-level go-standard config. Backward compatible — when `packages` is empty (default), single-package behavior is unchanged.
- **Recursive auto-discovery (build-time)** — discovers ALL `go.mod` files at any depth in dep sources during the BUILD phase (not during Nix evaluation), reads the module path, and generates replace directives automatically. Excludes example/testdata/vendor directories. Moving discovery to build-time avoids `builtins.readDir`/`builtins.readFile` on derivation outputs, which would force those derivations to be built during evaluation and break `nix flake check --no-build`.
- **Two-phase sub-module pipeline** — explicit `subModules` entries are mapped into `{modulePath, localDir}` pairs and handled at EVAL time; auto-discovered sub-modules are found by a shell script during `postPatch` at BUILD time. Both phases generate the same replace-directive shape and version normalization; dedup between them is a `grep -qF` check. (Restructured 2026-08-12 when discovery moved to build time; the pre-2026-06-19 4-way split brain no longer exists.)
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
- **Auto-discovery happens at BUILD TIME, not eval time** — `mkPreparedSource` generates a shell script that scans `_local_deps/` for `go.mod` files during `postPatch`. This means `nix flake check --no-build` works without building dep derivations. Explicit `subModules` are still handled at eval time (they don't read from store paths).
- **`postPatchExtra` runs BEFORE replace directives are injected** — consumers needing to read the generated replaces must account for this ordering.
- **`GOTOOLCHAIN = "local"` is set by default** in all devShells — prevents Go from downloading newer toolchains. Override via `shellExtraEnv.GOTOOLCHAIN` if needed.
- **`mkGoFlake.nix` emits `builtins.trace` deprecation warning** — the flake.nix export wraps with a trace message directing to the migration guide. Will be removed in a future release.
- **`templates/go-flake-parts/` is deprecated** — marked with banner in README and deprecation comment in flake.nix header. Use `templates/go-standard/` instead.
- **Module tests use `lib.evalModules` with stub options** — `test-module.nix` evaluates the go-standard module in isolation by providing flake-parts infrastructure stubs (`systems`, `perSystem`, `flake`, `packages`, `apps`, `devShells`, `checks`, `treefmt`). The `perSystem` function is then evaluated as its own module to check outputs.
- **`lib.mkIf` returns a wrapped value, not a plain function** — when testing overlays conditional on `enableOverlay`, you must unwrap the `{ _type = "if"; condition = bool; content = fn; }` structure. See `test-module.nix` `overlayCheck` for the pattern.
- **`test-assets/mock-templ-missing-generated/web/home_templ.go` must NEVER be committed** — the templ-committed fixture needs that file absent; the auto-commit daemon re-adding it turns `moduleTest` red (`attribute 'templ-committed' missing` hard-evals out of the whole check). It is gitignored now — if moduleTest fails with that error, check `git ls-files test-assets/mock-templ-missing-generated/` first.
- **Nix 2.34: tryEval cannot recover thrown messages** — `toString` of a tryEval-captured error is `""`. Never write content assertions like `hasInfix ... (toString result.value)`; assert against a pure message builder (see `goModFloorMessage`), flattened derivation attrs, or the throw-site source text instead. Eight such assertions shipped never-green on 2026-09-24/25 and hid a real `cgoEnabled` bug (`toString false` is `""` → CGO_ENABLED unset → cgo silently re-enabled; now canonical `0`/`1`).
- **`mkDerivation` consumes the `env` attrset but flattens its entries** — after `buildGoModule ({ ... env = { FOO = "bar"; }; })`, `pkg ? env` is false but `pkg.FOO == "bar"`. Read flattened attrs, not `.env`.
- **Clean-worktree verification recipe (daemon + GC race)** — `nix flake check` on dirty trees under the auto-commit daemon intermittently fails with `path ...-source is not valid` (dirty-copy GC). Recipe: `git worktree add /tmp/x HEAD && cd /tmp/x && nix flake check --no-build`, or commit first. Also: chain `git add -A && git commit -m ...` in ONE command — the daemon races separate add/commit pairs (verify by commit SUBJECT, not hash).
- **Host binfmt/GC incident (2026-09-25)** — after a daemon restart, `/run/binfmt` vanished while `/etc/nix/nix.conf` `extra-sandbox-paths` still referenced it: EVERY local build failed until `systemctl restart systemd-binfmt.service` (root). Combined with auto-GC (`max-free=30G`), `nix flake check` also deleted unrooted source copies mid-check. Run `scripts/nix-health.sh` before local verification batches; CI is unaffected — push (with owner approval) and let CI be the oracle when the host is down. Full writeup: `docs/postmortems/2026-09-25_lock-bump-and-silent-host-break.md`.

## Key files

| File                                 | Purpose                                                                                                                                            |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `mkPreparedSource.nix`               | Core helper — solves private Go dep injection for Nix sandbox builds                                                                               |
| `pure-functions.nix`                 | `stripVersionSuffix`, `repoName`, `newestGoAttrName`, `staleGoAttrName`, `goModFloorMessage`, `goBaseFrom` — standalone, testable pure functions used by mkPreparedSource, the goPkgAttr auto default, and eval-time checks |
| `test-pure-functions.nix`            | 61 checks: idempotence, no-`/vN`-in-output, determinism, edge cases, newestGoAttrName, staleGoAttrName, goModFloorMessage, goBaseFrom — wired as `checks.pureFunctions` |
| `mkGoFlake.nix`                      | DEPRECATED — function-based predecessor to go-standard module; emits trace warning                                                                 |
| `modules/go-standard.nix`            | Proper flake-parts module (exposed as `flakeModules.go-standard`) — 44 options, monorepo support, bundles treefmt-nix                              |
| `flake.nix`                          | Self-hosting: checks, formatter, devShell, lib export, flakeModules export                                                                         |
| `test.nix`                           | Integration tests (auto-discovery, explicit, validation, publicDeps, requireDeps dedup, multi-deps monorepo, publicDeps /v2, in-tree replace stripping, pseudo-version normalization — 9 scenarios) |
| `test-module.nix`                    | Module-level tests for go-standard options and outputs (139 assertions)                                                                            |
| `templates/go-flake-parts/flake.nix` | DEPRECATED — old manual template; marked with deprecation banner                                                                                   |
| `templates/go-standard/flake.nix`    | Minimal template using go-standard module (recommended for new projects)                                                                           |
| `scripts/nix-lint.sh`                | Lints flake.nix files across all projects for common errors                                                                                        |
| `scripts/nix-health.sh`              | Pre-flight canary for local build batches: binfmt mount vs nix.conf, daemon age, auto-GC exposure, store headroom                                  |
| `scripts/check-docs-annotations.sh` + `check-rows.py` | Docs-annotation gates (archived completeness + table row uniformity), vendored from the docs-health skill with attribution; wired as `checks.docsAnnotations` |
| `scripts/dashboard.sh`               | Overview of flake check status across all projects                                                                                                 |
| `scripts/generate-flake.sh`          | Bootstrap new projects; configurable with `--dir`, `--template`, `--no-push`, `--dry-run`, `--verbose`, `--list-templates`                         |
| `docs/migration-guide.md`            | Migration guide: mkGoFlake/go-flake-parts/manual → go-standard                                                                                     |
| `docs/architecture.d2` / `.svg`      | Architecture diagram: consumer inputs → module → outputs                                                                                           |
| `docs/man/go-standard.5`             | Man page documenting all go-standard module options                                                                                                |
| `docs/man/mkPreparedSource.5`        | Man page documenting all mkPreparedSource parameters                                                                                               |
| `docs/flake-patterns.md`             | Reference: correct patterns and anti-patterns                                                                                                      |
| `docs/consumer-audit-checklist.md`   | 8-section audit criteria + triage script for verifying consumer repos use go-standard superbly                                                     |
| `.github/workflows/ci.yml`           | GitHub Actions CI: format check, integration tests, module tests, smoke tests, flake.lock freshness — ubuntu + macOS matrix                        |
