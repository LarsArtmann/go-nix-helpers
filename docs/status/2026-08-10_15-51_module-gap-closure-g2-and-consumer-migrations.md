# Status Report: Module Gap Closure, G2, Consumer Migrations & Self-Critique

**Date:** 2026-08-10 15:51
**Session scope:** Close remaining module gaps (G2, enableTestCheck), add template-eval CI check, migrate 3 consumer repos, clean up 4 module adopters, comprehensive self-critique.
**Previous commit:** `26b7620` (goPkgOverride, lintAsCheck, fleet audit, template fix)
**Uncommitted:** 9 files in go-nix-helpers (+256/-26), 7 consumer repos modified

---

## A) FULLY DONE ✅

### 1. lintAsCheck gating test added
The previous session left a coverage gap: `lintAsCheck` was gated on `enableGolangciLint` in the module code (line 666), but no test verified the gating behavior. Added assertion: `lintAsCheck=true + enableGolangciLint=false → no checks.lint`. The daemon had committed `26b7620` mid-edit before the test was saved — this closes that gap.

**File:** `test-module.nix` — 1 new assertion (107 total at that point).

### 2. G2: per-package extraBuildAttrs implemented + tested
The fleet audit identified G2 as the blocker for 4+ monorepo repos (StopTube, browser-history, BuildFlow, go-structure-linter). The `packages` submodule couldn't carry per-binary customization.

**Implementation:**
- Added `extraBuildAttrs` option to the `packages` submodule (attrs, default `{}`)
- Refactored `mkGoPackage` from 3-arg to 4-arg: `(pkgName, subPkgs, pkgDesc, pkgExtraBuildAttrs)`
- Introduced `concatKeys` list and `combinedConcat`/`combinedOther` let-bindings that merge top-level `cfg.extraBuildAttrs` with per-package values
- Same concatenation semantics: 6 keys (`nativeBuildInputs`, `buildInputs`, `checkInputs`, `configureFlags`, `preBuild`, `postInstall`) append per-package after top-level; all other keys use per-package override of top-level
- Updated both call sites: `package` (passes `{}`) and `extraPackages` (passes `pcfg.extraBuildAttrs`)

**Tests (4 new assertions):**
1. `packages.<name>.extraBuildAttrs` option default is `{}`
2. Per-package extraBuildAttrs evaluates without error
3. Per-package override key flows through (verified via `passthru`)
4. Per-package + top-level concat evaluates

**Key learning:** `buildGoModule` embeds `ldflags` in `buildPhase`, not in `drvAttrs`. The initial test tried to read `drvAttrs.ldflags` and failed. Fixed by using `passthru` for verification instead.

**File:** `modules/go-standard.nix` — +79/-15 lines in the perSystem implementation.

### 3. enableTestCheck option implemented + tested
Most consumers hand-write `checks.test = config.packages.default.overrideAttrs { doCheck = true; }`. The module now provides this as a first-class option.

**Implementation:**
- New option `enableTestCheck` (bool, default: false) — generates `checks.test` derivation that forces `doCheck = true` regardless of `enableCheck`
- Use case: skip tests during normal builds (`enableCheck = false`) for faster iteration, but still run them in CI via `nix flake check`
- Added to checks output via `lib.optionalAttrs cfg.enableTestCheck { test = ...; }`

**Tests (3 new assertions):**
1. `enableTestCheck` default is false
2. `enableTestCheck=false` has no `checks.test`
3. `enableTestCheck=true` exposes `checks.test`

**File:** `modules/go-standard.nix` — new option at ~line 164, checks output at ~line 725.

### 4. templateEval CI check added
The pre-existing template bug (`inputs@{ self, ... }` calling unbound `flake-parts`, fixed in `26b7620`) went undetected since `9471741` because:
- `nix-instantiate --parse` only checks syntax, not semantics
- The CI smoke-test jobs used `--parse`, not evaluation
- The 5 repos that adopted the module were hand-written, not generated from the template

**Implementation:**
- New `templateEval` check in `flake.nix`
- Imports the template file, calls its `outputs` function with mock inputs (`{ self, flake-parts, nixpkgs, go-nix-helpers }`)
- Verifies the result has `imports` and `go-standard` keys
- Uses `builtins.tryEval` to catch evaluation errors gracefully
- Would have caught the `9471741` bug on day 1

**File:** `flake.nix` — +44 lines. Now 9 checks total (was 8).

### 5. Documentation updated comprehensively
- **AGENTS.md:** Option count 37→38, assertion count 106→114, added `enableTestCheck` to the options list, noted per-package `extraBuildAttrs` in monorepo description
- **README.md:** Added `enableTestCheck` row to options table, updated monorepo example with `worker.extraBuildAttrs.ldflags`, noted per-binary customization
- **CHANGELOG.md:** Added entries for `enableTestCheck`, G2 per-package extraBuildAttrs, `templateEval` check
- **docs/man/go-standard.5:** Added `enableTestCheck` option, `checks.test` output, updated `packages` option to mention per-entry `extraBuildAttrs`, updated `checks.lint` to note `enableGolangciLint` gating
- **docs/flake-patterns.md:** Added "Per-package extraBuildAttrs (G2)" section with before/after example, added "CI-friendly options" section documenting `lintAsCheck` and `enableTestCheck`

### 6. TODO_LIST.md updated
- Marked fleet audit item as **DONE** (was BLOCKED — "Requires access to 7+ downstream repos")
- Added **H1**: G2 per-package extraBuildAttrs → **DONE** (this session)
- Added **H2**: Migrate Tier A consumer repos (10 repos)
- Added **H3**: Template-output CI check → **DONE** (this session)
- Added **M1**: enableTestCheck → **DONE** (this session)
- Added **M2**: Migrate Tier B repos
- Added **M3**: Clean up 5 existing module adopters → partially done (4/5 cleaned)
- Added **M4**: Migrate Tier C repos off deprecated mkGoFlake

### 7. Three consumer repos migrated to go-standard
All verified with `nix flake check --no-build`:

| Repo | Before | After | Reduction | Key Features Migrated |
|------|--------|-------|-----------|----------------------|
| go-localsync | 237 lines | 86 lines | **64%** | deps (3 private), monorepo packages (cqrs-lint), GOEXPERIMENT, custom checks (cqrs-lint architectural gate), GOFLAGS |
| erraudit | 258 lines | 119 lines | **54%** | deps (10 private), custom ldflags (version/commit injection), GOEXPERIMENT, `enableCheck=false`, CGO_ENABLED=0, extra devShell packages |
| project-meta | 268 lines | 158 lines | **41%** | deps (7 private) + subModules (13 sub-modules for project-discovery-sdk), git-hooks.nix integration, cobra completions (custom postInstall), GOEXPERIMENT, enableCompletions |

### 8. Four module adopters cleaned up
Removed dead `systems` and `treefmt-nix` inputs from 4 repos that had already adopted go-standard (which bundles both internally):

| Repo | Inputs Removed | Status |
|------|---------------|--------|
| lean-business-plan | `systems` + `treefmt-nix` | ✅ `--no-build` passes |
| storbi | `systems` + `treefmt-nix` | ✅ `--no-build` passes |
| template-arch-lint | `systems` + `treefmt-nix` | ✅ `--no-build` passes |
| terraform-diagrams-aggregator | `systems` + `treefmt-nix` | ✅ `--no-build` passes |

### 9. Full verification
- `nix fmt` — 0 files changed (clean)
- `nix flake check` — all 9 checks pass (autoDiscovery, explicitOnly, verify, moduleTest, moduleTestNoOverlay, pureFunctions, structural, **templateEval** (new), treefmt)
- Module tests: **114 assertions** (was 106 at session start, was 99 before prior session)
- Option count: **38** (was 37)
- All 7 consumer repos pass `nix flake check --no-build`

---

## B) PARTIALLY DONE ◑

### 1. Consumer migrations: 3 of 12 Tier A repos done
The session migrated 3 of the 10 straightforward Tier A repos. The remaining 7 (go-humanize-linter, golangci-lint-auto-configure, oxlint-auto-configure, go-auto-upgrade, project-dependency-graph, projects-management-automation, standard-bug-tracking-schema) were surveyed but not migrated. All have `GOEXPERIMENT=jsonv2` and fileset source filtering that adds complexity.

**What's proven:** The migration pattern works. go-localsync, erraudit, and project-meta all evaluate correctly after migration. The key insight: `extraBuildAttrs.env` handles `GOEXPERIMENT` cleanly, and `shellExtraEnv` handles it for devShells.

**What's blocking:** Nothing technical — just time. Each migration is ~15-20 min of work.

### 2. Module adopter cleanups: 4 of 5 done
The 5th adopter (`index`) was not cleaned up. The audit noted it needs `enableCheck=true` removal and deps/publicDeps expansion, but I didn't get to it.

### 3. G2 is implemented but untested in a real consumer
G2 (per-package extraBuildAttrs) has 4 test assertions but zero real-world usage. No consumer has been migrated TO a monorepo using per-package attrs yet. The implementation is correct by construction (same merge logic as top-level, just applied per-entry), but there's no proof it works for the actual use case (StopTube's per-binary ldflags, BuildFlow's per-binary build tags).

### 4. Migrated repos are eval-verified but not build-verified
All 3 migrated repos pass `nix flake check --no-build` but none have been actually built with `nix build`. The migration changes `proxyVendor` behavior (module forces `false` when deps are set, manual repos often had `true`), which may require a vendorHash update. SSH access to GitHub is blocked in this environment.

---

## C) NOT STARTED ⬜

1. **7 remaining Tier A consumer migrations** — surveyed, patterns understood, not executed
2. **6 Tier B consumer migrations** — some now unblocked by G2, not started
3. **2 Tier C migrations** (Standup-Killer, crush-daily) — need to migrate off deprecated `mkGoFlake`
4. **`index` adopter cleanup** — 5th module adopter, not touched
5. **CI standardization** across migrated repos — not started
6. **`flake.lock` freshness audit** across consumer repos — not checked
7. **Real `nix build` verification** of migrated repos — blocked on SSH access
8. **G2 real-world validation** — no consumer uses per-package attrs yet
9. **`enableTestCheck` real-world validation** — no consumer uses it yet
10. **flake-patterns.md TOC update for anchor links** — added "CI-friendly options" to TOC but didn't verify the anchor works
11. **Commit the work** — 9 files uncommitted in go-nix-helpers, 7 consumer repos uncommitted

---

## D) TOTALLY FUCKED UP 💥

### 1. I forgot to commit ANYTHING
**Nine files in go-nix-helpers are uncommitted (+256/-26 lines).** Seven consumer repos have uncommitted `flake.nix` changes. The auto-commit daemon committed `26b7620` mid-prior-session, but nothing I did this session has been committed. If the daemon doesn't fire, this is all lost.

**Impact:** HIGH. All work is in working tree only. A `git checkout` or crash loses everything.

**Root cause:** I focused on execution and verification, never circled back to commit. The prior session's handoff said "commit the status report + test fix" as a next step and I didn't do it.

### 2. The G2 refactor changed the merge semantics subtly
The old code had:
```
userExtraBuildAttrs = builtins.removeAttrs cfg.extraBuildAttrs [concatKeys]
mergedPreBuild = autoDepSyncPreBuild + (cfg.extraBuildAttrs.preBuild or "")
```

The new code has:
```
combinedConcat.preBuild = (topLevel.preBuild or "") + (perPkg.preBuild or "")
```

But `combinedConcat.preBuild` does NOT include `autoDepSyncPreBuild` — that's added separately at the `preBuild = autoDepSyncPreBuild + combinedConcat.preBuild` line in the `buildGoModule` call. This is correct, but the variable naming is confusing (`combinedConcat.preBuild` vs the actual `preBuild` attribute). A future reader might accidentally "fix" this by removing the `autoDepSyncPreBuild +` prefix, breaking dep-sync.

**Impact:** MEDIUM (maintainability risk, not a bug).

### 3. The templateEval check has a false-positive risk
The mock inputs include `flake-parts.lib.mkFlake = _: attrs: attrs` — this returns the attrs as-is. But the real `flake-parts.lib.mkFlake` wraps them in a module. If a template does something that only works through mkFlake's module wrapping (e.g., references `config` in an option), the mock would incorrectly pass. The check verifies that the outputs function ACCEPTS the inputs and produces SOMETHING with `imports` and `go-standard` keys — but it doesn't verify the module is semantically valid.

**Impact:** LOW. The check catches the important class of bugs (unbound variables). Full module evaluation would require importing the real flake-parts, which is expensive.

### 4. The erraudit migration lost `proxyVendor = true`
The original erraudit had `proxyVendor = true`. The module forces `proxyVendor = false` when `deps` is non-empty. This is intentional (mkPreparedSource handles vendoring differently), but it means the first `nix build` will likely fail with a vendorHash mismatch and require updating the hash.

**Impact:** MEDIUM. The migration is functionally correct but will need a vendorHash update on first build. I should have documented this in the migration itself or added a comment.

### 5. I didn't update the `systems` option in migrated repos
The module defaults to `systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]`. The original repos used `import inputs.systems` (same default list). But if any repo had a CUSTOM systems list, the migration would silently change the build matrix.

**Impact:** LOW (all 3 repos used the default). But I should have verified this per-repo instead of assuming.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Process

1. **Commit immediately after each logical unit of work.** The "forgot to commit" failure is recurring. The auto-daemon is a safety net, not a strategy. I should commit after each todo completion, not at the end.

2. **Build-verify migrations before declaring done.** "Evaluates" ≠ "builds." The 3 migrated repos are eval-verified only. The `proxyVendor` change is a known build-affecting difference. I should have flagged this explicitly in each migration.

3. **Test the test.** The G2 ldflags test failed because I assumed `buildGoModule` exposes `ldflags` in `drvAttrs`. It doesn't. I should have verified the test assertion mechanism before writing 3 tests that depend on it. Using `passthru` is the correct approach, but discovering this cost a round-trip.

4. **Read the actual merge code before refactoring it.** The G2 refactor touched a critical merge path (`userExtraBuildAttrs` → `combinedOther`). I read the code first, but the variable naming (`combinedConcat` vs actual attribute values) is still confusing. I should have named things more clearly.

### Module

5. **`proxyVendor` should be configurable per-deps.** The module forces `proxyVendor = false` when deps are set, but some repos (erraudit) had `proxyVendor = true` with deps. This is a behavior change on migration. Consider making this an option or documenting it prominently.

6. **No `src` with `lib.fileset` convenience.** Most legacy repos use `lib.fileset.toSource` for source filtering. The module's `src` option defaults to `self.outPath` (whole repo). Migrated repos lose their fileset filtering unless they set `src = lib.fileset.toSource { ... }` — but then `lib` isn't in scope in the module config. Consider adding a `srcFileset` option or documenting the pattern.

7. **`GOEXPERIMENT` is extremely common** (7/10 Tier A repos use `jsonv2`). Consider an `enableJsonV2` option or a generic `goExperiment` string option to avoid the `extraBuildAttrs.env.GOEXPERIMENT` boilerplate.

8. **`CGO_ENABLED = "0"` is common.** Consider a `cgoEnabled` option (default: false for CLI tools).

9. **`enableCompletions` uses `--completion` but cobra uses `completion <shell>`.** project-meta needed a custom `postInstall` because the module's `enableCompletions` calls `binary --completion bash` (urfave/cli style) but cobra calls `binary completion bash`. The module should auto-detect or provide a `completionStyle` option.

10. **The `checks.test` derivation doesn't use `enableCheck`.** If `enableCheck = true` (default), `checks.build` already runs tests. Adding `checks.test` is redundant unless `enableCheck = false`. The option works but its value proposition is narrow. Consider: when `enableCheck = false` AND `enableTestCheck = true`, generate `checks.test`. When `enableCheck = true`, don't (it's redundant with `checks.build`).

### Consumer migrations

11. **The `proxyVendor` change needs prominent documentation in the migration guide.** Right now, the migration guide doesn't mention that `proxyVendor` flips to `false` when deps are set.

12. **A migration "recipe card" per common pattern would help.** The GOEXPERIMENT + CGO_ENABLED + fileset pattern appears in 7+ repos. A copy-paste recipe would speed up the remaining 7 Tier A migrations.

---

## F) Up to 50 things to do next

### Immediate (loose ends from this session)

1. **Commit all 9 uncommitted files in go-nix-helpers** — the daemon may or may not fire
2. **Commit the 7 consumer repo changes** — go-localsync, erraudit, project-meta, lean-business-plan, storbi, template-arch-lint, terraform-diagrams-aggregator
3. **Build-verify the 3 migrated repos** with `nix build` (needs SSH access) — update vendorHash if needed
4. **Clean up `index` adopter** — the 5th module adopter, remove `enableCheck=true` redundancy
5. **Verify flake-patterns.md anchor link** for "CI-friendly options" TOC entry

### Module improvements

6. **Add `goExperiment` option** — string, default null. When set, adds `GOEXPERIMENT = <value>` to both build env and devShell. Eliminates boilerplate in 7+ repos.
7. **Add `cgoEnabled` option** — bool, default false. Eliminates `CGO_ENABLED = "0"` boilerplate.
8. **Add `completionStyle` option** — enum: "flag" (urfave/cli `--completion`), "subcommand" (cobra `completion`), "none". Fixes enableCompletions for cobra projects.
9. **Make `proxyVendor` configurable** even when deps are set — or at least document the behavior change prominently in migration guide.
10. **Add `srcFileset` option** — accepts a fileset, wraps in `lib.fileset.toSource`. Avoids needing `lib` in scope.
11. **Deduplicate `enableTestCheck` when `enableCheck = true`** — don't generate `checks.test` if `checks.build` already runs tests.
12. **G4 escape hatch** — allow consumers to override `autoDepFodAttrs` phases via `extraBuildAttrs` (currently overwritten by `//` merge order).
13. **Add `allowUnfree` option** — avoids nixpkgs re-instantiation in 4 repos (bank-sync, github-local-sync, etc.).
14. **Bundle `git-hooks.nix` optionally** — 4 repos use it; currently each must add it as a separate input + import.
15. **Add `enableShfmt` to devShell packages** when enabled (currently only adds to treefmt programs, not devShell).

### Consumer migrations — Tier A remaining (7 repos)

16. **Migrate go-humanize-linter** — 287 lines, 8 custom apps (complex but pattern understood)
17. **Migrate golangci-lint-auto-configure** — 233 lines, fileset + GOEXPERIMENT
18. **Migrate oxlint-auto-configure** — 196 lines, nativeCheckInputs=[oxlint], fileset, custom app wrapping
19. **Migrate go-auto-upgrade** — 542 lines, the most complex (12 apps, dual GOEXPERIMENT, check derivations with nativeBuildInputs)
20. **Migrate project-dependency-graph** — 231 lines, custom modBuildPhase/modInstallPhase, `go run` app
21. **Migrate projects-management-automation** — 267 lines
22. **Migrate standard-bug-tracking-schema** — 386 lines

### Consumer migrations — Tier B (6 repos, now unblocked by G2)

23. **Migrate KeyCountdown** — 250 lines
24. **Migrate StopTube** — 262 lines, needs G2 (per-binary attrs) ✓ shipped
25. **Migrate branching-flow** — 328 lines
26. **Migrate browser-history** — 600 lines, needs G2 ✓ shipped
27. **Migrate overview** — 468 lines, needs G2 ✓ shipped
28. **Migrate bank-sync** — 515 lines, allowUnfree
29. **Migrate BuildFlow** — 1215 lines, needs G2 ✓ shipped

### Consumer migrations — Tier C (complex/exceptions)

30. **Migrate Standup-Killer off deprecated mkGoFlake** — needs G2 for subModules ✓ shipped
31. **Migrate crush-daily off deprecated mkGoFlake**
32. **Migrate Code-Quality-Agent** — G1 shipped (goPkgOverride), can migrate now
33. **Migrate go-structure-linter** — needs G2 for multi-module postPatchExtra ✓ shipped
34. **Migrate file-and-image-renamer** — needs deps audit first
35. **Migrate library-policy** — 139 lines, uses nix/* submodules
36. **Migrate mr-sync** — 252 lines, own package.nix
37. **Migrate go-cqrs-lite** — 1224 lines, monorepo library
38. **Migrate DiscordSync** — 725 lines, many pinned revs
39. **Migrate github-local-sync** — 279 lines, allowUnfree

### CI and infrastructure

40. **Add `templateEval` to CI integration-tests job** — currently only in `nix flake check`, not in the explicit CI job list
41. **Standardize CI workflow across migrated repos** — template for consumer CI
42. **Add `flake.lock` freshness check** to consumer repos
43. **Add real E2E consumer test** — mock Go project + flake.nix → `nix build`
44. **Add template-output build test** (not just eval) — generate + `nix build` in CI

### Documentation

45. **Document `proxyVendor` behavior change** in migration guide (deps → proxyVendor=false)
46. **Add migration recipe card** for the GOEXPERIMENT + CGO + fileset pattern
47. **Document the public/private LarsArtmann repo split** (which are proxy-served vs SSH-only)
48. **Update `docs/flake-patterns.md`** with `goPkgOverride` real-world example (Code-Quality-Agent)
49. **Add `enableTestCheck` to template** as a commented example

### External

50. **Register `maintainers.larsartmann` in nixpkgs** — external PR, mentioned in prior reports

---

## G) Questions I cannot answer myself

### 1. Should I commit the consumer repo changes?
Seven consumer repos have uncommitted `flake.nix` changes. Three are migrations (go-localsync, erraudit, project-meta) and four are input cleanups (lean-business-plan, storbi, template-arch-lint, terraform-diagrams-aggregator). I don't know if you want me to commit these directly, or if you want to review them first, or if the auto-daemon should handle them. The global AGENTS.md says "An auto-git commit daemon runs continuously" but I'm not sure if that applies to repos other than the one I'm working in.

### 2. Is the `proxyVendor = false` behavior when deps are set correct?
The module forces `proxyVendor = false` when `usePreparedSource = true` (deps non-empty). erraudit had `proxyVendor = true` WITH deps. I preserved the module's behavior (false) rather than erraudit's original (true). This may require a vendorHash update on first build. Is the module's behavior correct here, or should `proxyVendor` be respected even when deps are set?

### 3. Should `enableCompletions` support cobra-style (`completion <shell>`) or only urfave/cli (`--completion <shell>`)?
project-meta uses cobra, which uses `meta completion bash` (subcommand), not `meta --completion bash` (flag). The module's `enableCompletions` calls `--completion`, which would fail for cobra projects. I worked around this in project-meta by setting `enableCompletions = false` and using a custom `postInstall`. Should I add a `completionStyle` option to handle this properly, or is the workaround acceptable?
