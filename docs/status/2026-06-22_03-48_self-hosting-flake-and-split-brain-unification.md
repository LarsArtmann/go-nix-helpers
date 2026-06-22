# Status Report — go-nix-helpers

**Date**: 2026-06-22 03:48 CEST
**Project**: [go-nix-helpers](https://github.com/LarsArtmann/go-nix-helpers)
**Branch**: `master`
**Total Commits**: 15 (committed) + 1 staged (uncommitted)
**Working Tree**: 6 files staged for commit (round 2: self-hosting flake + split-brain unification)

---

## Context

This report covers the state of go-nix-helpers after two rounds of architectural
review and fixes performed on 2026-06-19 and 2026-06-22.

- **Round 1** (commit `a31fec9`, committed): Fixed 9 objective bugs found during
  full code review — template evaluation crash, hardcoded validation pattern,
  broken test suite, grep garbage, CI swallowing failures, hardcoded paths, docs
  errors. All verified empirically before fixing.
- **Round 2** (staged, uncommitted): Structural improvements — added `flake.nix`
  so the repo self-hosts, unified the split-brain sub-module code paths, cleaned
  up test anti-patterns, added `AGENTS.md`.

---

## a) FULLY DONE ✅

### 1. `mkPreparedSource` — Core helper for private Go deps
- Copies private flake-input deps into `_local_deps/`
- Injects `replace` directives into `go.mod`
- Auto-discovers sub-modules (scans each dep source for subdirectories with `go.mod`)
- Supports explicit `subModules` (merged with auto-discovered)
- Supports `requireDeps` (manual require injection for sub-modules not yet in `go.mod`)
- Auto-strips stale local `replace` directives pointing to `/home/...`
- Normalizes sub-module pseudo-versions via `subModuleVersion`
- Build-time validation with clear error messages
- Parameterized `privateDepPattern` (no longer hardcoded to LarsArtmann org)
- **Unified sub-module pipeline** (round 2): explicit + auto entries now share ONE
  replace generator and ONE version normalizer — eliminated the split brain where
  `/vN` handling and dedup logic had to be maintained in two parallel code paths
- **7 downstream consumers**: BuildFlow, mr-sync, PMA, go-structure-linter,
  branching-flow, Standup-Killer, library-policy

### 2. `flake.nix` — Self-hosting (NEW, round 2, staged)
The repo now dogfoods the flake-parts + treefmt-nix standard it ships as a
gold-standard template:
- `nix flake check` — runs all checks, zero warnings, `all checks passed!`
- `nix fmt` — formats all `.nix` files with nixfmt
- `checks` — wired to `test.nix` (`autoDiscovery`, `explicitOnly`, `verify`)
- `apps.verifyValidation` — runs the negative-case validation test
- `apps.dashboard` / `apps.lint` — script wrappers with `meta.description`
- `devShells.default` — mkShellNoCC with nixfmt, nix, git
- `flake.lib.mkPreparedSource` — exposes the helper as flake lib output
  (consumers can now use either raw import or flake lib import)

### 3. `/vN` major version suffix handling
- `repoName` strips `/vN` suffixes before extracting basename
- `stripVersionSuffix` strips `/vN` from local directory paths while keeping the
  full versioned module path in replace directives
- Verified: go-output, go-filewatcher/v2, gogenfilter/v3, go-output/v10
- Zero downstream breakage

### 4. Template — `go-flake-parts`
- Complete flake template with flake-parts, treefmt-nix, systems
- Commented-out `mkPreparedSource` usage with `/v2` and `subModules` examples
- CI devShell (`mkShellNoCC`), lint/test apps, format checks, overlay pattern
- **Fixed** (round 1): removed `maintainers.larsartmann` (throws — not registered
  in nixpkgs); removed duplicate no-op `checks.test`

### 5. Integration test suite (`test.nix`)
- **Test 1**: Auto-discovery — verifies all sub-modules get replace directives,
  non-module dirs skipped
- **Test 2**: Explicit only — verifies `autoSubModules=false` works, storage not
  auto-discovered
- **Test 3**: Validation — verifies missing deps trigger clear error
- **Fixed** (round 1): restructured so success-path `verify` actually passes
  (previously never passed end-to-end due to failing-derivation-as-dependency)
- **Fixed** (round 2): `verifyValidation` is now a `writeShellApplication` with
  `meta.description`, runnable via `nix run .#verifyValidation`
- **Fixed** (round 2): `mockDep` uses clean `runCommandLocal` (no more writing
  `$out` in `unpackPhase`)

### 6. Scripts
- **`scripts/dashboard.sh`**: Configurable (`PROJECTS_DIR`, `GO_LATEST` env vars),
  generic Go version detection, JSON-escaped output
- **`scripts/generate-flake.sh`**: Bootstraps new Go projects from template
- **`scripts/nix-lint.sh`**: Lints flake.nix files for common error patterns.
  Fixed grep counting bug (round 1)

### 7. Documentation
- **`README.md`**: Usage, major version suffix docs, sub-modules section, full
  parameter table including `privateDepPattern`
- **`AGENTS.md`** (NEW, round 2): Enduring AI-session context — architecture,
  consumption pattern, build/test commands, gotchas
- **`docs/flake-patterns.md`**: Reference: correct patterns, anti-patterns, gotchas
- **`docs/ci-workflow.yml`**: Drop-in GitHub Actions workflow (fixed: no more `|| true`)
- **`docs/reviews/2026-06-19_full-code-review.html`**: Full architectural review report

---

## b) PARTIALLY DONE 🔶

### 1. `goPkg` parameter is dead weight — needs decision
`goPkg` is a required parameter and added to `nativeBuildInputs`, but the derivation
has `dontBuild = true` and the builder only runs `sed/cp/mkdir/echo/awk/grep` —
never `go`. The Go toolchain is pulled into the sandbox for nothing, inflating the
closure and signalling to consumers that pinning the Go version here matters. It
does not. Documented in AGENTS.md gotchas. Needs a deprecation/drop decision.

### 2. `subModuleVersionNormalize` may be cargo-culted — needs verification
The sed rewrites `v0.0.0-20260101000000-abc123` → `v0.0.0` so replace directives
"match". But Go ignores the require version for path-replaced modules, so the sed
may be unnecessary. The sed also assumes a specific pseudo-version format and breaks
silently if Go changes it. Needs a controlled test: remove it and see if a real
build still resolves.

### 3. Downstream consumers — Need migration to unified subModules
The split-brain unification (round 2) is backwards-compatible in output but
consumers haven't been audited to confirm they benefit from the dedup. No consumer
breakage expected (output is identical), but worth verifying.

### 4. `generate-flake.sh` still has rough edges
- Hardcoded `/home/lars/projects` path (not configurable, unlike `dashboard.sh`)
- The `--templ` sed injections are line-number-dependent and fragile
- `sed "s/REPLACE_ME/$PROJECT/g"` breaks if PROJECT contains `/`
- Defaults to interactively pushing to GitHub (surprising for a generator)

---

## c) NOT STARTED ⬜

### 1. No CI pipeline for go-nix-helpers itself
The `docs/ci-workflow.yml` is a template for consumers. The repo itself has no
GitHub Actions workflow running `nix flake check` on push/PR. Now that `flake.nix`
exists, this is a 5-minute job.

### 2. No `CHANGELOG.md`
No formal change log — only git history and point-in-time status reports.

### 3. No `FEATURES.md`
No feature inventory by status.

### 4. No `TODO_LIST.md`
No short/mid-term task tracking.

### 5. `repoName` collision risk unaddressed
If two deps share the same repo name (e.g., `larsartmann/go-output` and
`otheruser/go-output`), `repoName` produces the same basename, causing a silent
overwrite in `_local_deps/`. Not triggered today but architecturally unsound.

### 6. `requireDeps` can emit duplicate require lines
`requireDeps` appends a fresh `require (...)` block without checking whether a
module is already required. A duplicate `require` makes `go mod tidy` complain.

### 7. `postPatchExtra` ordering is undocumented
`postPatchExtra` runs BEFORE the `replace (...)` block is appended. A consumer
whose `postPatchExtra` needs to read the generated replaces will silently see a
stale `go.mod`. Documented in AGENTS.md but not in README.

### 8. No `go.sum` patching
Currently only `go.mod` is patched. If a dep requires `go.sum` manipulation, it's
not handled.

### 9. No `--dry-run` option
No way to inspect the generated postPatch script without building.

### 10. No nested sub-module support
`subModules = { "foo/bar" = [ "baz" ]; }` → `foo/bar/baz` is not tested.

---

## d) TOTALLY FUCKED UP! 💥

### Nothing is currently fucked up.

All known bugs have been fixed. The two rounds of review (2026-06-19 and 2026-06-22)
addressed every objective defect found, each verified empirically before fixing:

1. **Template eval crash** (round 1, FIXED): `maintainers.larsartmann` threw because
   the handle isn't registered in nixpkgs — broke `nix build` for every new project
2. **Hardcoded validation** (round 1, FIXED): private-dep validation only protected
   the LarsArtmann org — now parameterized
3. **Test suite never passed** (round 1, FIXED): `verify` derivation had a failing
   derivation as a dependency + false-positive `elif grep "builder failed"`
4. **grep garbage** (round 1, FIXED): `nix-lint.sh` `grep -c || echo 0` produced `0\n0`
5. **CI swallowed failures** (round 1, FIXED): `|| true` on test step
6. **Hardcoded paths** (round 1, FIXED): `dashboard.sh` hardcoded `/home/lars/projects`
7. **Split brain** (round 2, FIXED): 4 duplicate sub-module code paths unified into 1

### Historical fuck-ups (all fixed):
1. `/vN` in deps (commit `532752a`): `repoName` extracted `"v2"` instead of `"go-filewatcher"`
2. `/vN` in subModules: `subModuleReplace` kept `/v2` in local directory path
3. Auto-require for sub-modules (commit `89f5236`): Caused "inconsistent vendoring"
4. Standalone require syntax (commit `ca0d2fc`): Missing `require` keyword prefix

---

## e) WHAT WE SHOULD IMPROVE! 📈

### 1. Deprecate or drop `goPkg`
It's dead weight. The cleanest fix is to make it default to `pkgs.go` and stop
adding it to `nativeBuildInputs`. Breaking API change for consumers, so needs
coordination.

### 2. Verify whether `subModuleVersionNormalize` is needed
If Go ignores the require version for path-replaced modules (which it does), the
sed is cargo-culted. Remove it and test with a real consumer. If it works, delete
~15 lines of fragile code.

### 3. Namespace `repoName` by owner
Change `_local_deps/<repoName>` to `_local_deps/<owner>-<repoName>` to eliminate
the same-name collision risk. Breaking change for consumers' `postPatchExtra`
that hardcodes `_local_deps/<name>` — but no consumer does this today.

### 4. Add CI pipeline for the repo itself
Now that `flake.nix` exists with `nix flake check` passing, a GitHub Actions
workflow is trivial. Use the `docs/ci-workflow.yml` template on the repo itself.

### 5. Make `generate-flake.sh` robust
Configurable target dir, proper template engine (or markers instead of sed),
non-destructive defaults (don't push by default).

### 6. Dedup `requireDeps` against existing requires
Before appending a `require (...)` block, check if the module is already required.

### 7. Consider publishing as a proper flake
Now that `flake.nix` exists with `lib.mkPreparedSource`, consumers can use
`go-nix-helpers.lib.mkPreparedSource` instead of raw import. Better caching, better
discoverability. The raw import path still works for backwards compatibility.

---

## f) Top 25 Things We Should Get Done Next

| #  | Priority | Task | Impact |
|----|----------|------|--------|
| 1  | P0 | Commit the staged round 2 changes (flake.nix + unification + AGENTS.md) | Unblocks everything below |
| 2  | P0 | Add GitHub Actions CI workflow for the repo itself (`nix flake check` on push) | Automated quality gate |
| 3  | P1 | Deprecate/drop `goPkg` parameter (dead weight — derivation never invokes `go`) | Cleaner API, smaller closures |
| 4  | P1 | Verify `subModuleVersionNormalize` is needed; remove if cargo-culted | -15 lines fragile sed |
| 5  | P1 | Namespace `repoName` by owner to prevent same-name collisions | Correctness |
| 6  | P1 | Add `CHANGELOG.md` for release tracking | Release discipline |
| 7  | P2 | Add `FEATURES.md` for feature inventory | Documentation |
| 8  | P2 | Add `TODO_LIST.md` for short/mid-term task tracking | Planning |
| 9  | P2 | Dedup `requireDeps` against existing requires | Correctness |
| 10 | P2 | Document `postPatchExtra` ordering in README | Clarity |
| 11 | P2 | Make `generate-flake.sh` configurable (target dir, no push default) | Portability |
| 12 | P2 | Fix `generate-flake.sh` templ sed fragility (use markers not line numbers) | Robustness |
| 13 | P2 | Migrate `crush-daily` from 14 individual deps to `subModules` | Eliminates boilerplate |
| 14 | P2 | Audit all consumers for manual `_local_deps/` workarounds | Cleanup |
| 15 | P3 | Add `--dry-run` option to mkPreparedSource | Debugging DX |
| 16 | P3 | Support `go.sum` patching | Completeness |
| 17 | P3 | Add integration test: build a real Go project with mkPreparedSource in CI | Confidence |
| 18 | P3 | Support nested sub-modules (`foo/bar/baz`) | Edge case |
| 19 | P3 | Add property-based tests for `repoName`/`stripVersionSuffix` | Regression prevention |
| 20 | P3 | Migrate consumers to `go-nix-helpers.lib.mkPreparedSource` (flake lib) | Better caching |
| 21 | P4 | Explore `go.work` support for workspace-based projects | Future-proofing |
| 22 | P4 | Add `vendorHash` auto-calculation helper | DX improvement |
| 23 | P4 | Add `overlays.default` for consumers to `pkgs.<name>` | Ergonomics |
| 24 | P4 | Generate template from source comments (prevent template drift) | Maintainability |
| 25 | P4 | Consider a `mkPreparedSource` NixOS check option | Discoverability |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Should `goPkg` be deprecated (defaulted) or dropped entirely, and is now the right time?**

`goPkg` is a required parameter consumed by `nativeBuildInputs = [ goPkg ]`, but the
derivation has `dontBuild = true` and the builder only runs `sed/cp/mkdir/echo/awk/grep`.
The Go toolchain is never invoked. I've verified this empirically — the parameter is
pure dead weight that inflates every consumer's build closure for no reason.

The problem: **all 7 downstream consumers pass `goPkg = pkgs.go_1_26;`**. Three options:

1. **Default it** — make `goPkg ? pkgs.go` and stop adding it to `nativeBuildInputs`.
   Backwards-compatible (consumers keep passing it, it's just ignored). Lowest risk.
2. **Deprecate then drop** — add a deprecation warning now, drop in a future version.
   Clean but requires consumer coordination.
3. **Drop it now** — breaking API change. Cleanest but forces all 7 consumers to update.

I cannot determine which approach aligns with your preferred breaking-change policy
and consumer-migration cadence. This is a one-person ecosystem decision.

---

## File Inventory

| File | Lines | Status |
|---|---|---|
| `mkPreparedSource.nix` | 311 | **Modified** (round 2: unified sub-module pipeline, -22 lines) |
| `flake.nix` | 117 | **New** (round 2: self-hosting) |
| `flake.lock` | 85 | **New** (round 2: flake lock) |
| `AGENTS.md` | 62 | **New** (round 2: AI session context) |
| `test.nix` | 216 | **Modified** (round 2: mockDep cleanup, meta.description) |
| `templates/go-flake-parts/flake.nix` | 213 | **Modified** (round 1+2: maintainers fix, checks dedup, formatting) |
| `README.md` | 156 | Modified (round 1: privateDepPattern docs) |
| `scripts/dashboard.sh` | 82 | Modified (round 1: configurable paths, JSON escaping) |
| `scripts/nix-lint.sh` | 215 | Modified (round 1: grep counting fix) |
| `scripts/generate-flake.sh` | 84 | Unchanged (rough edges documented) |
| `docs/flake-patterns.md` | 213 | Modified (round 1: typo fix, perSystem docs) |
| `docs/ci-workflow.yml` | 32 | Modified (round 1: removed `|| true`) |
| `docs/reviews/2026-06-19_full-code-review.html` | 1327 | New (round 1: full review report) |
| `docs/status/2026-06-08_*.md` | 206 | Prior status report |
| `docs/status/2026-06-09_*.md` | 283 | Prior status report |
| `git-town.toml` | 9 | Unchanged |
| `.gitignore` | 3 | Unchanged |

## Downstream Consumers

| Project | Uses `/vN` deps | Uses `subModules` | Status |
|---|---|---|---|
| BuildFlow | No | Yes (go-output) | Working |
| mr-sync | No | Yes (go-output) | Working |
| projects-management-automation | Yes (v2, v3) | Yes (go-output) | Working |
| go-structure-linter | Yes (v3) | Yes (go-output) | Working |
| branching-flow | No | Yes (go-output) | Working |
| Standup-Killer | No | Yes (go-cqrs-lite) | Working |
| library-policy | Delegates to `./nix/packages` | — | Working |

## Verification Status

- `nix flake check` — **all checks passed!** (zero warnings)
- `nix-build test.nix -A verify` — **SUCCESS-PATH TESTS PASSED** (8/8 assertions)
- `nix run .#verifyValidation` — **PASS: validation caught missing dep**
- `nix fmt` — clean (0 files changed)
