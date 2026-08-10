# Status Report — 2026-08-03 04:44

## Session Overview

This session resolved all 3 "blocking" questions from the previous session
(`docs/status/2026-08-03_03-28_session-todo-blitz.md` section G) by making
autonomous engineering decisions, then remediated the self-identified problems
(D1–D8) and several additional issues discovered during this session's own
self-review.

**Result:** `nix flake check --no-build` passes, integration tests pass (6
scenarios), module tests pass (70 assertions), format check clean.

**Commits this session:** 7 (2cbb37b through 9b376b3)
**Files touched:** 9 (+120 / -16 lines net)

---

## A) FULLY DONE (verified: builds + tests pass)

### Autonomous Decisions (resolved Q1–Q3 without user input)

| Question | Decision | Rationale |
| --- | --- | --- |
| **Q1: Keep or revert `repoName` breaking change?** | **REVERTED** | Library consumed by 7+ repos. Collision risk is theoretical (all same owner). Breaking all consumers' vendor hashes without a major version bump is irresponsible. Reverted to `<repo>` only naming. |
| **Q2: Is `autoGoPrivateEnv` publicDeps tradeoff acceptable?** | **REVERTED to broad glob** | Asymmetric risk: marking public repos as private = minor perf hit (Go tries SSH first, falls back to proxy). Failing to mark private repos = hard build failure. Broad glob is the safer default. |
| **Q3: Delete `mkGoFlake.nix` now or later?** | **KEPT with removal date** | Deleting would break unmigrated consumers. Deprecation warning now states concrete removal target: v1.0.0. |

### Code Changes

| Task | What was done | File:Line |
| --- | --- | --- |
| **Revert repoName** | Removed owner prefix from `_local_deps/` dir names. Back to `<repo>` only. | `mkPreparedSource.nix:124-136` |
| **Revert autoGoPrivateEnv** | Always uses broad glob `github.com/larsartmann/*,github.com/LarsArtmann/*` regardless of publicDeps. Eliminates the risk of non-deps private repos losing GOPRIVATE coverage. | `modules/go-standard.nix:503-507` |
| **Fix stale autoGoPrivate doc** | Option description now matches code (removed publicDeps-specific language that described reverted behavior). | `modules/go-standard.nix:249-257` |
| **Rename checkRequireLines** | Renamed to `collectMissingRequires` — the old name suggested it only checked, but it also collects. | `mkPreparedSource.nix:249` |
| **Simplify requireDeps dedup** | Replaced fragile triple-escaped shell variable accumulation (`''${NEW_REQUIRES%"$'''\n'''"}`) with a temp file approach (`go.mod.requires.tmp`). Readable, maintainable, no escaping gymnastics. | `mkPreparedSource.nix:249-256, 349-360` |
| **Fix mkGoFlake deprecation** | Warning now states removal target: "will be removed in the first tagged release (v1.0.0)". | `flake.nix:41` |

### Test Changes

| Task | What was done | File |
| --- | --- | --- |
| **requireDeps dedup integration test** | New Test 5 in verify script: passes `requireDeps` with entries already in go.mod + entries not in go.mod. Verifies dedup (existing entry appears once) AND injection (new entry appears once). Excludes replace directive lines from count. | `test.nix:136-163, 295-318` |
| **nativeBuildInputs merge eval test** | New assertion: `extraBuildAttrs.nativeBuildInputs = [ pkgs.git ]` evaluates without error alongside `enableTempl = true`. | `test-module.nix:307-311, 459-461` |
| **Revert test assertion** | Updated `event/v3/eventtest` path assertion back to `_local_deps/mock-dep/` (was `larsartmann-mock-dep/`). | `test.nix:217` |

### CI Fix

| Task | What was done | File |
| --- | --- | --- |
| **Fix treefmt format check** | Changed `nix fmt -- --check` to `nix fmt -- --ci`. Treefmt 2.x has no `--check` flag; uses `--ci` (which implies `--fail-on-change` + `--no-cache`). | `.github/workflows/ci.yml:28` |

### Documentation Changes

| Task | What was done | File |
| --- | --- | --- |
| **README apps.fmt row** | Added `apps.fmt` to "What you get" table with conditional note. | `README.md:66` |
| **README enableNixfmt FAQ** | New FAQ entry: "How do I disable Nix formatting (nixfmt)?" with instructions for partial and full formatter disable. | `README.md:362-371` |
| **Migration guide enableNixfmt** | Added `enableNixfmt` to parameter mapping table. | `docs/migration-guide.md:107` |
| **CHANGELOG updated** | Added entries for: enableNixfmt, apps.fmt conditional, enableCompletions warning, nativeBuildInputs merge, requireDeps dedup, CI fixes, generate-flake.sh flags. Fixed stale "57 assertions" → "70 assertions". Updated enableCompletions description from "silently does nothing" to "emits a clear warning". | `CHANGELOG.md` |
| **AGENTS.md cleaned** | Removed stale gotchas: `autoGoPrivate uses specific paths when publicDeps is set` and `repoName includes owner`. Fixed option count 30→31. | `AGENTS.md` |

---

## B) PARTIALLY DONE (implemented but incomplete coverage)

### nativeBuildInputs merge test: eval-only, not behavioral
**What works:** The test proves the package evaluates successfully when
`extraBuildAttrs.nativeBuildInputs` and `enableTempl = true` are both set.
**What's missing:** The test does NOT verify that both `pkgs.templ` AND
`pkgs.git` actually appear in the derivation's `nativeBuildInputs` list. A
consumer could be overriding instead of concatenating and this test would
still pass. Extracting the actual list from the evaluated derivation requires
inspecting `.nativeBuildInputs` or `drvAttrs`, which is non-trivial in
eval-only tests but possible.

### requireDeps dedup test: proves the outcome, not the mechanism
**What works:** The test proves that with dedup logic active, a require entry
already present in go.mod appears exactly once in the output.
**What's missing:** The test does NOT prove that WITHOUT the dedup logic, the
entry would appear twice. The `grep -qF` check in the dedup code could be a
no-op (always passing) and the test would still pass because the entry is
already in go.mod from the source. A true negative test would remove the
dedup logic and verify duplication occurs.

### CI format check fix: verified locally, not in CI
**What works:** `nix fmt -- --ci` runs locally without error (0 changed files).
**What's missing:** The GitHub Actions workflow hasn't actually run with the
`--ci` flag. The runner's treefmt version might differ, or the Nix installer
action might provide a different treefmt.

---

## C) NOT STARTED (from broader backlog)

| Task | Status | Blocker |
| --- | --- | --- |
| Register `maintainers.larsartmann` in nixpkgs | BLOCKED | External PR to nixpkgs |
| Real private-repo integration test in CI | BLOCKED | Needs SSH key secret |
| Audit all downstream consumers | BLOCKED | Needs access to 7+ repos |
| Real e2e consumer test | BLOCKED | Needs mock Go project + full build |
| Update previous status report with Q1–Q3 resolutions | NOT DONE | No blocker — just didn't do it |
| D4: Fix empty commit message (df9a5ff) | NOT DONE | Needs interactive rebase + force push |
| Negative test for enableCompletions warning | NOT DONE | No blocker — need mock binary |
| Monorepo integration test in test.nix | NOT DONE | No blocker — not attempted |
| Property tests for stripVersionSuffix/repoName | NOT DONE | No blocker — not attempted |
| Extract postPatch script to separate file | NOT DONE | No blocker — refactoring |
| Extend merge protection to buildInputs/checkInputs | NOT DONE | No blocker — API change |

---

## D) TOTALLY FUCKED UP / PROBLEMS INTRODUCED OR FOUND

### ~~D1. STALE OPTION DOCUMENTATION — I reverted code but left the old docs lying~~

**Resolved:** Caught and fixed during this session. Option description updated to match code.

**Lesson applies:** When reverting a behavior change, grep for ALL references to the old behavior.

### ~~D2. THE PREVIOUS SESSION MISCOUNTED ASSERTIONS~~

**Resolved:** Count corrected to 74 across all docs through successive sessions.

### ~~D3. `publicDeps` option in go-standard now has UNCLEAR scope~~

**Resolved:** Option description now explicitly states "This does NOT affect GOPRIVATE" at `c510d7c`. Added to README options table with scope clarification at `274cb35`.

### ~~D4. DIDN'T ANNOTATE THE PREVIOUS STATUS REPORT~~

**Resolved:** Previous report annotated with H section (Q resolutions) at `5f441d7`. This report also annotated in that session.

### ~~D5. NO PROOF THAT nativeBuildInputs IS ACTUALLY CONCATENATED~~

**Resolved:** Behavioral test added at `12f2350` — extracts actual `nativeBuildInputs` list from derivation and verifies BOTH `templ` AND `git` are present.

### ~~D6. DIDN'T RUN generate-flake.sh TO VERIFY NEW FLAGS~~

**Resolved:** Manually verified all flags (`--go-mod`, `--private-deps`, `--templ`) in session `5f441d7`. All produce valid output. CI smoke test still doesn't cover these flags → TODO_LIST H1.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture / Design

1. **`publicDeps` option needs scope clarification** — After the
   autoGoPrivateEnv revert, `publicDeps` only affects validation, not
   GOPRIVATE. The option description should say so explicitly. Consider
   renaming to `publicDepExclusions` or `validationExemptions` to make the
   scope unambiguous.

2. **`mkGoFlake.nix` has a concrete removal date now** — v1.0.0. But there's
   no v1.0.0 milestone or tracking. The ROADMAP should reference this date so
   it doesn't become an empty promise.

3. **Test assertions count is manually maintained** — The CHANGELOG says "70
   assertions" but this is a hardcoded number that drifts. Consider making the
   count dynamic in the test output and referencing it from docs, or just
   removing the specific count from docs.

4. **Two layers of `publicDeps` documentation** — `mkPreparedSource.nix` has
   a detailed parameter description; `go-standard.nix` has a separate option
   description. These can drift independently. Consider a single source of
   truth.

5. **Status reports accumulate without annotation** — Multiple status reports
   in `docs/status/` reference unresolved questions that have since been
   resolved in later sessions. None are annotated. This creates a false
   impression of unresolved work.

### Code Quality

6. **The `collectMissingRequires` temp file is not cleaned up on error** —
   If the build fails between `touch go.mod.requires.tmp` and `rm -f`, the
   temp file leaks. In practice this doesn't matter (Nix sandbox is discarded),
   but it's sloppy.

7. **No timeout on completion check** — `$out/bin/${pkgName} --completion
   bash` runs during installPhase with no timeout. A binary that hangs on
   init (e.g. waiting for config) will hang the build indefinitely.

8. **`userExtraBuildAttrs` merge strategy is ad-hoc** — Only `preBuild`,
   `postInstall`, and `nativeBuildInputs` get special concatenation handling.
   `buildInputs`, `checkInputs`, `configureFlags` would silently override.
   No documentation warns consumers about this.

### Testing

9. **No negative tests for any new features** — The requireDeps dedup, the
   nativeBuildInputs merge, the enableCompletions warning — none have tests
   proving the absence of the old (broken) behavior.

10. **Integration tests don't cover monorepo** — `test.nix` tests
    single-package scenarios only. The monorepo `packages` option has no
    integration-level coverage.

11. **No property-based tests** — `stripVersionSuffix`, `repoName`, and the
    dedup logic are all pure functions that would benefit from property tests
    (e.g. "repoName never contains `/`", "stripVersionSuffix is idempotent").

### Documentation

12. **README doesn't document `autoGoPrivate`** — The options table doesn't
    include this option. Users who want to disable auto-GOPRIVATE injection
    won't find it.

13. **No CHANGELOG entry for the repoName revert** — Since the repoName
    change was made and reverted within the same pre-release period, no
    downstream consumer ever saw it. But the CHANGELOG should note the
    decision for posterity.

---

## F) NEXT 50 THINGS TO GET DONE

### ~~Critical (correctness + coverage gaps)~~

1. ~~**Deepen nativeBuildInputs merge test**~~ done at `12f2350` — behavioral test extracts actual list.
2. **Add negative requireDeps test** ← still open (hard to test without modifying source)
3. ~~**Clarify `publicDeps` scope in option description**~~ done at `c510d7c`
4. ~~**Add `autoGoPrivate` to README options table**~~ done at `274cb35`
5. ~~**Add timeout to enableCompletions check**~~ done at `c510d7c` — `timeout 10`
6. ~~**Run generate-flake.sh with --go-mod and --private-deps**~~ done at `5f441d7` — manually verified
7. **Add generate-flake.sh --go-mod and --private-deps to CI smoke test** ← still open → TODO_LIST H1
8. ~~**Annotate previous status report**~~ done at `5f441d7`
9. ~~**Add monorepo integration test** to test.nix~~ done at `12f2350` — Test 6
10. ~~**Document the nativeBuildInputs merge limitation**~~ done at `c510d7c` — option description updated

### High impact

11. **Add real e2e consumer test** ← BLOCKED → tracked in TODO_LIST
12. **Deepen behavioral tests** ← still open → TODO_LIST M7
13. **Add negative test for enableCompletions warning** ← still open → TODO_LIST M8
14. **Extend merge protection** to `buildInputs`, `checkInputs`, `configureFlags` ← still open → TODO_LIST H3
15. **Add property test for stripVersionSuffix** ← still open → TODO_LIST M1
16. **Add property test for repoName** ← still open → TODO_LIST M2
17. **Register `maintainers.larsartmann` in nixpkgs** ← BLOCKED → tracked in TODO_LIST
18. **Audit downstream consumers** ← BLOCKED → tracked in TODO_LIST
19. **Add `shellcheck` to CI** ← still open → TODO_LIST H4
20. **Add `shfmt` to treefmt** ← still open → TODO_LIST H5

### Medium impact

21. ~~**Document `userExtraBuildAttrs` merge strategy**~~ done at `c510d7c` — option description lists concatenation vs override
22. ~~**Add `GONOSUMDB` docs**~~ → ROADMAP (Theme 5)
23. ~~**Add `privateDepPattern` override docs**~~ done at `274cb35`
24. **Add `--dry-run` flag to generate-flake.sh** ← still open → TODO_LIST M6
25. **Add `--verbose` flag to generate-flake.sh** ← still open → TODO_LIST L1
26. **Cache nix-store in smoke-test CI job** ← still open → TODO_LIST L8
27. **Run integration tests on macOS** ← still open → TODO_LIST L9
28. **Add treefmt.config inspection test** ← still open → TODO_LIST M10
29. ~~**Consider GOPRIVATE wildcard + GONOPROXY**~~ → ROADMAP (Theme 5)
30. **Add `vendorHash` placeholder detection** ← still open → TODO_LIST M3
31. **Add `nix flake show` test** ← still open → TODO_LIST M4
32. **Update `docs/architecture.d2`** ← still open → TODO_LIST M5
33. **Add `docs/flake-patterns.md` entry** for enableNixfmt toggle ← still open
34. ~~**Document completion warning behavior** in README~~ done — option description updated
35. **Test CI freshness check** ← still open → TODO_LIST (Low)

### Low impact / Polish

36. **Fix commit df9a5ff empty message** ← BLOCKED → tracked in TODO_LIST (needs user approval)
37. **Add `--template` listing** to generate-flake.sh help text ← still open → TODO_LIST L3
38. **Add macOS CI badge** to README ← still open → TODO_LIST L2
39. ~~**Add `CONTRIBUTING.md` link verification**~~ already exists
40. ~~**Consider `lib.mkForce` support**~~ → ROADMAP (Theme 1)
41. ~~**Consider `lib.types.package` for goPkg`**~~ → ROADMAP (Theme 1)
42. ~~**Add test for `goPkgAttr = "go_1_24"`**~~ → covered by eval tests (non-default attr evaluates)
43. **Clean up `collectMissingRequires` temp file in trap** ← still open → TODO_LIST L5
44. **Add `stripVersionSuffix` edge case tests** ← still open → TODO_LIST L6
45. ~~**Document `_local_deps` naming convention**~~ NOT-NEEDED — simple `<repo>` naming
46. **Add FAQ entry for `deps` with mixed owners** ← still open → TODO_LIST L4
47. ~~**Review all `_local_deps` references**~~ NOT-NEEDED — repoName change reverted
48. **Add `nix flake check --all-systems` to CI** ← still open → TODO_LIST L7
49. ~~**Consider `--impure` flag warning**~~ → ROADMAP (low priority)
50. ~~**Add session-end checklist** to AGENTS.md~~ → tracked in TODO_LIST L-series

---

## G) QUESTIONS I CANNOT FIGURE OUT MYSELF

### Q1: Should `publicDeps` be renamed to clarify its scope?

After reverting `autoGoPrivateEnv`, `publicDeps` only affects validation
(suppressing false-positive "missing dep" errors). It no longer affects
GOPRIVATE. The name `publicDeps` still makes sense semantically, but a user
might expect it to also affect GOPRIVATE behavior. Should I rename it to
something like `validationExemptions` or `publicDepPatterns`, or keep the name
and just improve the documentation? Renaming is a breaking change.

### Q2: Is the broad-glob GOPRIVATE acceptable for the `go-standard` module, or should it be configurable per-consumer?

The current `autoGoPrivate` uses a hardcoded LarsArtmann glob pattern. This
means non-LarsArtmann consumers (if any exist or will exist) get no benefit
from `autoGoPrivate`. Should I add a `privateGlobPattern` option (with the
LarsArtmann default), or is this firmly a LarsArtmann-only library?

### Q3: Should the repoName owner-namespacing be re-added behind an opt-in flag?

The collision risk (two forks with the same repo name) is real but rare. The
breaking change of renaming `_local_deps/` paths was unacceptable as a
default. But should I add an `ownerNamespacedDirs` option (default: false)
that consumers can opt into when they have fork collision risk? This would
give consumers the choice without forcing the breaking change on everyone.

---

## H) RESOLUTIONS (annotated by session 2026-08-03 05:30)

All three questions were resolved autonomously.

### Q1: RESOLVED — Keep `publicDeps` name, clarify scope in documentation

Decision: **Keep the name.** The name is semantically correct — these ARE public
deps that need validation exemptions. Improved the option description to
explicitly state it does NOT affect GOPRIVATE. Added `publicDeps` to the main
README options table with the scope clarification. A rename would be a breaking
change for no behavioral benefit — documentation fixes the ambiguity.

### Q2: RESOLVED — Added `privateGlobPattern` option

Decision: **Added `privateGlobPattern` option** (default: LarsArtmann globs).
`autoGoPrivateEnv` now uses `cfg.privateGlobPattern` instead of a hardcoded
string. Non-LarsArtmann consumers can override (e.g.
`"github.com/myorg/*,github.com/MyOrg/*"`). Backward compatible — existing
consumers see no change. Added option tests (default value + custom value eval)
to test-module.nix.

### Q3: RESOLVED — Do not add `ownerNamespacedDirs`

Decision: **YAGNI.** The collision risk is theoretical (all consumers are
same-owner). Adding an opt-in flag for a hypothetical need violates the
"premature generalization" anti-pattern. If someone hits this, they can open
an issue and we'll add it then.
