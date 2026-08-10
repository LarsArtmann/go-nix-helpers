# Status Report: publicDeps — False Positive on Public Repos Fix

**Date:** 2026-08-03 02:47 CEST
**Session focus:** Resolving feedback `2026-08-03_mkpreparedsource-false-positive-on-public-repos.md`
**Status:** Core feature shipped, all tests green, but gaps remain

---

## Executive Summary

The feedback reported that `mkPreparedSource` treats ALL `github.com/larsartmann/*` repos as private, even public ones served by proxy.golang.org. This causes false-positive validation failures and misleading error messages.

I implemented all three suggested fixes (A+B+C): added a `publicDeps` exclusion list, forwarded `validatePrivateDeps`/`privateDepPattern`/`publicDeps` through all three API layers, and rewrote the error message. All `nix flake check` tests pass.

However, I missed several documentation updates and one significant functional gap around `GOPRIVATE` interaction in devShells.

---

## A) Fully Done

| Item                             | Details                                                                                                                                                                       |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `publicDeps` in mkPreparedSource | New parameter added, filtering implemented via `grep -vFx` in validateScript, documented in header comments                                                                   |
| Improved error message           | Changed "private modules without local replace" → "modules without local replace", added 3 remediation options (add to deps / set validatePrivateDeps=false / use publicDeps) |
| go-standard.nix options          | Added `publicDeps` (list str) and `privateDepPattern` (str) options with defaults, forwarded to mkPreparedSource call                                                         |
| mkGoFlake.nix forwarding         | Added all 3 params to function signature and mkPreparedSource call                                                                                                            |
| test.nix publicDeps test         | New Test 4: mixed public+private deps, verifies public dep has no replace and private dep still has replace                                                                   |
| test.nix message grep            | Updated `verifyValidation` to grep for new "modules without local replace" text                                                                                               |
| test-module.nix assertions       | 3 new option assertions (privateDepPattern default, publicDeps default empty, publicDeps config eval)                                                                         |
| Man pages                        | Updated `mkPreparedSource.5` and `go-standard.5` with new parameters                                                                                                          |
| AGENTS.md architecture section   | Updated option count 28→30, added publicDeps to option list                                                                                                                   |
| AGENTS.md gotcha                 | Updated `privateDepPattern` gotcha to mention `publicDeps`                                                                                                                    |
| Feedback archived                | Moved from `docs/feedback/new/` to `docs/feedback/processed/` via `git mv`                                                                                                    |
| Formatting                       | Ran `nix fmt` to fix nixfmt formatting issues                                                                                                                                 |
| Verification                     | `nix flake check` passes all 7 checks; `nix-build test.nix -A verify` passes all success-path tests; `verifyValidation` passes                                                |

---

## B) Partially Done

### ~~GOPRIVATE / autoGoPrivate interaction — UNRESOLVED~~ resolved at `052d92d` — reverted to broad glob (safer default); `privateGlobPattern` option added at `c510d7c` for configurability

**What's wrong:** When `deps != {}` in go-standard, `autoGoPrivate` sets `GOPRIVATE = "github.com/larsartmann/*,github.com/LarsArtmann/*"` in all devShells. This blanket-marks ALL LarsArtmann repos as private, including the public ones the user listed in `publicDeps`.

**Impact:** The `publicDeps` fix only covers **build-time validation** (mkPreparedSource). In devShells, Go still treats public LarsArtmann repos as private. Public repos still resolve (direct HTTPS clone from GitHub works), but:

- Go won't use the proxy cache for them (slower)
- If GitHub rate-limits unauthenticated clones, builds could fail
- Conceptually inconsistent: we tell mkPreparedSource "these are public" but tell devShells "these are private"

**What should be done:** `autoGoPrivateEnv` in `go-standard.nix:473-476` should be aware of `publicDeps`. Since `GOPRIVATE` doesn't support exclusions, the cleanest approach is to use `GONOPROXY`/`GOPROXY=direct` for private repos and let public ones go through the proxy normally. Alternatively, document this as a known limitation.

### ~~test-module.nix — privateDepPattern override not tested~~

~~I added the option and assertion for its default value, but didn't test overriding `privateDepPattern` to a custom regex (e.g., for a non-LarsArtmann org). Only the default value is verified.~~ → partially addressed: default-value assertion added; override-with-custom-regex test still open → tracked in TODO_LIST (behavioral tests deepening, M7)

---

## C) Not Started

| ~~**README.md troubleshooting section**~~ done at `9b376b3`, `274cb35` | ~~Line 273 still references old error text~~ Fixed: error text updated, `publicDeps` added as remediation option |
| ~~**AGENTS.md key files table**~~ done — now 32 options | ~~Line 107 still says "28 options"~~ Updated through successive sessions to 32 |
| **nix-private-go-repos SKILL.md** | Still open — skill has 0 mentions of `publicDeps`. → tracked in ROADMAP (Theme 5) |
| **docs/flake-patterns.md** | Still open — no mention of `publicDeps` patterns |
| ~~**CI workflow**~~ partially addressed | ~~CI runs `nix flake check --no-build`~~ `verify` check builds publicDepsTest indirectly; explicit CI build not added |

---

## D) Totally Fucked Up

Nothing is broken. All tests pass, the feature works as designed. The gaps are omissions, not defects.

---

## E) What We Should Improve

### ~~E1. The GOPRIVATE design gap (most important)~~

~~The real problem the feedback describes is "treating public repos as private." I fixed the **validation** layer but not the **runtime behavior** layer (`GOPRIVATE` in devShells). A truly complete fix would make the system consistently treat public repos as public everywhere:~~

~~Build validation:  publicDeps excluded  ✓ FIXED~~
~~DevShell GOPRIVATE: publicDeps ignored  ✗ NOT FIXED~~

**Resolution:** Decided at `052d92d` — broad glob kept as safer default (marking public repos as private = minor perf hit; failing to mark private repos = hard build failure). `privateGlobPattern` option added at `c510d7c` for non-LarsArtmann consumers. `publicDeps` scope clarified: only affects validation, NOT GOPRIVATE.

### E2. publicDeps is path-exact, not pattern-matching

`publicDeps` uses exact string matching (`grep -vFx`). If a user lists `"github.com/larsartmann/go-output"` but go.mod contains `"github.com/larsartmann/go-output/v2"`, the filter won't match. This should be documented more prominently or handled with prefix matching.

### ~~E3. No automated way to discover which repos are public~~

~~Users must manually maintain the `publicDeps` list. A future improvement could auto-detect public repos via GitHub API at evaluation time, or maintain a known-public list in go-nix-helpers itself.~~

**Resolution:** → ROADMAP (Theme 5: Smart private-dep detection — auto-detect via proxy.golang.org query).

### ~~E4. The deprecated mkGoFlake.nix got new params~~

~~I added `validatePrivateDeps`/`privateDepPattern`/`publicDeps` to the deprecated `mkGoFlake.nix`. This is correct for consistency, but since it's deprecated, the effort may be wasted. New consumers should use go-standard.~~

**Resolution:** Kept for consistency. Deprecation warning now states removal target v1.0.0 (`9b376b3`).

### ~~E5. Test coverage gaps~~

~~No test for `privateDepPattern` override, no test for `publicDeps` with versioned paths, no test for module forwarding of `publicDeps`.~~

**Resolution:** Partially addressed: `privateGlobPattern` tests added at `763c94c`; behavioral `nativeBuildInputs` test at `12f2350`. Remaining gaps tracked in TODO_LIST M7-M10.

---

## F) Up to 50 Things to Get Done Next

### High Priority

1. ~~Fix README.md troubleshooting heading to match new error message text~~ done at `9b376b3`
2. ~~Add `publicDeps` as a remediation option in README.md troubleshooting~~ done at `274cb35`
3. ~~Fix AGENTS.md key files table: "28 options" → "30 options"~~ done — now at 32 options
4. ~~Make `autoGoPrivateEnv` in go-standard.nix aware of `publicDeps`~~ decided against at `052d92d` — broad glob kept as safer default; `privateGlobPattern` option added instead at `c510d7c`
5. Update nix-private-go-repos SKILL.md with `publicDeps` parameter and new error message ← still open
6. ~~Add test for `privateDepPattern` override in test-module.nix~~ partially done — default-value test added; override test still open → TODO_LIST M7
7. Add test for `publicDeps` with `/v2` versioned module paths ← still open → TODO_LIST M9

### Medium Priority

8. ~~Document the path-exact matching behavior of `publicDeps` more prominently~~ done at `274cb35`
9. Add `publicDeps` usage example to docs/flake-patterns.md ← still open
10. ~~Consider prefix matching for `publicDeps` instead of exact match~~ → ROADMAP (Theme 5)
11. ~~Update README.md GOPRIVATE section to mention interaction with publicDeps~~ done — `publicDeps` scope clarified in README options table at `274cb35`
12. ~~Add integration test that exercises the full go-standard module with `publicDeps` set~~ done at `12f2350` (multi-deps test covers this)
13. ~~Consider a `knownPublicRepos` default list built into go-nix-helpers~~ → ROADMAP (Theme 5)
14. ~~Update docs/migration-guide.md if mkGoFlake→go-standard migration mentions validation~~ done at `b10399f`

### Lower Priority

15. ~~Add a `--list-public` script that checks GitHub API for public repos~~ → ROADMAP (Theme 5: auto-detect via proxy.golang.org)
16. ~~Consider deprecation path for mkGoFlake.nix validation forwarding~~ done — removal target set to v1.0.0 at `9b376b3`
17. ~~Update CI to build publicDepsTest explicitly~~ partially — `verify` check builds it indirectly
18. ~~Consider GONOPROXY as alternative to GOPRIVATE for finer-grained control~~ → ROADMAP (Theme 5)
19. ~~Add a test that verifies the error message contains all 3 remediation options~~ done — `verifyValidation` checks message text
20. ~~Consider `publicDepPattern` (regex exclusion) as alternative to `publicDeps` (exact list)~~ → ROADMAP (Theme 5)
21. ~~Document the 5 known public LarsArtmann repos somewhere discoverable~~ → ROADMAP (Theme 5)
22. ~~Consider whether `publicDeps` should auto-include sub-module paths~~ → ROADMAP (Theme 5)

### Documentation Polish

23. ~~Update README.md examples to show `publicDeps` usage~~ done at `274cb35`
24. ~~Add `publicDeps` to the go-standard.nix header comment usage example~~ done in option description
25. ~~Update architecture.d2/svg diagram if it shows validation flow~~ still open → TODO_LIST M5
26. ~~Review all docs for any other "private modules" references that imply ALL LarsArtmann repos are private~~ done across successive doc passes

---

## G) Questions I Cannot Answer Myself

1. ~~**Should `publicDeps` use exact match or prefix match?**~~ Decided: **exact match kept.** Documented in README and man page at `274cb35`. Prefix matching is a ROADMAP item (Theme 5). Test for `/v2` paths tracked in TODO_LIST M9.

2. ~~**Should we maintain a built-in known-public list?**~~ Decided: **No.** Would couple go-nix-helpers to specific repos and create maintenance burden. → ROADMAP (Theme 5: auto-detect via proxy.golang.org query).

3. ~~**Is the GOPRIVATE gap a blocker for shipping this, or acceptable as a known limitation?**~~ Decided: **Broad glob kept as known limitation.** Asymmetric risk: marking public repos as private = minor perf hit; failing to mark private repos = hard build failure. `privateGlobPattern` option added at `c510d7c` for configurability. Resolved at `052d92d`.
