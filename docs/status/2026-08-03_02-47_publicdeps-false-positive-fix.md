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

### GOPRIVATE / autoGoPrivate interaction — UNRESOLVED

**What's wrong:** When `deps != {}` in go-standard, `autoGoPrivate` sets `GOPRIVATE = "github.com/larsartmann/*,github.com/LarsArtmann/*"` in all devShells. This blanket-marks ALL LarsArtmann repos as private, including the public ones the user listed in `publicDeps`.

**Impact:** The `publicDeps` fix only covers **build-time validation** (mkPreparedSource). In devShells, Go still treats public LarsArtmann repos as private. Public repos still resolve (direct HTTPS clone from GitHub works), but:

- Go won't use the proxy cache for them (slower)
- If GitHub rate-limits unauthenticated clones, builds could fail
- Conceptually inconsistent: we tell mkPreparedSource "these are public" but tell devShells "these are private"

**What should be done:** `autoGoPrivateEnv` in `go-standard.nix:473-476` should be aware of `publicDeps`. Since `GOPRIVATE` doesn't support exclusions, the cleanest approach is to use `GONOPROXY`/`GOPROXY=direct` for private repos and let public ones go through the proxy normally. Alternatively, document this as a known limitation.

### test-module.nix — privateDepPattern override not tested

I added the option and assertion for its default value, but didn't test overriding `privateDepPattern` to a custom regex (e.g., for a non-LarsArtmann org). Only the default value is verified.

---

## C) Not Started

| Item                                  | Why it matters                                                                                                                                                                                              |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **README.md troubleshooting section** | Line 273 still references old error text `"private modules without local replace"`. Doesn't mention `publicDeps` as a remediation option — only mentions `validatePrivateDeps = false`                      |
| **AGENTS.md key files table**         | Line 107 still says "28 options" in the key files table — I only updated the architecture section (line 79)                                                                                                 |
| **nix-private-go-repos SKILL.md**     | The feedback doc explicitly references this skill's gotcha table. The skill should be updated to document the new `publicDeps` parameter and improved error message                                         |
| **docs/flake-patterns.md**            | No mention of `publicDeps` or mixed public/private dep handling patterns                                                                                                                                    |
| **CI workflow**                       | CI runs `nix flake check --no-build` which doesn't build check derivations, so the new publicDepsTest is only verified locally, not in CI's build steps. The `verify` step does build it indirectly though. |

---

## D) Totally Fucked Up

Nothing is broken. All tests pass, the feature works as designed. The gaps are omissions, not defects.

---

## E) What We Should Improve

### E1. The GOPRIVATE design gap (most important)

The real problem the feedback describes is "treating public repos as private." I fixed the **validation** layer but not the **runtime behavior** layer (`GOPRIVATE` in devShells). A truly complete fix would make the system consistently treat public repos as public everywhere:

```
Build validation:  publicDeps excluded  ✓ FIXED
DevShell GOPRIVATE: publicDeps ignored  ✗ NOT FIXED
```

### E2. publicDeps is path-exact, not pattern-matching

`publicDeps` uses exact string matching (`grep -vFx`). If a user lists `"github.com/larsartmann/go-output"` but go.mod contains `"github.com/larsartmann/go-output/v2"`, the filter won't match. This should be documented more prominently or handled with prefix matching.

### E3. No automated way to discover which repos are public

Users must manually maintain the `publicDeps` list. A future improvement could auto-detect public repos via GitHub API at evaluation time, or maintain a known-public list in go-nix-helpers itself.

### E4. The deprecated mkGoFlake.nix got new params

I added `validatePrivateDeps`/`privateDepPattern`/`publicDeps` to the deprecated `mkGoFlake.nix`. This is correct for consistency, but since it's deprecated, the effort may be wasted. New consumers should use go-standard.

### E5. Test coverage gaps

- No test for `privateDepPattern` override (only default checked)
- No test for `publicDeps` with versioned paths (e.g., `/v2` suffix)
- No test for the go-standard module's actual forwarding of `publicDeps` to mkPreparedSource (only option existence + config eval checked)

---

## F) Up to 50 Things to Get Done Next

### High Priority

1. Fix README.md troubleshooting heading to match new error message text
2. Add `publicDeps` as a remediation option in README.md troubleshooting
3. Fix AGENTS.md key files table: "28 options" → "30 options"
4. Make `autoGoPrivateEnv` in go-standard.nix aware of `publicDeps` — exclude them from GOPRIVATE or use a smarter mechanism
5. Update nix-private-go-repos SKILL.md with `publicDeps` parameter and new error message
6. Add test for `privateDepPattern` override in test-module.nix
7. Add test for `publicDeps` with `/v2` versioned module paths

### Medium Priority

8. Document the path-exact matching behavior of `publicDeps` more prominently (README + man page example)
9. Add `publicDeps` usage example to docs/flake-patterns.md
10. Consider prefix matching for `publicDeps` instead of exact match
11. Update README.md GOPRIVATE section to mention interaction with publicDeps
12. Add integration test that exercises the full go-standard module with `publicDeps` set
13. Consider a `knownPublicRepos` default list built into go-nix-helpers
14. Update docs/migration-guide.md if mkGoFlake→go-standard migration mentions validation

### Lower Priority

15. Add a `--list-public` script that checks GitHub API for public repos
16. Consider deprecation path for mkGoFlake.nix validation forwarding (since it's deprecated)
17. Update CI to build publicDepsTest explicitly (currently only built via verify)
18. Consider GONOPROXY as alternative to GOPRIVATE for finer-grained control
19. Add a test that verifies the error message contains all 3 remediation options
20. Consider `publicDepPattern` (regex exclusion) as alternative to `publicDeps` (exact list)
21. Document the 5 known public LarsArtmann repos somewhere discoverable
22. Consider whether `publicDeps` should auto-include sub-module paths

### Documentation Polish

23. Update README.md examples to show `publicDeps` usage
24. Add `publicDeps` to the go-standard.nix header comment usage example
25. Update architecture.d2/svg diagram if it shows validation flow
26. Review all docs for any other "private modules" references that imply ALL LarsArtmann repos are private

---

## G) Questions I Cannot Answer Myself

1. **Should `publicDeps` use exact match or prefix match?** Exact match is safer (no surprise exclusions), but prefix match would handle `/v2` versioned paths automatically. This is a design tradeoff I need your call on. (Current: exact match.)

2. **Should we maintain a built-in known-public list?** I could hardcode the 5 known public LarsArtmann repos (go-atomic-write, go-ndjson, go-sse, go-output, go-branded-id) as a default `publicDeps`, but this creates a maintenance burden and couples go-nix-helpers to specific repos. Should this be opt-in or always-on?

3. **Is the GOPRIVATE gap a blocker for shipping this, or acceptable as a known limitation?** The devShell GOPRIVATE issue means public repos resolve via direct GitHub clone instead of the proxy. It works, but it's slower and conceptually inconsistent. Should I fix it now (more complex change to `autoGoPrivateEnv`) or ship and document the limitation?
