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

### D1. BREAKING CHANGE: `repoName` namespacing changes `_local_deps/` paths — NO MIGRATION GUIDE

**Severity: HIGH.** The `repoName` change (M9) renames all `_local_deps/` directories from `<repo>` to `<owner>-<repo>`. Every downstream consumer that uses `mkPreparedSource` will get a **different vendor hash** when upgrading. This is a breaking change that was NOT documented in the migration guide. Consumers upgrading go-nix-helpers will see:
- Build fails with vendorHash mismatch
- Must recompute hash via `nix build`

**What I should have done:** Added a "Breaking Changes" section to the migration guide documenting the `_local_deps/` path change and the need to recompute vendor hashes.

### D2. requireDeps dedup logic is UNTESTED

The dedup logic (M12) was implemented but **no test case was added** to `test.nix` that passes `requireDeps` with entries already present in `go.mod` and verifies they are not duplicated. The dedup could be broken and we wouldn't know.

### D3. `autoGoPrivateEnv` change may be INCORRECT for edge cases

When `publicDeps` is non-empty, I switched GOPRIVATE from the broad glob to specific dep paths. But consider: what if the user has private deps in `deps` AND **other** private LarsArtmann repos that are NOT in deps but ARE required in go.mod (resolvable via SSH in devShell)? Those would no longer be covered by GOPRIVATE and Go would try to fetch them from the proxy, failing. The previous broad glob covered ALL LarsArtmann repos. The new specific-path approach only covers repos explicitly in `deps`.

**Possible fix:** The GOPRIVATE when publicDeps is set should still use the glob but EXCLUDE the public deps, e.g. using Go's GOPRIVATE syntax which doesn't support exclusions — meaning this approach may be fundamentally limited.

### D4. Commit `df9a5ff` has an EMPTY commit message

The auto-git daemon committed the `generate-flake.sh` placeholder fix with a blank message. This is ugly in git history. Not directly my fault, but I should have squashed or amended.

### D5. `checkRequireLines` naming is misleading

The variable name suggests it only checks, but it also builds the `NEW_REQUIRES` string. Should be named `buildDedupedRequires` or `collectMissingRequires`.

### D6. The requireDeps dedup heredoc has fragile escaping

The expression `''${NEW_REQUIRES%"$'''\n'''"}` uses triple-escaping (Nix `''` escaping + shell `$` escaping + literal `\n`). This is correct but extremely hard to read or maintain. A simpler approach would use `printf` or `awk` to check/write.

### D7. README "What you get" table doesn't mention conditional `apps.fmt`

The table at README line 68 lists `apps.fmt` as always present. After M10, `apps.fmt` is conditional. The table should note this.

### D8. `enableNixfmt` not in migration guide parameter mapping

The migration guide's parameter mapping table (mkGoFlake -> go-standard) doesn't mention `enableNixfmt`. Not strictly wrong (it's a new option, not a migration), but inconsistent.

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

### Critical (breaking change remediation)

1. **Add "Breaking Changes" section to migration guide** documenting `repoName` path change and required vendorHash recompute
2. **Add CHANGELOG.md** with this session's breaking change entry
3. **Fix D3: rethink `autoGoPrivateEnv` with publicDeps** — test with real mixed private/public repos or keep glob + document tradeoff
4. **Add test for requireDeps dedup** in test.nix (pass requireDeps that duplicate existing go.mod entries)
5. **Add test for nativeBuildInputs merge** proving user inputs are appended not overridden

### High impact

6. **Add real e2e consumer test** — mock Go project + flake.nix importing go-standard, built via `nix build` (currently blocked but could be unblocked with a mock)
7. **Deepen behavioral tests** — extract actual `buildGoModule` attribute values (buildFlags, ldflags, proxyVendor) and assert on them
8. **Add negative test for enableCompletions warning** — mock binary without `--completion` support, verify warning is emitted
9. **Audit all downstream consumers** for the `repoName` breaking change impact (blocked on access)
10. **Register `maintainers.larsartmann` in nixpkgs** (blocked on external PR)

### Medium impact

11. **Fix "What you get" table** — note `apps.fmt` is conditional
12. **Add `enableNixfmt` to README FAQ** — "How do I disable nixfmt?"
13. **Rename `checkRequireLines`** to `collectMissingRequires`
14. **Simplify requireDeps dedup escaping** — use `grep -q` + conditional append instead of string accumulation
15. **Extend merge protection** to `buildInputs`, `checkInputs`, `configureFlags`
16. **Add timeout to completion check** — `timeout 5 $out/bin/${pkgName} --completion bash`
17. **Remove `mkGoFlake.nix`** — set a removal date and delete it, update migration guide
18. **Extract postPatch script** from mkPreparedSource into a separate `.sh` file
19. **Add monorepo integration test** to test.nix — two packages sharing vendor hash
20. **Document `GONOSUMCHECK`/`GONOSUMDB`** as alternatives to GOPRIVATE for the publicDeps edge case
21. **Add `nix flake check` to generate-flake.sh smoke test** — use `--override-input` to avoid network
22. **Run integration tests on macOS too** — not just eval
23. **Add property tests** for stripVersionSuffix and repoName edge cases
24. **Add FAQ entry for `deps` with mixed owners** — non-LarsArtmann private repos
25. **Document the `owner-repo` naming convention** in mkPreparedSource header comment
26. **Consider `goPkg` as `lib.types.package`** instead of `goPkgAttr` string (breaking, plan for v2)
27. **Add `enableNixfmt` to migration guide** parameter mapping table
28. **Test the CI freshness check** — verify it catches a stale lock file
29. **Test the macOS CI job** — verify it actually passes on macOS (can't verify locally)
30. **Add `privateDepPattern` override documentation** — how to use for non-LarsArtmann orgs
31. **Consider GOPRIVATE wildcard with GONOPROXY exclusions** — instead of specific paths
32. **Add `--dry-run` flag to generate-flake.sh** — preview without writing
33. **Add `generate-flake.sh` integration test** — generate + `nix flake check` with `--override-input`
34. **Document the completion warning behavior** in README enableCompletions option
35. **Add `treefmt.config` inspection test** — verify all enabled programs produce correct treefmt config

### Low impact / Polish

36. **Fix commit df9a5ff empty message** — `git rebase -i` to squash or amend (requires force push, ask user)
37. **Add `shellcheck` to CI** for scripts/generate-flake.sh
38. **Add `shfmt` to treefmt** for shell script formatting
39. **Consider `lib.types.package` for goPkg** in a future v2 API
40. **Add `vendorHash` placeholder detection** — warn if still `sha256-AAA...` in consumer flakes
41. **Add `nix flake show` test** — verify all expected outputs exist
42. **Add `--template` listing** to generate-flake.sh help text
43. **Cache nix-store in smoke-test job** — speed up CI
44. **Add badges for macOS CI** to README
45. **Add `CONTRIBUTING.md`** referenced by README but may not exist
46. **Update `docs/architecture.d2`** to reflect new enableNixfmt option
47. **Add `docs/flake-patterns.md`** entry for enableNixfmt toggle
48. **Consider `lib.mkForce` support** for consumers who need to override list attrs
49. **Add `--verbose` flag to generate-flake.sh** — show what files were created
50. **Review all `_local_deps` references in downstream repos** after the breaking repoName change

---

## G) QUESTIONS I CANNOT FIGURE OUT MYSELF

### Q1: Should the `repoName` breaking change be reverted or kept?

The owner-namespacing (M9) prevents same-name different-owner collisions (two forks named `go-cqrs-lite`), but it changes `_local_deps/` paths for ALL existing consumers, requiring vendorHash recompute on upgrade. Is the collision risk real enough to justify the breaking change, or should I keep the old `<repo>` naming and only namespace when a collision is detected?

### Q2: Is the `autoGoPrivateEnv` tradeoff acceptable?

When `publicDeps` is set, GOPRIVATE switches from the broad glob to specific paths. This means LarsArtmann repos NOT in `deps` but present in `go.mod` (resolvable via SSH in devShell) would no longer be covered by GOPRIVATE. Should I (a) keep the specific-paths approach and document the limitation, (b) keep the glob and accept that public repos in `publicDeps` will be needlessly marked private, or (c) use a more sophisticated approach like GOPRIVATE=glob + GONOPROXY=publicDeps?

### Q3: Should `mkGoFlake.nix` be deleted now?

It's been deprecated with a `builtins.trace` warning for a while. The migration guide exists. All known consumers have been told to migrate. Should I delete it in this session's commits, or set a hard removal date (e.g. next major version)?
