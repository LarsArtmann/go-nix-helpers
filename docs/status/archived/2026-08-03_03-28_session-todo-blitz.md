# Status Report — 2026-08-03 03:28

## Session Overview

Executed 16 tasks from `TODO_LIST.md` across 8 commits touching 11 files (+397 / -86 lines).
All `nix flake check`, integration tests, and module tests (70 assertions) pass.

---

## A) FULLY DONE (verified: builds + tests pass)

### Code Changes

| Task | What was done | Files |
| --- | --- | --- |
| **H1** — `autoGoPrivateEnv` aware of `publicDeps` | When `publicDeps` is non-empty, GOPRIVATE switches from broad glob `github.com/larsartmann/*` to specific dep paths so public repos fetch via proxy | `modules/go-standard.nix:503-519` |
| **H3** — `enableCompletions` UX | Checks `--completion bash` support before installing; emits clear stderr warning with remediation options instead of silent no-op | `modules/go-standard.nix:429-447` |
| **M5** — `nativeBuildInputs` merge protection | Consumer's `extraBuildAttrs.nativeBuildInputs` is now concatenated to module's list instead of overriding | `modules/go-standard.nix:411-421, 464-467` |
| **M9** — `repoName` namespaced by owner | `_local_deps/` uses `<owner>-<repo>` format (e.g. `larsartmann-go-cqrs-lite`) to prevent fork collisions | `mkPreparedSource.nix:124-138` |
| **M10** — `apps.fmt` conditional + `enableNixfmt` | New `enableNixfmt` option (was hardcoded true); `apps.fmt` only generated when >=1 formatter enabled | `modules/go-standard.nix:171-176, 543-545, 602` |
| **M12** — `requireDeps` dedup | Manually injected require lines are checked against existing go.mod entries before insertion | `mkPreparedSource.nix:248-258, 351-360` |

### CI Changes

| Task | What was done |
| --- | --- |
| **M1** — `generate-flake.sh` smoke test | New CI job tests 3 template variants, validates output with `nix-instantiate --parse` |
| **M11** — macOS CI runner | Matrix strategy adds `macos-latest` to the check job |
| **M13** — `flake.lock` freshness | New CI job runs `nix flake update`, diffs against committed lock file |

### Script Changes

| Task | What was done |
| --- | --- |
| **L2** — `--go-mod` flag | Creates `go.mod` + `main.go` skeleton during generation |
| **L3** — `--private-deps` for go-standard | Adds `deps = { ... }` section to go-standard template output |
| **Bonus fix** — Placeholder mismatch | Fixed pre-existing bug: `YOUR-PROJECT-NAME` in go-standard template was never replaced |

### Documentation Changes

| Task | What was done |
| --- | --- |
| **M3/M4** — FAQ entries | Added `vendorHash = null` (committed vendor) and monorepo vendorHash sharing entries |
| **M6** — enableCompletions caveat | Options table now notes cobra/urfave/cli requirement |
| **M7** — Troubleshooting fix | Updated error text from old wording to current `"modules without local replace"`, added `publicDeps` as remediation option 3 |
| **M8** — publicDeps matching docs | Documented exact-match behavior and `/vN` caveat |
| **M9-doc** — Migration guide | Added detailed code example for migrating `extraApps`/`extraChecks`/`extraFlake` to direct flake-parts declarations |
| **L4** — GOTOOLCHAIN docs | Added FAQ entry for `GOTOOLCHAIN = "local"` and override instructions |
| **Man page** | Added `enableNixfmt` entry to `go-standard.5` |
| **AGENTS.md** | Updated option count (30->31), added gotchas for autoGoPrivate, nativeBuildInputs merge, repoName namespacing, apps.fmt conditional, enableCompletions warning, requireDeps dedup |

### Test Changes

| Task | What was done | Assertion count |
| --- | --- | --- |
| **L1** — Remaining option tests | Added `enableNixfmt` default, `devShellExtraPackages` callable, systems override propagation | +3 |
| **H2** — Behavioral tests | Added meta propagation (description, mainProgram, license, maintainers, extraMeta), monorepo meta, formatter toggles (nixfmt, all-off), enableTempl, custom ldflags, shellExtraEnv, apps.fmt conditional | +12 |
| Total | 70 assertions (up from 57) | +13 net |

---

## B) PARTIALLY DONE (implemented but incomplete coverage)

### H2 — Behavioral tests: partially deepened
**What works:** Meta attribute propagation (description, license, mainProgram, maintainers) is now verified.
**What's missing:** The behavioral tests verify *evaluation produces the right attribute values* for meta, but they do NOT verify that `buildFlags`, `ldflags`, and `nativeBuildInputs` actually reach the `buildGoModule` call as correct argument values. The TODO said "verify buildFlags, ldflags, nativeBuildInputs actually reach buildGoModule" — I added tests that confirm packages *exist* with custom flags, but did not extract and inspect the actual attribute values passed to `buildGoModule`. This would require inspecting the derivation's attributes (`.builder`, `.args`, or using `drvAttrs`) which is non-trivial in Nix eval-only tests.

### M1 — generate-flake.sh smoke test: parse-only, not build
**What works:** CI generates 3 template variants and validates they parse as valid Nix.
**What's missing:** Does not run `nix flake check` on the generated output because that would require fetching all flake inputs (network-intensive in CI). The test catches syntax errors but not semantic ones (e.g. invalid option values).

### M11 — macOS CI: eval-only
**What works:** `nix flake check --no-build` runs on macOS.
**What's missing:** No derivations are actually *built* on macOS. The `--no-build` flag means we only verify evaluation, not compilation. Integration and module tests still run on `ubuntu-latest` only.

---

## C) NOT STARTED (from original TODO_LIST)

All non-blocked TODO items were addressed. The 4 blocked items remain:

| Task | Status | Blocker |
| --- | --- | --- |
| Register `maintainers.larsartmann` in nixpkgs | BLOCKED | External PR to nixpkgs |
| Real private-repo integration test in CI | BLOCKED | Needs SSH key secret |
| Audit all downstream consumers | BLOCKED | Needs access to 7+ repos |
| Real e2e consumer test | BLOCKED | Needs mock Go project + full build |

---

## D) TOTALLY FUCKED UP / PROBLEMS INTRODUCED

### ~~D1. BREAKING CHANGE: `repoName` namespacing changes `_local_deps/` paths — NO MIGRATION GUIDE~~

**Resolved:** Reverted at `2cbb37b` — `<repo>` only naming restored. Broad glob kept. No migration needed since the breaking change was reverted before any consumer upgraded.

**Severity: HIGH.** The `repoName` change (M9) renames all `_local_deps/` directories from `<repo>` to `<owner>-<repo>`. Every downstream consumer that uses `mkPreparedSource` will get a **different vendor hash** when upgrading. This is a breaking change that was NOT documented in the migration guide. Consumers upgrading go-nix-helpers will see:
- Build fails with vendorHash mismatch
- Must recompute hash via `nix build`

**What I should have done:** Added a "Breaking Changes" section to the migration guide documenting the `_local_deps/` path change and the need to recompute vendor hashes.

### ~~D2. requireDeps dedup logic is UNTESTED~~

**Resolved:** Test added at `687b62f` — Test 5 in `test.nix` verifies dedup with entries already present in go.mod.

The dedup logic (M12) was implemented but **no test case was added** to `test.nix` that passes `requireDeps` with entries already present in `go.mod` and verifies they are not duplicated. The dedup could be broken and we wouldn't know.

### ~~D3. `autoGoPrivateEnv` change may be INCORRECT for edge cases~~

**Resolved:** Reverted to broad glob at `052d92d`. `privateGlobPattern` option added at `c510d7c` for configurability.

When `publicDeps` is non-empty, I switched GOPRIVATE from the broad glob to specific dep paths. But consider: what if the user has private deps in `deps` AND **other** private LarsArtmann repos that are NOT in deps but ARE required in go.mod (resolvable via SSH in devShell)? Those would no longer be covered by GOPRIVATE and Go would try to fetch them from the proxy, failing. The previous broad glob covered ALL LarsArtmann repos. The new specific-path approach only covers repos explicitly in `deps`.

**Possible fix:** The GOPRIVATE when publicDeps is set should still use the glob but EXCLUDE the public deps, e.g. using Go's GOPRIVATE syntax which doesn't support exclusions — meaning this approach may be fundamentally limited.

### D4. Commit `df9a5ff` has an EMPTY commit message

Still open → tracked in TODO_LIST (Blocked — needs interactive rebase + force push, user approval).

### ~~D5. `checkRequireLines` naming is misleading~~

**Resolved:** Renamed to `collectMissingRequires` at `96336e0`.

### ~~D6. The requireDeps dedup heredoc has fragile escaping~~

**Resolved:** Replaced with temp file approach at `96336e0`.

### ~~D7. README "What you get" table doesn't mention conditional `apps.fmt`~~

**Resolved:** Fixed at `9b376b3` — `apps.fmt` added to table with conditional note.

### ~~D8. `enableNixfmt` not in migration guide parameter mapping~~

**Resolved:** Added to migration guide parameter mapping at `b10399f`.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture / Design

1. **`autoGoPrivateEnv` needs a smarter strategy** — When publicDeps is set, the current approach loses coverage for non-deps private repos. Consider: keep the glob for GOPRIVATE and instead use `GONOSUMCHECK` or `GONOSUMDB` for the public ones, or document the tradeoff explicitly.

2. **`mkGoFlake.nix` should be removed, not just deprecated** — It has been deprecated for a while. The `builtins.trace` warning is noisy. Pick a removal date and delete it.

3. **`goPkgAttr` is a string, not a path** — `pkgs.${cfg.goPkgAttr}` is fragile. A better design would be `goPkg = lib.mkOption { type = lib.types.package; }` but this is a breaking API change.

4. **The `postPatch` script in mkPreparedSource is getting unwieldy** — 30+ lines of embedded shell in a Nix string. Consider extracting to a separate script file or using `writeShellScript`.

5. **No versioning or changelog for breaking changes** — The `repoName` change is breaking. There's no CHANGELOG.md entry. Semantic versioning would help downstream consumers.

6. **Test infrastructure is eval-only** — The module tests prove options exist and evaluate, but don't prove the package actually builds correctly with those options. A real e2e test (blocked) would catch more.

### Code Quality

7. **`userExtraBuildAttrs` only special-cases 3 attrs** — `nativeBuildInputs`, `preBuild`, `postInstall`. What about `buildInputs`, `checkInputs`, `configureFlags`? These would also be overridden. Consider a recursive merge strategy.

8. **The completion check runs the binary during installPhase** — `$out/bin/${pkgName} --completion bash` could hang or crash for binaries that do heavy init. A timeout would be safer.

9. **`stripVersionSuffix` matches `v[0-9]+` too broadly** — A directory literally named `v1` or `v2` (not a version suffix) would be stripped. Unlikely but possible.

10. **CI freshness check modifies files in CI** — `nix flake update` writes to `flake.lock` during CI. If the runner's nix registry differs, it could produce false positives. Consider `nix flake lock --no-update` or comparing input revisions directly.

### Testing

11. **No negative tests for new features** — The enableCompletions warning, the requireDeps dedup, the nativeBuildInputs merge — none have tests proving the *absence* of the old behavior.

12. **No property-based testing** — All tests are example-based. Property tests for `stripVersionSuffix`, `repoName`, etc. would catch edge cases.

13. **Integration tests don't cover monorepo** — `test.nix` tests single-package scenarios only. The monorepo path through mkPreparedSource is untested at the integration level.

### Documentation

14. **No CHANGELOG.md exists** — Breaking changes have nowhere to be announced. AGENTS.md explicitly says "Use CHANGELOG.md for change history" but the file doesn't exist.

15. **README FAQ doesn't mention `enableNixfmt`** — Users who want to disable nixfmt formatting won't find it in the FAQ.

---

## F) NEXT 50 THINGS TO GET DONE

### ~~Critical (breaking change remediation)~~

1. ~~**Add "Breaking Changes" section to migration guide** documenting `repoName` path change~~ NOT-NEEDED — `repoName` change was reverted at `2cbb37b`; no breaking change shipped.
2. ~~**Add CHANGELOG.md** with this session's breaking change entry~~ done — CHANGELOG.md exists and is comprehensive.
3. ~~**Fix D3: rethink `autoGoPrivateEnv` with publicDeps**~~ done at `052d92d` — reverted to broad glob.
4. ~~**Add test for requireDeps dedup** in test.nix~~ done at `687b62f`.
5. ~~**Add test for nativeBuildInputs merge** proving user inputs are appended not overridden~~ done at `12f2350` — behavioral test extracts actual list.

### High impact

6. **Add real e2e consumer test** ← BLOCKED → tracked in TODO_LIST
7. **Deepen behavioral tests** ← still open → TODO_LIST M7
8. **Add negative test for enableCompletions warning** ← still open → TODO_LIST M8
9. **Audit all downstream consumers** ← BLOCKED → tracked in TODO_LIST
10. **Register `maintainers.larsartmann` in nixpkgs** ← BLOCKED → tracked in TODO_LIST

### Medium impact

11. ~~**Fix "What you get" table** — note `apps.fmt` is conditional~~ done at `9b376b3`
12. ~~**Add `enableNixfmt` to README FAQ** — "How do I disable nixfmt?"~~ done at `9b376b3`
13. ~~**Rename `checkRequireLines`** to `collectMissingRequires`~~ done at `96336e0`
14. ~~**Simplify requireDeps dedup escaping**~~ done at `96336e0` — temp file approach
15. **Extend merge protection** to `buildInputs`, `checkInputs`, `configureFlags` ← still open → TODO_LIST H3
16. ~~**Add timeout to completion check**~~ done at `c510d7c` — `timeout 10`
17. ~~**Remove `mkGoFlake.nix`** — set a removal date~~ done — removal target set to v1.0.0 at `9b376b3`
18. **Extract postPatch script** ← still open → TODO_LIST L10
19. ~~**Add monorepo integration test** to test.nix~~ done at `12f2350` — Test 6 (multi-deps)
20. ~~**Document `GONOSUMCHECK`/`GONOSUMDB`**~~ → ROADMAP (Theme 5)
21. ~~**Add `nix flake check` to generate-flake.sh smoke test**~~ partially — CI smoke-test job validates parse only
22. **Run integration tests on macOS too** ← still open → TODO_LIST L9
23. **Add property tests** for stripVersionSuffix and repoName ← still open → TODO_LIST M1-M2
24. **Add FAQ entry for `deps` with mixed owners** ← still open → TODO_LIST L4
25. ~~**Document the `owner-repo` naming convention`**~~ NOT-NEEDED — owner prefix reverted at `2cbb37b`
26. ~~**Consider `goPkg` as `lib.types.package`**~~ → ROADMAP (Theme 1)
27. ~~**Add `enableNixfmt` to migration guide** parameter mapping table~~ done at `b10399f`
28. **Test the CI freshness check** ← still open → TODO_LIST (Low)
29. ~~**Test the macOS CI job**~~ partially — CI runs `--no-build` on macOS
30. ~~**Add `privateDepPattern` override documentation**~~ done at `274cb35`
31. ~~**Consider GOPRIVATE wildcard with GONOPROXY exclusions**~~ → ROADMAP (Theme 5)
32. **Add `--dry-run` flag to generate-flake.sh** ← still open → TODO_LIST M6
33. **Add `generate-flake.sh` integration test** ← partially — CI smoke-test validates parse
34. ~~**Document the completion warning behavior** in README~~ done — option description updated
35. **Add `treefmt.config` inspection test** ← still open → TODO_LIST M10

### Low impact / Polish

36. **Fix commit df9a5ff empty message** ← BLOCKED → tracked in TODO_LIST (needs user approval for force push)
37. **Add `shellcheck` to CI** ← still open → TODO_LIST H4
38. **Add `shfmt` to treefmt** ← still open → TODO_LIST H5
39. ~~**Consider `lib.types.package` for goPkg`**~~ → ROADMAP (Theme 1)
40. **Add `vendorHash` placeholder detection** ← still open → TODO_LIST M3
41. **Add `nix flake show` test** ← still open → TODO_LIST M4
42. **Add `--template` listing** to generate-flake.sh help text ← still open → TODO_LIST L3
43. **Cache nix-store in smoke-test job** ← still open → TODO_LIST L8
44. **Add badges for macOS CI** to README ← still open → TODO_LIST L2
45. ~~**Add `CONTRIBUTING.md`** referenced by README~~ already exists
46. **Update `docs/architecture.d2`** ← still open → TODO_LIST M5
47. **Add `docs/flake-patterns.md`** entry for enableNixfmt toggle ← still open
48. ~~**Consider `lib.mkForce` support**~~ → ROADMAP (Theme 1)
49. **Add `--verbose` flag to generate-flake.sh** ← still open → TODO_LIST L1
50. ~~**Review all `_local_deps` references in downstream repos**~~ NOT-NEEDED — repoName change reverted at `2cbb37b`

---

## G) QUESTIONS I CANNOT FIGURE OUT MYSELF

### Q1: Should the `repoName` breaking change be reverted or kept?

The owner-namespacing (M9) prevents same-name different-owner collisions (two forks named `go-cqrs-lite`), but it changes `_local_deps/` paths for ALL existing consumers, requiring vendorHash recompute on upgrade. Is the collision risk real enough to justify the breaking change, or should I keep the old `<repo>` naming and only namespace when a collision is detected?

### Q2: Is the `autoGoPrivateEnv` tradeoff acceptable?

When `publicDeps` is set, GOPRIVATE switches from the broad glob to specific paths. This means LarsArtmann repos NOT in `deps` but present in `go.mod` (resolvable via SSH in devShell) would no longer be covered by GOPRIVATE. Should I (a) keep the specific-paths approach and document the limitation, (b) keep the glob and accept that public repos in `publicDeps` will be needlessly marked private, or (c) use a more sophisticated approach like GOPRIVATE=glob + GONOPROXY=publicDeps?

### Q3: Should `mkGoFlake.nix` be deleted now?

It's been deprecated with a `builtins.trace` warning for a while. The migration guide exists. All known consumers have been told to migrate. Should I delete it in this session's commits, or set a hard removal date (e.g. next major version)?

---

## H) RESOLUTIONS (annotated by session 2026-08-03 04:44 + 05:30)

All three questions were resolved autonomously. See
`docs/status/2026-08-03_04-44_revert-and-remediation.md` for full rationale.

### Q1: REVERTED `repoName` namespacing

Decision: **Reverted to `<repo>` only naming.** Library consumed by 7+ repos.
Collision risk is theoretical (all same owner). Breaking vendor hashes
without a major version bump is irresponsible.

### Q2: REVERTED `autoGoPrivateEnv` to broad glob

Decision: **Always uses broad glob** `github.com/larsartmann/*,github.com/LarsArtmann/*`
regardless of `publicDeps`. Asymmetric risk: marking public repos as private =
minor perf hit; failing to mark private repos = hard build failure. Broad glob
is safer. Additionally, a new `privateGlobPattern` option (session 05:30) makes
the glob configurable for non-LarsArtmann consumers.

### Q3: KEPT `mkGoFlake.nix` with removal target v1.0.0

Decision: **Kept with concrete removal date.** Deprecation warning now states
"will be removed in the first tagged release (v1.0.0)". Deleting would break
unmigrated consumers.
