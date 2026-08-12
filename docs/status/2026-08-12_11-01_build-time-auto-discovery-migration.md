# Status Report: Build-Time Auto-Discovery Migration & Flake Check Fix

**Date:** 2026-08-12 11:01
**Session goal:** "Fix!" — resolve all errors from a `nix flake check` + `nix fmt` run
**Outcome:** Root cause found and fixed; all checks green; one architectural change

---

## What Was Broken (Input)

The user pasted output from a formatting/check run containing errors from multiple tools:

| Tool         | Errors                                                                 | Severity     |
| ------------ | ---------------------------------------------------------------------- | ------------ |
| shfmt        | 3 shell scripts using spaces instead of tabs                           | Formatting   |
| deadnix      | Unused lambda patterns in flake.nix, templates, test-module.nix        | Lint warning |
| statix       | Assignment-instead-of-inherit, empty patterns                          | Lint warning |
| nix          | `syntax error, unexpected end of file` at flake.nix:1:1                | Transient    |
| nix (flake)  | `path 'mock-dep.drv' is not valid` during `nix flake check --no-build` | **Critical** |
| prettier     | `exec: prettier: not found` in dev shell                               | Environmental|

The shfmt/deadnix/statix issues were **already fixed** in commit `c0a8290` (the working tree was clean when I started). The syntax error was transient (the file parses fine). The prettier error was from dprint trying to run outside the treefmt config.

The **real bug** was `nix flake check --no-build` failing because `mkPreparedSource.nix` used `builtins.readDir` and `builtins.readFile` on dep derivation outputs during Nix evaluation — forcing those derivations to be built during evaluation, which `--no-build` prohibits.

---

## a) FULLY DONE

### 1. Root Cause: Eval-Time → Build-Time Auto-Discovery Migration

**Problem:** `mkPreparedSource.nix` had a `discoverSubModules` function that called `builtins.readDir` on dep source derivation outputs during Nix evaluation. This forced Nix to build those derivations during evaluation. `nix flake check --no-build` (used in CI) fails with `path 'mock-dep.drv' is not valid` because it refuses to build.

**Fix:** Replaced the eval-time Nix tree-walk with a build-time shell script (`autoDiscoverScript`) that runs in `postPatch` after deps are copied to `_local_deps/`. The script uses `find` + `awk` to discover sub-modules, extract module paths from `go.mod` files, normalize pseudo-versions, and generate replace directives — all at build time.

**Files changed:**
- `mkPreparedSource.nix` — Removed `readModulePath`, `discoverSubModules`, `allDiscovered`, `allSubModules`, `subModuleVersionNormalize`, `allSubModuleReplace`. Added `explicitSubModuleReplace`, `explicitVersionNormalize`, `autoDiscoverScript`. Updated `postPatch` to run the script and merge discovered replaces with explicit ones (deduped).
- `flake.nix` — Removed `self` from `test-module.nix` import (mismatch with the prior commit that removed `self` from the parameter list).
- `AGENTS.md` — Updated architecture bullet and gotchas section.
- `mkPreparedSource.nix` header comment — Updated to reflect build-time discovery.

**Verification:**
- `nix flake check --no-build` — **all checks passed**
- `nix fmt -- --ci` — 0 changed files
- `nix build .#checks.x86_64-linux.verify` — all success-path tests passed
- `nix build .#checks.x86_64-linux.autoDiscovery` — built, go.mod has correct replaces
- `nix build .#checks.x86_64-linux.multiDepsTest` — built, multi-dep discovery works
- `nix build .#checks.x86_64-linux.moduleTest` — 114 assertions pass
- `nix build .#checks.x86_64-linux.pureFunctions` — 22 assertions pass
- `nix build .#checks.x86_64-linux.structural` — pass
- `deadnix` — clean
- `statix` — clean

### 2. Confirmed Already-Fixed Items (from commit c0a8290)

| Issue                  | Status          |
| ---------------------- | --------------- |
| shfmt: spaces → tabs   | Already fixed   |
| deadnix: unused vars   | Already fixed   |
| statix: inherit/patterns| Already fixed  |
| flake.nix syntax error | Transient/state |

---

## b) PARTIALLY DONE

### Man Pages — Not Updated

`docs/man/mkPreparedSource.5` and `docs/man/go-standard.5` still reference "auto-discovery" without noting it now happens at build time. The behavior described (recursive scan, excluded directories) is still accurate, but the implementation mechanism changed. Low priority — the user-facing API is unchanged.

### AGENTS.md Architecture Section — Partially Updated

Updated the auto-discovery bullet and added a gotcha, but the "Unified sub-module pipeline" bullet still references the old unified `allSubModules` list which no longer exists in that form (explicit and auto-discovered are now handled in separate phases).

---

## c) NOT STARTED

Nothing relevant to this session's work was left unstarted.

---

## d) TOTALLY FUCKED UP

Nothing. All changes are verified working.

---

## e) WHAT WE SHOULD IMPROVE (Self-Critique)

### Architecture Critique

1. **The `-mindepth 3` magic number is fragile.** The build-time script uses `find _local_deps/ -mindepth 3 -name go.mod` to skip top-level go.mod files. This assumes `_local_deps/<basename>/go.mod` is always depth 2 (the root module) and sub-modules are depth 3+. This is correct for the current data model but is a hidden assumption. A comment or variable would make it self-documenting.

2. **Two-phase sub-module handling increases cognitive complexity.** Explicit `subModules` are handled at eval time (Nix), auto-discovered at build time (shell). The dedup logic between them is now a shell `grep` check rather than `lib.unique`. This works but is harder to reason about than the old unified list. The tradeoff was necessary to fix `--no-build`.

3. **The shell-based module path extraction (`awk '/^module /{print $2; exit}'`) duplicates logic** that was previously in `readModulePath` (Nix). Both do the same thing but in different languages. If the go.mod format ever changes (unlikely), both need updating.

4. **No build-time test for the dedup logic.** The existing `verify` check tests that explicit and auto-discovered entries are both present, but doesn't test the case where an explicit `subModules` entry DUPLICATES an auto-discovered one. The old `lib.unique` guaranteed dedup; the new `grep -qF` check should too, but there's no dedicated test.

### Process Critique

5. **I should have inspected individual test assertions**, not just exit code 0. The `verify` check produces a directory with `result.txt` saying "all success-path tests passed" — but I didn't see the individual PASS/FAIL lines because they're consumed by the derivation build. I verified the go.mod output manually for two cases, which partially compensates.

6. **I didn't check if `readModulePath` was referenced elsewhere** before removing it. It was a `let`-bound function local to `mkPreparedSource.nix`, so this was safe — but I should have verified with a grep before deleting.

7. **I initially treated the paste as 6 independent issues** when actually 4 of them were already fixed. I spent time reading files and checking formatting before realizing the working tree was clean. A `git status` + `git log --oneline -1` at the very start would have immediately shown the state.

8. **The `test-module.nix` `{self}` mismatch** was introduced by commit `c0a8290` (which removed `self` from the parameter list but didn't update `flake.nix`). This means CI was already broken before this session. I should have caught this faster by running `nix flake check --no-build` immediately after seeing the first error.

### Missing Coverage

9. **No test for the `autoSubModules = false` + `subModules` + auto-discovery interaction.** When auto-discovery is disabled, the script is skipped entirely (`lib.optionalString autoSubModules`). The `explicitOnly` test covers this case, but only with a single dep and single sub-module.

10. **No test for deeply nested excluded directories.** The shell `case` pattern `*/example/*` should match at any depth, but there's no test for `_local_deps/X/a/b/example/c/go.mod`.

---

## f) Up to 50 Things to Get Done Next

### High Priority (P0 — correctness/regression risk)

1. Add a test case where explicit `subModules` entry DUPLICATES an auto-discovered one — verify the dedup works at build time
2. Add a comment explaining the `-mindepth 3` assumption in `autoDiscoverScript`
3. Verify a real downstream consumer (e.g. BuildFlow, mr-sync) still builds correctly with the new build-time discovery
4. Run `nix flake check --no-build` in CI to confirm it passes in a clean environment (not just locally with cached derivations)
5. Add a test for excluded directories at depth > 1 (e.g. `_local_deps/X/a/example/b/go.mod`)

### Medium Priority (P1 — documentation & maintainability)

6. Update `docs/man/mkPreparedSource.5` to note build-time discovery
7. Update `docs/man/go-standard.5` if needed
8. Update AGENTS.md "Unified sub-module pipeline" bullet to reflect the two-phase design
9. Extract the `-mindepth 3` into a named variable with a comment
10. Consider adding `shellcheck` to the CI for the generated shell script in `autoDiscoverScript`
11. Add `autoDiscoverScript` output to the `verify` check's diagnostic output (for debugging)
12. Document the eval-time vs build-time boundary in `docs/flake-patterns.md`
13. Consider extracting `autoDiscoverScript` into a separate `.nix` file for testability
14. Add a property test: "discovered replaces never contain `/vN/` in the localDir when the physical directory doesn't have it"

### Lower Priority (P2 — nice to have)

15. Explore whether `builtins.pathExists` could replace `-mindepth 3` for a more robust root-skip
16. Add `--trace-verbose` support to `autoDiscoverScript` for debugging consumer builds
17. Consider adding a `failOnNoDiscovery` option for consumers who expect auto-discovery to find at least one sub-module
18. Benchmark: does build-time discovery slow down the build noticeably vs eval-time?
19. Consider caching discovered modules across builds (unlikely to help — Nix already caches the derivation)
20. Add a `--list-discovered` debug app that shows what would be discovered without building
21. Consider whether `subModuleVersion` normalization should also run on main dep replaces
22. Review whether the `case` pattern for excluded dirs handles all edge cases (spaces, special chars)
23. Add integration test with a dep that has go.mod in the root only (no sub-modules)
24. Add integration test with a dep that has go.mod ONLY in subdirectories (no root go.mod)
25. Consider whether `find -mindepth 3` should be configurable via a parameter
26. Document the shell portability of `autoDiscoverScript` (bashisms: `case`, `[[ ]]`, `${var#pattern}`)
27. Add a test for the scenario where `_local_deps/` is empty (no deps)
28. Add a test for the scenario where a dep has a `vendor/` directory with go.mod files
29. Review whether `node_modules` exclusion is still needed (Go projects shouldn't have it)
30. Consider adding `dist/`, `build/`, `bin/` to default `excludeSubModuleDirs`
31. Add a CI step that runs `nix-build test.nix -A autoDiscovery` and inspects the go.mod
32. Consider adding a golden file test (compare go.mod output to a known-good reference)
33. Explore whether `nix flake check` (without `--no-build`) would catch issues `--no-build` misses
34. Review the `sed` escaping in `subModuleVersionNormalize` — the `|` delimiter could conflict with module paths containing `|`
35. Add error handling in `autoDiscoverScript` for malformed go.mod files
36. Consider whether `awk '/^module /{print $2; exit}'` should be more robust (handle `module\t<path>`, comments, etc.)
37. Add a test for module paths containing dots (e.g. `github.com/x/y.z/v2`)
38. Add a test for module paths with hyphens (e.g. `github.com/go-cqrs-lite`)
39. Review whether the `grep -qF` dedup in the replace-merge step handles whitespace variations
40. Consider adding a `--dry-run` mode to mkPreparedSource that shows the generated postPatch script
41. Update `docs/architecture.d2` diagram to show the build-time discovery flow
42. Consider whether the two-phase design could be simplified by moving explicit subModules to build time too
43. Add a benchmark comparing eval-time vs build-time discovery performance
44. Consider whether `nixpkgs.lib.optionalString` is the right choice vs inline `if` for `autoDiscoverScript`
45. Review whether the `excludeSubModuleDirs` default list matches real-world LarsArtmann repos
46. Add a test for symlinks in dep sources (should they be followed?)
47. Consider adding `GOFLAGS=-mod=mod` to the build environment for go.mod modifications
48. Review whether `chmod -R u+w _local_deps` is still needed (it was for read-only store paths)
49. Consider documenting the order of operations in postPatch (copyDeps → stripLocalReplaces → postPatchExtra → normalize → discover → requires → replaces → validate)
50. Consider whether the `verify` check should also test `requireDedupTest`, `multiDepsTest`, `publicDepsTest`, and `versionedPublicDepsTest` individually (currently they're built but not verified by the check script)

---

## g) Questions I Cannot Answer Myself

1. **Should the `verify` check script test ALL 7 test derivations** (`autoDiscovery`, `explicitOnly`, `publicDepsTest`, `requireDedupTest`, `multiDepsTest`, `versionedPublicDepsTest`, `validationTest`)? Currently it only runs assertions on `autoDiscovery`, `explicitOnly`, and `publicDepsTest`. The others are built (so they must not crash) but their go.mod outputs aren't verified by the check script. Is this intentional (the build succeeding is enough) or a gap?

2. **Are there downstream consumers that inspect the `go.mod` output of `mkPreparedSource` during Nix evaluation?** The build-time discovery change means the replace directives for auto-discovered modules are no longer available at eval time. Any consumer that reads the go.mod at eval time (e.g. for validation or custom logic) would break. I can't determine this without access to the consumer repos.

3. **Should the eval-time `discoverSubModules` / `readModulePath` functions be kept in `pure-functions.nix` as testable utilities**, even though they're no longer used by `mkPreparedSource`? They were never there (they were `let`-bound in mkPreparedSource), but the concept of testing module-path extraction in isolation might be valuable for the shell-side `awk` equivalent.
