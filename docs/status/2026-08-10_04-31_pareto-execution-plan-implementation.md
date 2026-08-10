# Status Report — 2026-08-10 04:31

## Pareto Execution Plan Implementation Session

Executed 11 of 12 work packages from the Pareto execution plan
(`docs/planning/2026-08-10_02-41_pareto-execution-plan.md`). Started with the
1% tier (51% of value) and worked through to the polish tier.

**Session metrics:** 16 commits, 17 files changed, +1096/-166 lines, 92 module
assertions (up from 74), 22 pure function assertions (new), 8 flake checks
(up from 6).

---

## A) FULLY DONE

### P1: Merge protection fix (H3) — CRITICAL BUG FIX
- **What:** Extended `extraBuildAttrs` concatenation to `buildInputs`,
  `checkInputs`, `configureFlags` in addition to the existing
  `nativeBuildInputs`, `preBuild`, `postInstall`.
- **Why:** Consumer's `buildInputs`/`checkInputs`/`configureFlags` silently
  overrode the module's list instead of concatenating. A consumer adding
  `extraBuildAttrs.buildInputs = [ pkgs.sqlite ]` would unknowingly drop
  module-provided inputs.
- **Files:** `modules/go-standard.nix` (merge logic + option description),
  `test-module.nix` (4 new behavioral assertions).
- **Verified:** `nix build .#checks.x86_64-linux.moduleTest` — all 92
  assertions pass, including new `buildInputs`/`checkInputs`/`configureFlags`
  extraction tests.

### P2: CI shell tooling (H5, H4)
- **What:** Added `shfmt` to treefmt (both this repo's own config and as a
  new `enableShfmt` option in go-standard), ran `nix fmt` to format all
  scripts, added `shellcheck` CI job, fixed 2 warnings (unused `CYAN`
  variable in `dashboard.sh`, SC2016 false positive in `generate-flake.sh`).
- **Files:** `flake.nix`, `modules/go-standard.nix` (new `enableShfmt`
  option), `scripts/dashboard.sh`, `scripts/generate-flake.sh`,
  `scripts/nix-lint.sh`, `.github/workflows/ci.yml`, `test-module.nix`
  (2 new assertions: option default + toggle).
- **Verified:** `shellcheck` exits 0 on all scripts; `nix fmt -- --ci` clean.

### P3: CI smoke-test flags (H1, L8)
- **What:** Added `--go-mod`, `--private-deps`, and combined
  `--go-mod --private-deps --templ` variants to CI smoke-test job. Added
  Nix installer + magic-nix-cache to the smoke-test job (was missing).
- **Files:** `.github/workflows/ci.yml` (3 new CI steps + Nix setup).
- **Verified:** All flag combinations tested locally — `generate-flake.sh`
  produces correct files for each variant.

### P4: Behavioral test deepening (M7, M9)
- **What:** Added 5 behavioral tests proving `buildFlags`, `ldflags` (with
  version injection), `custom ldflags`, `proxyVendor` reach the derivation
  (not just eval-level). Added integration Test 7: `publicDeps` with `/v2`
  versioned path.
- **Files:** `test-module.nix` (5 new assertions), `test.nix` (new Test 7
  scenario + verify script section).
- **Verified:** `nix build .#checks.x86_64-linux.verify` — all 7 integration
  scenarios pass.

### L5: Temp file cleanup in trap
- **What:** Added `trap 'rm -f go.mod.requires.tmp' EXIT` around the temp
  file lifecycle in `mkPreparedSource.nix` postPatch. If any command between
  creation and cleanup fails, the trap ensures cleanup.
- **Files:** `mkPreparedSource.nix`.
- **Verified:** Integration tests pass (trap doesn't interfere with normal
  flow).

### P5: Pure function property tests (M1, M2, L6)
- **What:** Extracted `stripVersionSuffix` and `repoName` from
  `mkPreparedSource.nix` into `pure-functions.nix` (importable, testable).
  Created `test-pure-functions.nix` with 22 assertions covering:
  idempotence, no-`/vN`-in-output invariant, determinism, no-slash invariant,
  edge cases (`v1`, `v100`, empty string, single segment, non-version
  `v`-prefixes, only-version-segments).
- **Files:** `pure-functions.nix` (new, 30 lines), `test-pure-functions.nix`
  (new, 145 lines), `mkPreparedSource.nix` (imports from pure-functions.nix),
  `flake.nix` (wired as `checks.pureFunctions`).
- **Verified:** `nix build .#checks.x86_64-linux.pureFunctions` — 22/22 pass.

### P6: Detection and safety nets (M3, M4, L5)
- **What:**
  - **M3 (vendorHash placeholder):** Added `builtins.trace` warning in
    `go-standard.nix` when `vendorHash` matches the `sha256-AAA...` placeholder
    pattern. Warning fires at evaluation time via `builtins.seq`.
  - **M4 (structural test):** Added `checks.structural` derivation that
    verifies `flakeModules.go-standard`, `lib.mkPreparedSource`,
    `lib.mkGoFlake` all exist in flake outputs.
  - **L5:** Already done (trap cleanup above).
- **Files:** `modules/go-standard.nix`, `test-module.nix` (1 new assertion),
  `flake.nix` (new structural check).
- **Verified:** Warning fires during module test evaluation (visible in build
  log). Structural check passes.

### P7: GOPRIVATE behavioral test (H2)
- **What:** Added 4 behavioral assertions proving GOPRIVATE injection into
  devShell: (1) GOPRIVATE present when `deps` set, (2) uses default
  `privateGlobPattern`, (3) uses custom `privateGlobPattern`, (4) NOT set
  when `deps` empty.
- **Files:** `test-module.nix` (2 new test configs + 4 new assertions).
- **Verified:** All 4 assertions pass.

### P8: Docs and diagram sync (M5, L2, L4)
- **What:**
  - Updated `docs/architecture.d2` to show `privateGlobPattern`, `enableNixfmt`,
    `enableShfmt` options (was showing "+20 more"). Regenerated `.svg`.
  - Added FAQ entry: "How do I use deps with non-LarsArtmann repos?" with
    code example for overriding `privateDepPattern` and `privateGlobPattern`.
  - L2 (macOS CI badge): CI badge already covers macOS via matrix. No change
    needed.
- **Files:** `docs/architecture.d2`, `docs/architecture.svg`, `README.md`.

### P10: Test infrastructure (M8, M10)
- **What:**
  - **M8 (enableCompletions negative test):** Added 2 assertions verifying
    the warning text ("does not support the --completion subcommand") is
    present in the derivation's `postInstall`, and `installShellFiles` is in
    `nativeBuildInputs`.
  - **M10 (treefmt config inspection):** Added 2 assertions verifying
    treefmt programs match enabled options: 3 programs with defaults
    (gofumpt, goimports, nixfmt), 0 programs when all disabled.
- **Files:** `test-module.nix` (4 new assertions).
- **Verified:** All assertions pass.

### P11: CI expansion (L7, L9)
- **What:** Extended `integration-tests` job from `ubuntu-latest` only to a
  matrix of `[ubuntu-latest, macos-latest]`. Uses `nix eval --raw --impure
  --expr 'builtins.currentSystem'` for dynamic system detection.
  L7 (`--all-systems`): Not feasible — Linux runners can't evaluate darwin
  derivations. The matrix approach achieves the same cross-platform coverage.
- **Files:** `.github/workflows/ci.yml`.
- **NOTE:** Has one uncommitted change (the CI YAML diff from the auto-git
  daemon's version vs my version — see section D).

---

## B) PARTIALLY DONE

### P9: Script UX improvements (M6, L1, L3) — 90% done
- **Done:** `--dry-run`, `--verbose`, `--list-templates` flags all
  implemented and tested. Help text updated with new flags + template
  listing.
- **Gap:** No CI smoke-test coverage for the new flags. The smoke-test job
  tests `--go-mod`, `--private-deps`, `--templ` but not `--dry-run` or
  `--verbose`.

---

## C) NOT STARTED

### P12: Refactoring (L10) — DELIBERATELY SKIPPED
- **Task:** Extract `postPatch` script from `mkPreparedSource.nix` into a
  separate `.sh` file.
- **Decision:** After studying the `postPatch` string, it interpolates 8
  dynamically-generated Nix variables (`copyDeps`, `stripLocalReplacesScript`,
  `replaceLines`, `validateScript`, etc.). Extracting to `.sh` would require
  passing all fragments as env vars or using placeholder substitution —
  **increasing** complexity rather than reducing it. This is the idiomatic
  Nix pattern for `mkDerivation` phases. The plan correctly flagged this as
  the highest-risk Verschlimmbesserung. Skipped on merit.

---

## D) TOTALLY FUCKED UP

### D1: Uncommitted CI YAML change
The `.github/workflows/ci.yml` file has an uncommitted diff. The auto-git
daemon committed a version using GitHub Actions expression syntax
(`${{ runner.arch == 'X64' && ... }}`) for system detection. I then changed
it to use `nix eval --raw --impure --expr 'builtins.currentSystem'` which
is more robust. The file was reformatted by the daemon but my version wasn't
committed because the daemon committed first.

**Current state:** My version (the `nix eval` approach) is the working tree
version, uncommitted. The daemon's version is committed. Needs reconcile.

### D2: TODO_LIST.md is now stale
The TODO_LIST still shows all 30 items as `TODO`. Every actionable item from
the Pareto plan (H1-H5, M1-M10, L1-L10 except L10) has been completed in
this session, but the TODO_LIST was not updated. This is a docs-health
violation per the project's own conventions — completed items should be
removed (they live in CHANGELOG, not TODO_LIST).

### D3: No CHANGELOG entries
16 commits shipped new features and tests but no CHANGELOG.md entries were
written. The project convention says completed work goes in CHANGELOG.

### D4: shellcheck CI job uses external action
The `shellcheck` job uses `ludeeus/action-shellcheck@2.0.0` from the GitHub
Actions marketplace. This is a third-party action that could be supply-chain
risk. A more conservative approach would be to install shellcheck via Nix
and run it directly. Minor, but worth noting.

---

## E) WHAT WE SHOULD IMPROVE

1. **TODO_LIST lifecycle must be maintained during execution.** I completed
   25+ items but didn't update TODO_LIST.md as I went. The list went from
   "severely stale" (before the docs-health audit) to "severely stale" again
   (after this session). The delete-done protocol must be applied after each
   work package, not deferred to a separate session.

2. **CHANGELOG must be written incrementally.** 16 commits with no CHANGELOG
   entries means there's no structured record of what shipped. Each package
   (P1-P11) should have added a CHANGELOG entry.

3. **CI YAML needs commit discipline.** The auto-git daemon and manual edits
   are fighting over `ci.yml`. The working tree has the correct version but
   it's uncommitted. Should have committed immediately after verifying.

4. **P12 risk assessment was correct but should be documented.** The decision
   to skip P12 should be recorded in the plan document itself (strikethrough
   with rationale), not just in this status report.

5. **Pure function extraction created a new public surface.** `pure-functions.nix`
   is a new file that consumers could theoretically import, but it's not
   documented in AGENTS.md, README.md, or exported via `flake.lib`. Should
   decide: is it internal (test-only) or public API?

6. **The `vendorHashWarning` uses `builtins.trace`** which prints to stderr
   during evaluation. This is the Nix idiom for warnings, but it's noisy in
   CI logs. Consider using `lib.warn` (Nix 2.21+) for a more structured
   warning if the Nix version supports it.

7. **Test count inflation.** Module tests went from 74 to 92 assertions, but
   many new tests are eval-level (`packages ? default`) rather than true
   behavioral tests. The behavioral tests (extracting `drvAttrs`) are more
   valuable and should be the preferred pattern.

8. **Integration test count in docs is now wrong.** AGENTS.md says "6
   scenarios" — it's now 7. FEATURES.md was updated to "6" in the previous
   session but is now also wrong.

---

## F) Up to 50 Things to Get Done Next

### Immediate (fix damage from this session)
1. Update TODO_LIST.md — mark all completed items as done (delete them)
2. Write CHANGELOG entries for all 16 commits
3. Commit the uncommitted `ci.yml` change
4. Update AGENTS.md test counts (74→92 module assertions, 6→7 integration scenarios, 32→37 options)
5. Update FEATURES.md integration test count (6→7)
6. Document `pure-functions.nix` in AGENTS.md key files table
7. Annotate the Pareto plan: mark P1-P11 as shipped, P12 as skipped with rationale

### Short-term (fill remaining gaps)
8. Add `--dry-run` and `--verbose` to CI smoke-test job
9. Add `enableShfmt` to the man page (`docs/man/go-standard.5`)
10. Add `enableShfmt` to the README options table
11. Add `pure-functions.nix` to `flake.lib` export (or explicitly mark as internal)
12. Consider `lib.warn` instead of `builtins.trace` for vendorHash placeholder
13. Add behavioral test for `enableShfmt` toggle in treefmt (currently only eval-level)
14. Add behavioral test for `enableShfmt = true` producing `shfmt.enable = true` in treefmt (done, but could be deeper)

### CI hardening
15. Replace `ludeeus/action-shellcheck` with Nix-installed shellcheck
16. Add `nix flake check --no-build` step to the smoke-test job
17. Add CI step for `nix build .#checks.x86_64-linux.structural`
18. Add CI step for `nix build .#checks.x86_64-linux.pureFunctions`
19. Add CI step for pure function tests on macOS
20. Add `--all-systems` to the macOS check job (can evaluate all systems on macOS)
21. Add Nix flake check to the macOS integration-tests job
22. Add CI badge for shellcheck job
23. Add CI step that verifies `nix fmt -- --ci` passes on macOS too

### Test deepening
24. Add property test: `repoName` output never contains `/vN`
25. Add property test: `stripVersionSuffix` preserves non-version path segments
26. Add test: `extraBuildAttrs` with ALL list attrs simultaneously
27. Add test: `enableCompletions` with a mock binary that DOES support `--completion`
28. Add test: monorepo `packages` option with `enableCompletions`
29. Add test: `ldflags = []` (empty list, not null)
30. Add test: `proxyVendor = false` with deps (should be forced to false)
31. Add test: `buildFlags` with special characters (spaces, quotes)
32. Add test: `deps` with a deeply nested module path (5+ levels)
33. Add test: `postPatchExtra` actually runs (behavioral, not eval)
34. Add test: `shellExtraEnv.GOPRIVATE` overrides `autoGoPrivate`
35. Add test: `autoGoPrivate = false` suppresses GOPRIVATE even with deps
36. Add test: `enableGopls = false` removes gopls from devShell
37. Add test: `enableGovulncheck = false` removes govulncheck from devShell
38. Add integration test: `requireDeps` with `/v2` path dedup
39. Add integration test: deeply nested sub-module at 4+ levels
40. Add test: `stripLocalReplaces` with no existing replaces (no-op)

### Documentation
41. Update `docs/migration-guide.md` to mention `enableShfmt`
42. Update `docs/flake-patterns.md` with the new `extraBuildAttrs` merge pattern
43. Add `docs/man/go-standard.5` entry for `enableShfmt`
44. Add `docs/man/go-standard.5` entry for `vendorHash` placeholder warning
45. Add architecture diagram note about pure-functions.nix
46. Write a CONTRIBUTING.md for downstream consumers

### Polish
47. Add `--force` flag to `generate-flake.sh` to overwrite existing files
48. Add `--vendor-hash` flag to `generate-flake.sh` for post-build hash injection
49. Consider adding `golangci-lint` config template to `generate-flake.sh`
50. Add `nix run .#lint` smoke test to CI

---

## G) Questions I Cannot Answer Myself

### Q1: Should `pure-functions.nix` be a public API?
`pure-functions.nix` was created to make `stripVersionSuffix` and `repoName`
testable. It's currently not exported via `flake.lib` and not documented. Should
it be:
- (a) Exported as `flake.lib.pure` for consumer use (e.g., downstream tools
  that need to parse Go module paths), or
- (b) Kept as an internal test utility with no public surface?
This affects whether to document it, version it, and maintain backward
compatibility.

### Q2: Should the vendorHash placeholder warning be a hard error?
Currently it's a `builtins.trace` warning (non-blocking). Some CI setups
capture `trace` output differently. Should an unfilled `sha256-AAA...`
placeholder be a hard eval error (forcing the consumer to set a real hash or
explicitly acknowledge with `vendorHash = null`), or keep it as a warning?
This is a breaking-change decision for 7+ downstream consumers.

### Q3: Should P12 (postPatch extraction) be revisited with a different approach?
I skipped P12 because interpolating 8 Nix variables into a `.sh` file would
increase complexity. An alternative approach would be to use `pkgs.writeText`
to generate the script at eval time and `source` it in postPatch. This trades
Nix string escaping for file-generation complexity. Is this worth exploring,
or is the current inline approach the right call?
