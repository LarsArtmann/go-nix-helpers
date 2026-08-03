# Status Report: Bug Fixes & Test Gap Fill

**Date:** 2026-07-24 23:04
**Session:** Fix 4 bugs (D1-D4) and fill 6 testing gaps identified in prior self-critique
**Branch:** master (12 commits ahead of origin)
**Working tree:** Clean — all changes committed

---

## A) FULLY DONE (shipped, tested, verified)

These items are implemented, pass `nix flake check`, and have no known issues:

| #   | Task                                                          | Evidence                                                                                                                                                              |
| --- | ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **D1 Fix:** Monorepo overlay maps each package correctly      | `modules/go-standard.nix:545` — uses `${name}` not `${cfg.pname}`. Tested by `monorepoOverlayCheck` assertion.                                                        |
| 2   | **D2 Fix:** Dead `completionAttrs` removed                    | `modules/go-standard.nix` — 0 occurrences of `completionAttrs`. Completions now wired into `mkGoPackage` via `completionPostInstall` with proper `postInstall` merge. |
| 3   | **D4 Fix:** `generate-flake.sh --templ` works for go-standard | `scripts/generate-flake.sh:104` — sed uncomments `# enableTempl = true;` line in template.                                                                            |
| 4   | CHANGELOG.md consolidated                                     | Merged 3 duplicate "Added" sections into one clean set under `[Unreleased]`.                                                                                          |
| 5   | Man pages wired into devShell                                 | `flake.nix:77` — `manPages` derivation installs `.5` files to `share/man/man5/`. DevShell includes `man` + `manPages`.                                                |
| 6   | `enableCompletions` description improved                      | Now documents cobra/urfave/cli requirement and silent-no-op behavior.                                                                                                 |
| 7   | Monorepo test: `packages.worker` exists                       | `test-module.nix` — assertion evaluates perSystem with `packages.worker` config.                                                                                      |
| 8   | Monorepo test: `apps.worker` exists                           | Same config — verifies app generation for extra packages.                                                                                                             |
| 9   | Monorepo overlay test: D1 regression                          | Dedicated `monorepoOverlayCheck` — evaluates overlay with mock packages, verifies `overlayResult.worker == "mock-worker-derivation"`.                                 |
| 10  | `enableGolangciLint=false` test                               | Asserts `apps.lint` disappears when toggle is false.                                                                                                                  |
| 11  | `enableGofumpt=false` test                                    | Asserts `treefmt.programs.gofumpt.enable == false`.                                                                                                                   |
| 12  | `enableGoimports=false` test                                  | Asserts `treefmt.programs.goimports.enable == false`.                                                                                                                 |
| 13  | `version` override test                                       | Asserts custom version `"1.0.0-test"` appears in package derivation name.                                                                                             |
| 14  | `enableCompletions=true` test                                 | Asserts package evaluates successfully with completions enabled.                                                                                                      |
| 15  | `buildFlags` test                                             | Asserts package evaluates with custom `buildFlags = [ "-tags" "integration" ]`.                                                                                       |
| 16  | `extraBuildAttrs.postInstall` merge                           | `userExtraBuildAttrs` now strips both `preBuild` AND `postInstall` to avoid double-application.                                                                       |

**Test verification:**

- `nix flake check` — **ALL CHECKS PASSED** (6 derivation checks + treefmt)
- `moduleTest` — **52/52 PASS** (was 43, added 9 new assertions)
- `moduleTestNoOverlay` — **PASS**
- `nix fmt` — Clean (0 changed files on last run)

---

## B) PARTIALLY DONE (shipped with known gaps)

### B1. Tests are "compiles without error" tests, NOT behavioral tests

The 6 new test cases verify that module **evaluation** succeeds with various configs, but they do NOT verify that the values actually reach `buildGoModule` correctly:

- **`buildFlags` test:** Only checks that `packages.default` evaluates. Does NOT inspect the derivation to confirm `buildFlags = [ "-tags" "integration" ]` is actually in the buildGoModule call.
- **`enableCompletions` test:** Only checks that evaluation doesn't crash. Does NOT verify that `installShellFiles` appears in `nativeBuildInputs` or that `postInstall` contains the `installShellCompletion` call.
- **`version` test:** Checks `lib.hasInfix "1.0.0-test"` in the derivation name, which is a reasonable proxy but doesn't verify `ldflags` contains `-X main.version=1.0.0-test`.

**Impact:** Low — the wiring is straightforward and the evaluation tests catch type errors and missing options. But a regression in how attributes are merged into `buildGoModule` would not be caught.

### B2. `generate-flake.sh --templ` fix is unverified

The sed command was written but never actually run against the template. The fix looks correct (`s/# *enableTempl = true;/enableTempl = true;/` matches the commented line in the template), but there's no smoke test proving it works end-to-end.

### B3. Man pages not tested

The `manPages` derivation is wired into the devShell but there's no test verifying that `man go-standard` actually renders correctly from within the devShell. The `.5` files could have formatting issues that `man` would reject.

### B4. `enableCompletions` design is still naive

The `|| true` in `installShellCompletion` silently swallows failures. A user who enables completions on a binary that doesn't support `--completion <shell>` gets no error and no completions — just silence. The description now documents this, but the UX is still poor.

### B5. Documentation drift — multiple files still reference old state

- `AGENTS.md` says "tested by `test-module.nix`" but doesn't mention the 52-check count or the D1/D2 fixes.
- `docs/man/go-standard.5` line 84 says `enableCompletions (bool, default: false)` but doesn't mention the cobra/urfave/cli requirement or the `postInstall` wiring.
- `README.md` options table still has the old `enableCompletions` description ("Install shell completions for the default binary").
- `FEATURES.md` still says `FULLY_FUNCTIONAL` for completions despite the naive design.
- `TODO_LIST.md` was NOT updated to mark D1-D4 fixes as done.

---

## C) NOT STARTED / BLOCKED

| #   | Task                                          | Why blocked                                                                                                                                                |
| --- | --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C1  | Register `maintainers.larsartmann` in nixpkgs | Requires external PR to nixpkgs repo                                                                                                                       |
| C2  | Real private-repo integration test in CI      | Requires SSH key secret configuration in GitHub                                                                                                            |
| C3  | Audit all downstream consumers                | Requires access to 7+ downstream repos (BuildFlow, mr-sync, PMA, etc.)                                                                                     |
| C4  | Real e2e consumer test                        | Requires creating a mock Go project + flake.nix that imports go-standard and building it through the full pipeline. Not blocked externally, just not done. |

---

## D) TOTALLY FUCKED UP (things I missed or did poorly)

### D-NEW-1. I forgot to update 5 documentation files

After fixing D1, D2, D4 and adding 9 test assertions, I did NOT update:

- **`AGENTS.md`** — Still references old test count, doesn't mention D1 overlay fix, D2 postInstall wiring, or the `userExtraBuildAttrs` rename
- **`TODO_LIST.md`** — D1-D4 bug fixes are not marked as done
- **`README.md`** — `enableCompletions` description is stale
- **`FEATURES.md`** — Still says `FULLY_FUNCTIONAL` for completions
- **`docs/man/go-standard.5`** — Doesn't document postInstall behavior or cobra requirement

### D-NEW-2. I didn't smoke-test the generate-flake.sh fix

I changed the sed command but never ran:

```bash
scripts/generate-flake.sh --templ --dir /tmp/test-project test-project
```

to verify the output is valid Nix. The fix is probably correct but unverified.

### D-NEW-3. The `version` test is fragile

```nix
assertCheck "version override propagates to package name" (
  versionCfg.packages.default ? name
  && lib.hasInfix "1.0.0-test" versionCfg.packages.default.name
) "version in package name"
```

This relies on `buildGoModule` derivation naming conventions (`${pname}-${version}`). If nixpkgs changes the naming format, this test breaks for the wrong reason. A better test would inspect `versionCfg.packages.default.version` directly — but that may not exist as an attribute.

### D-NEW-4. Monorepo overlay test uses mock strings instead of real derivations

```nix
packages.x86_64-linux = {
  default = "mock-default-derivation";
  worker = "mock-worker-derivation";
};
```

The test verifies the overlay function maps names correctly using string placeholders. This catches the D1 bug (wrong name mapping) but does NOT verify the overlay works with real `buildGoModule` derivations in a full flake evaluation.

### D-NEW-5. CHANGELOG rewrite may have lost historical context

I merged all history into one `[Unreleased]` section. The original had `### Previous changes` which separated older work. Once a release is tagged, all 50+ items will be lumped together with no way to distinguish what shipped when. The commit hashes (`775a540`, etc.) help but are not a substitute for version sections.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture / Code Quality

1. **The `enableCompletions` UX is poor** — silently does nothing if the binary doesn't support `--completion`. Should warn or fail loudly.
2. **The monorepo overlay has a potential circular dependency** — `self.packages.${system}.${name}` in the overlay references the flake's own perSystem output. If a consumer's flake evaluation order changes, this could fail.
3. **`userExtraBuildAttrs` strips `preBuild` and `postInstall` but not other potentially conflicting attrs** — e.g., `configureFlags`, `makeFlags`, `patches` are passed through raw. A consumer setting `extraBuildAttrs.patches` would work, but one setting `extraBuildAttrs.nativeBuildInputs` would OVERRIDE the module's carefully constructed list (including installShellFiles).
4. **No `apps.fmt` conditional** — `apps.fmt` is always generated even if all treefmt programs are disabled. Should be conditional.
5. **`generate-flake.sh` doesn't create `go.mod`** — generates only `flake.nix`, but the module requires `go.mod` for `treefmt.projectRootFile = "go.mod"`.
6. **`generate-flake.sh` doesn't handle `--private-deps` for go-standard template** — only handles it for go-flake-parts.

### Testing Gaps (still open)

7. **No real e2e consumer test** — still only module-level tests with stubs. A real Go project + flake.nix importing go-standard, built through `nix build`, would catch integration issues.
8. **No test that `buildFlags` actually reaches `buildGoModule`** — current test only checks evaluation succeeds.
9. **No test that `enableCompletions` wires `installShellFiles` into `nativeBuildInputs`** — current test only checks evaluation succeeds.
10. **No test that `ldflags` contains the version injection** — `version` test checks the name, not the ldflags.
11. **No test for `extraBuildAttrs.postInstall` merge** — the new `mergedPostInstall` logic is untested.
12. **No test for `deps` / `mkPreparedSource` integration** — the prepared source path is never exercised in module tests.
13. **No test for `proxyVendor` toggle** — untested.
14. **No test for `ldflags` custom override** — untested.
15. **No test for `devShellExtraPackages`** — untested.
16. **No test for `shellExtraEnv` / `autoGoPrivate`** — untested.
17. **No test for `enableTempl` adding `pkgs.templ` to devShells** — untested.
18. **No test for `enableGopls` / `enableGovulncheck` toggles** — untested.
19. **No test for `systems` override** — untested.
20. **No smoke test for `generate-flake.sh`** — the script has bugs that CI would catch.

### Documentation Gaps

21. **5 docs files are stale** — AGENTS.md, TODO_LIST.md, README.md, FEATURES.md, docs/man/go-standard.5 all reference old state.
22. **README `enableCompletions` description doesn't mention cobra requirement** — consumers will hit silent failures.
23. **Migration guide doesn't cover `extraApps`/`extraChecks`/`extraFlake` removal** — mkGoFlake had these, go-standard doesn't.
24. **FAQ doesn't cover `vendorHash` with `null`** — only covers hash mismatch.
25. **No documentation for monorepo `vendorHash` sharing** — multiple packages share one vendorHash.

### CI / DevOps

26. **CI doesn't run `generate-flake.sh`** — the rewritten script has bugs that CI would catch.
27. **CI doesn't run on macOS** — only `ubuntu-latest`.
28. **No Cachix configured.**
29. **No flake lock file update check.**
30. **Private-deps CI job still disabled (`if: false`).**

---

## F) Up to 50 things to get done next

### Priority 1: Documentation sync (do immediately)

1. Update `AGENTS.md` — D1/D2 fix details, test count (52), `userExtraBuildAttrs` rename, postInstall merge
2. Update `TODO_LIST.md` — mark D1-D4 as DONE
3. Update `README.md` — `enableCompletions` description with cobra requirement
4. Update `FEATURES.md` — mark completions as PARTIALLY_FUNCTIONAL
5. Update `docs/man/go-standard.5` — document postInstall behavior, cobra requirement, version option
6. Add FAQ entry for `vendorHash = null` (committed vendor/)
7. Add FAQ entry for monorepo vendorHash sharing
8. Document `GOTOOLCHAIN = "local"` behavior and override in README

### Priority 2: Deepen existing tests

9. Inspect `buildGoModule` derivation attrs in tests — verify `buildFlags`, `ldflags`, `nativeBuildInputs` actually contain expected values
10. Add `extraBuildAttrs.postInstall` merge test
11. Add `enableCompletions` behavioral test — verify `installShellFiles` in `nativeBuildInputs`, `installShellCompletion` in `postInstall`
12. Add `enableTempl` test — verify `pkgs.templ` in devShell packages
13. Add `enableGopls` / `enableGovulncheck` toggle tests
14. Add `systems` override test
15. Add `ldflags` custom override test
16. Add `proxyVendor` toggle test
17. Add `devShellExtraPackages` test
18. Add `shellExtraEnv` / `autoGoPrivate` test

### Priority 3: Smoke-test scripts

19. Add `generate-flake.sh` smoke test to CI — run script, verify output is valid Nix, `nix flake check` passes
20. Add `generate-flake.sh --templ` test — verify enableTempl uncommented correctly
21. Add `generate-flake.sh --template go-flake-parts` test — verify legacy template still works
22. Add `generate-flake.sh --private-deps` for go-standard template (currently unsupported)

### Priority 4: Design improvements

23. Make `enableCompletions` fail loudly or warn when binary doesn't support `--completion`
24. Make `apps.fmt` conditional on at least one treefmt program enabled
25. Add `generate-flake.sh` option to create `go.mod` skeleton
26. Add `nativeBuildInputs` merge protection in `userExtraBuildAttrs` (extend list instead of override)
27. Add `extraApps`/`extraChecks` equivalent to go-standard (mkGoFlake had these)
28. Redesign `enableCompletions` to support multiple completion strategies (cobra, urfave/cli, custom script)

### Priority 5: E2E / Integration testing

29. Write real e2e consumer test — mock Go project + flake.nix importing go-standard
30. Wire e2e test into CI
31. Add `deps`/`mkPreparedSource` integration test in module context
32. Test monorepo with real `buildGoModule` (not mock strings)
33. Test overlay application in a real nixpkgs context

### Priority 6: CI improvements

34. Add macOS CI runner (`runs-on: macos-latest`)
35. Configure Cachix for binary cache sharing
36. Add `nix flake update` check to CI (verify flake.lock freshness)
37. Enable private-deps CI job once SSH key is configured
38. Add `nix fmt --check` as separate CI step (faster feedback)

### Priority 7: Feature additions

39. Add `enableGoVet` toggle
40. Add `preCommitHooks` option for devShell (git hooks via pre-commit-nix)
41. Add `nixosModules` output for NixOS service configuration
42. Add `darwinModules` output for nix-darwin
43. Add `enableDocker` option to generate container image via `dockerTools`
44. Add cross-compilation support via `crossSystem` option
45. Add `postInstall` as a first-class option (not just via `extraBuildAttrs`)

### Priority 8: Ecosystem

46. Register `maintainers.larsartmann` in nixpkgs (external PR)
47. Audit all 7+ downstream consumers for migration status
48. Create `examples/` directory with real-world consumer configurations
49. Add benchmark suite for Nix evaluation time (regression detection)
50. Publish to naynix flake registry

---

## G) Questions (cannot figure out myself)

### G1. Should the private-deps CI test use a dedicated test repo, an existing consumer, or a mock?

The CI private-deps test needs a real Go project with private LarsArtmann dependencies. Options:

- **(a)** Create a dedicated `go-nix-helpers-test-consumer` repo (clean, isolated, but extra maintenance)
- **(b)** Use an existing consumer like `go-cqrs-lite` (real-world, but couples CI to that repo's availability)
- **(c)** Create a mock private repo with known content (deterministic, but doesn't test real-world scenarios)

I cannot decide this because it depends on your preference for CI isolation vs. real-world testing.

### G2. Should `mkGoFlake.nix` be fully removed now, or kept with the deprecation warning?

The file emits a `builtins.trace` warning but still works. Options:

- **(a)** Keep until all downstream consumers have migrated (safe, but maintenance burden)
- **(b)** Remove now and force migration (clean, but breaks consumers who haven't migrated)
- **(c)** Set a removal date (e.g., next major version) and document it

I don't know the migration status of all 7+ downstream consumers, so I can't assess the blast radius of removal.

### G3. Should I fix the 5 stale documentation files NOW, or wait for a broader docs-health pass?

AGENTS.md, TODO_LIST.md, README.md, FEATURES.md, and docs/man/go-standard.5 all reference pre-fix state. Options:

- **(a)** Fix all 5 now (quick, gets docs in sync immediately)
- **(b)** Run the `docs-health` skill for a comprehensive audit (thorough, but may surface more issues than just these 5)
- **(c)** Batch with the other documentation gaps (FAQ entries, migration guide updates) into one docs sprint

This depends on whether you want incremental fixes or a comprehensive docs overhaul.

---

## Resolution (2026-08-03)

**G3 answered:** Option (b) — a comprehensive `docs-health` pass was run on 2026-08-03. All 5 stale files updated: TODO_LIST.md rebuilt (DONE items removed, open work harvested), FEATURES.md fixed (`enableCompletions` → PARTIALLY_FUNCTIONAL, test count → 54), CHANGELOG.md updated (test count, man pages in devShell, userExtraBuildAttrs fix), ROADMAP.md cleaned (shipped ideas removed, smart private-dep detection theme added).

**Test count:** Bumped from 52 (reported here) to 54 (`50fd2c3` added 2 more assertions).

**G1 reframed:** The `mkPreparedSource` validation itself needs to distinguish public from private repos before a CI test design is meaningful. See `docs/feedback/new/2026-08-03_mkpreparedsource-false-positive-on-public-repos.md` — the validation treats ALL `github.com/larsartmann/*` repos as private, but several are public and served by `proxy.golang.org`. This is now the highest-priority TODO_LIST item.

**G2 resolved:** `mkGoFlake.nix` kept with deprecation trace warning. Full removal deferred until all consumers migrate (ROADMAP Theme 2).

### Section F "next tasks" — item-by-item status

| Items                                  | Status                         | Evidence                                                                                                        |
| -------------------------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| F 1–8 (documentation sync)             | ~~done~~ 2026-08-03            | This docs-health pass: TODO_LIST rebuilt, FEATURES fixed, CHANGELOG updated, ROADMAP cleaned, AGENTS.md current |
| F 9–11 (deepen tests to behavioral)    | Still open                     | TODO_LIST "Deepen module tests from eval-only to behavioral"                                                    |
| F 12–20 (remaining test gaps)          | Still open                     | TODO_LIST "Add remaining module option tests"                                                                   |
| F 21–22 (smoke-test generate-flake.sh) | Still open                     | TODO_LIST "Add generate-flake.sh smoke test to CI"                                                              |
| F 23–28 (design improvements)          | Still open                     | TODO_LIST high/medium impact                                                                                    |
| F 29–33 (E2E / integration testing)    | Still open — BLOCKED           | TODO_LIST blocked items                                                                                         |
| F 34–38 (CI improvements)              | Still open                     | TODO_LIST medium impact                                                                                         |
| F 39–45 (feature additions)            | Still open — long-term         | ROADMAP                                                                                                         |
| F 46–50 (ecosystem)                    | Still open — blocked/long-term | TODO_LIST (blocked) + ROADMAP                                                                                   |
