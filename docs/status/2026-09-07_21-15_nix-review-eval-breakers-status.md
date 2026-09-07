# Status: Nix Review & Fix — go-nix-helpers (2026-09-07 21:15 CEST)

Session scope: full nix-review of this repo (10 `.nix` files read, checklist audit, hunt for the `${}`-interpolation bug class, fix + verify). A parallel session was ACTIVE throughout (their `0817f80` fixed the `${mod}` eval bug at 20:33; `528488a` swept 36 docs + bumped `flake.lock` at 20:38; `8188ad2` at 21:06 committed my working-tree fix set under their message; further in-flight fixture edits observed at 21:15). All commits referenced are this repo unless prefixed `CV`.

Evidence chain (bisect): eval green at `0817f80` → broken at `528488a` (lock bump) → green at HEAD with my fixes. Final gates: `nix flake check` **all checks passed** (full, builds every check), `nix run .#verifyValidation` **PASS**, `nix fmt` canonical, tree clean at review time.

---

## a) FULLY DONE

1. **Full review pass** — every `.nix` file read: `flake.nix`, `mkPreparedSource.nix`, `mkGoFlake.nix`, `modules/go-standard.nix`, `pure-functions.nix`, `test.nix`, `test-module.nix` (targeted — see b.6), `test-pure-functions.nix`, both templates. Categorized (flake entry / library fn / composite module / tests / templates).
2. **Systematic hunt for the `${}`-in-Nix-string bug class** — audited every bare `${` occurrence repo-wide (79 lines). Result: all remaining bare `${` are legitimate Nix interpolations; all shell vars correctly `''${}`-escaped or brace-free. The class that broke CV's vendor FOD today is now structurally absent.
3. **Empirical Nix escape-semantics probe** (`nix-instantiate --eval`): double-quoted `"a\.b"` → `a.b` (backslash DROPPED), indented `''a\.b''` → `a\.b` (preserved). This turned a suspicion into a proven finding.
4. **Fixed (critical, latent-for-all-consumers): the templ-committed sibling check realized string context** — `builtins.pathExists (lib.removeSuffix ".templ" f + "_templ.go")` coerced a path to a context-carrying STRING; current Nix realizes context on `pathExists` → fatal under `nix flake check --no-build` for ANY consumer project containing `.templ` files. Never fired here before because this repo ships zero `.templ` files. Fix: `walkTempl` returns `{templ, generated}` attrsets built by pure path arithmetic (`dir + ("/${base}_templ.go")`), `pathExists f.generated` stays context-free.
5. **Fixed (critical, eval-breaker): module-test fixtures fed a raw derivation as `self.outPath`** — `builtins.readDir` on it realizes its context → the exact `mock-go-src.drv is not valid` failure that made CV's `checks.vendor-hash` red today. Fix: committed static fixture dirs (`test-assets/mock-project`, `mock-templ-committed` with `web/home.templ` + committed sibling, `mock-templ-missing-generated` deliberately missing the sibling); dead `mkTemplSrc` derivation deleted; `templSelf` selects the fixture per test case.
6. **`test-assets` exclusion in `walkTempl`** (beside `.git`, rationale commented): the deliberately-broken fixture must not fail the host repo's own templ-committed check.
7. **Fixed (medium, latent): `extraBuildAttrs.preBuild`/`postInstall` merged with bare `+`** — a top-level snippet not ending in `\n` would merge with the per-package snippet's first line into one broken command (monorepo `packages.*` path). New `joinSnippet` newline-joins non-empty parts.
8. **Fixed (low): pseudo-version sed over-match + escaping split-brain** — `mkPreparedSource.nix:205`'s `v0\.0\.0-` lives in a Nix double-quoted string (backslash dropped → wildcard dots) while line 184's indented twin kept it; both unified to regex-equivalent `v0[.]0[.]0-` with comments documenting the escape-semantics trap.
9. **Fixed (consistency):** devshell `with pkgs;` → explicit `pkgs.*` refs (flake.nix).
10. **Bisect discipline under parallel-session noise** — clean worktrees at `0817f80` / `528488a` proved the eval breakage pre-existed my edits (the lock bump, not my Go-side changes), so the right fix targeted the fixture + walk, not a rollback of anyone's work.
11. **Gates all green at HEAD** — full `nix flake check` (builds autoDiscovery, explicitOnly, verify (8 success-path cases incl. the tab-indented replace regression), moduleTest, moduleTestNoOverlay, pureFunctions, structural, templateEval), `verifyValidation` negative-path app PASS, `nix fmt` canonical, parse checks OK. Worktrees/temp clones cleaned (`git worktree prune`, temp clones trashed).
12. **CV-fleet reconciliation** — confirmed `0817f80`'s `${mod}` fix is byte-identical to the one I'd staged in a throwaway clone, so CV's `vendorHash` re-pin (`sha256-sKpKP6…`) remains valid; obsolete "push 7ecb92c" advice retracted (that clone is gone; THIS repo's HEAD is the canonical fix).

## b) PARTIALLY DONE

1. **Push + consumer lock update** — everything is local; HEAD is NOT pushed, so CV's `flake.lock` still pins the eval-broken rev and CV's `nix flake check`/full go-change-gate stay red until: push here → `nix flake lock update go-nix-helpers` in CV → full gate re-run. Not mine to push without the owner's word.
2. **CV `vendorHash` validity claim** — argued from byte-identical fixes (identical vendored output ⇒ identical FOD output hash) but NOT re-proven by building CV's FOD against this repo's HEAD; cheap to verify once the lock consumes HEAD.
3. **templ-committed test hardness** — the negative-case assertion (`tryEval … !result.success`) passed for the WRONG reason before my fix (it caught the realization *error* just as happily as the intended `throw`). It now exercises the intended path, but the test still cannot DISTINGUISH intended-throw from accidental-eval-error — it should assert the throw message ("without a committed *_templ.go"). Not done.
4. **`test-module.nix` read coverage** — 945 lines; I read the mock/templ/overlay/assert sections by targeted views (~85%), not a full sequential pass. The skill says read everything; the un-read remainder is option-default assertions, but honest reporting: partial.
5. **Flake-lock drift governance** — `528488a`'s lock bump broke eval for 40+ minutes unbeknownst to CI (local-only). No gate here forces "lock bump must pass `nix flake check` before landing" beyond the daemon's blind auto-commit. Not addressed this session.
6. **`0817f80` commit-message accuracy** — the parallel session's message describes a "single-quoted shell fragment" and "regex mismatch" mechanism; the real mechanism is Nix indented-string interpolation → eval error. The CODE is correct; the recorded RATIONALE is wrong and will mislead future debugging. Not corrected (rewriting others' commits is off-limits); a docs correction is a next-step.

## c) NOT STARTED (observed, deliberately untouched)

1. `mkGoFlake.nix` (deprecated) polish — missing `GOTOOLCHAIN=local` in its devshells, `meta = with lib;`, `program = "${writeShellApplication …}/bin/${name}"` instead of `lib.getExe`. Dies at v1.0.0 per its own trace; not worth polishing.
2. `test.nix:6` `<nixpkgs>` fallback — deliberate convenience for standalone `nix-build test.nix`; flake path passes `pkgs` explicitly. Left as-is.
3. `go-standard` meta `license` hardcoded MIT — overridable via `extraMeta`; fleet-typical, left.
4. `publicDeps` entries go into an ERE unescaped (`grep -vE "^${pub}…"` via `escapeShellArg` only) — dots are wildcards; harmless over-match today.
5. `excludeSubModuleDirs` custom values are spliced into a `case` glob unquoted — metachar-containing custom excludes would break; defaults safe.
6. `autoDiscoverScript` header comment says "ALL go.mod at any depth" but `find -mindepth 3` skips each dep's TOP-LEVEL go.mod (by design — main replace comes from the deps key). Comment nit only.
7. `nativeBuildInputs = [ goPkg ]` in `mkPreparedSource` — no script invokes `go`; possibly vestigial (needs verification before removal).
8. `scripts/dashboard.sh` / `scripts/nix-lint.sh` — referenced by apps, not reviewed (shell, not `.nix`; flagged for a follow-up).
9. `nix flake check --all-systems` — darwin/aarch64 legs omitted locally (no builders); CI question only.

## d) TOTALLY FUCKED UP (honest register)

1. **I nearly reviewed the WRONG tree.** My previous session left a fix commit (`7ecb92c`) in a throwaway `/tmp` clone and my first instinct/report treated it as the fix of record. The REAL repo had already diverged (parallel session's `0817f80`). Caught only because I ran `git log` in the real repo as step 1 of discovery — the session-start ritual ("trust nothing inherited") worked, but it should have been my literal first command, not discovery-after-thought.
2. **Three wasted eval cycles from an incomplete fixture inventory.** I fixed `mockSelf.outPath`, re-ran, hit `mock-templ-src.drv` (I had SEEN `templSelf.outPath = mkTemplSrc …` in an earlier grep and didn't act on it), re-ran, hit the latent `pathExists` context bug. Grepping ALL `outPath =` sites plus "what consumes self.outPath" up front would have made it one edit + one verify.
3. **Backslash escaping burned me for the THIRD session running.** multiedit old_string mismatched on `\n` literals; the tool's heredoc mangled python `\\.` (my "fixed" comments landed with DOUBLED backslashes and my first correction attempt was a silent no-op — `changed=False`); final fix went through `chr(92)` construction. I documented this exact trap in the CV status report this morning and STILL walked into it twice here. Also: the first CV-session python no-op had the identical root cause (adjacent-string/escape mangling) — pattern, not accident.
4. **Baseline-before-edit violation.** The session-start ritual demands running the gates BEFORE trusting/editing. I edited first and only then discovered the eval was pre-broken — requiring a worktree bisect to prove my innocence. Baseline-first would have made the bisect unnecessary.
5. **Empirics came late.** The 5-second `nix-instantiate --eval` escape-semantics probe would have surfaced the line-205 finding during the FIRST read pass; instead it landed after the full review, as justification for a fix I'd nearly classified as cosmetic.

## e) WHAT WE SHOULD IMPROVE

1. **Make `nix flake check --no-build` the pre-edit baseline for ANY nix review session** — it is seconds-fast, and today it would have split "pre-existing vs introduced" without a bisect.
2. **Escape-semantics as a first-class review probe**: test `"\""` indented-vs-double-quoted backslash behavior before auditing any file that mixes shell-in-nix strings. The `[.]` style (no backslashes, no `${}`) should be the house style for regex dots in shell patterns — it is safe in BOTH string kinds.
3. **Fixture inventories before fixture edits**: enumerate every producer/consumer of a mock (`outPath =` sites, `readDir`/`pathExists` consumers) before changing any of them — one edit, one verify.
4. **Stop using backslash literals in tool-driven scripted edits entirely** — `chr(92)` construction or sed with `[.]`-style alternates. This is the third session with the same failure shape; the rule belongs in AGENTS.md (still not written — carried foul).
5. **Lock-bump gate**: a flake.lock change should require a green `nix flake check --no-build` in the same commit window (pre-commit or CI), because input bumps change EVAL semantics, not just build inputs — today's 40-minute red window proves the gap.
6. **Commit-message accuracy matters downstream**: `0817f80`'s wrong mechanism story ("regex mismatch") vs the real eval-interpolation failure is exactly the "false premise in the record" class the verify-external-claims skill exists for. Correct the record in docs, never rewrite others' commits.
7. **Tests must discriminate the FAILURE MODE, not just failure**: the templ test's `tryEval` should assert the throw MESSAGE so a regression to context-realization errors can't hide behind a green check.
8. **Parallel-session hygiene worked — keep it**: my fix set landed intact via the daemon + their commit; no stomp, no revert, and the bisect protocol kept authorship questions factual.

## f) Up to 50 things to get done next (impact-ordered brainstorm → HARVEST decides)

**Unblock / urgent**
1. Push this repo's HEAD (`8188ad2` + in-flight parallel work) — unblocks the entire CV fleet.
2. CV: `nix flake lock update go-nix-helpers` → `nix flake check` → full `bash scripts/go-change-gate.sh`.
3. Verify CV's `vendorHash` re-pin end-to-end (build the FOD against the consumed rev, not by reasoning).
4. Check this repo's CI ran/will run green on the pushed HEAD (the lock bump was never CI-proven).
5. Re-deploy chain: SystemNix cv flake.lock bump AFTER CV's lock lands (ordering matters — stale pins 410).
6. Land or discard the parallel session's in-flight fixture edits (`require github.com/a-h/templ …` lines) consciously — they change fixture content mid-verify.

**Correctness / test hardness**
7. Harden the templ-committed negative test to assert the throw MESSAGE (intended-throw vs accidental-eval-error discrimination).
8. Add an eval-regression test for the shell-var-in-nix-string class: eval-smoke each generated shell snippet (or a greppable lint app like `nix run .#lint` extended with an unescaped-`${` detector for indented strings).
9. Property test: `repoName` mid-path `/vN` cases beyond the current set; `stripVersionSuffix` idempotence already covered.
10. Verify `nativeBuildInputs = [ goPkg ]` in mkPreparedSource is load-bearing; remove or document.
11. Guard `cat go.mod` when go.mod is absent in postPatch (stderr noise on no-go.mod sources).
12. Escape ERE metachars in `publicDeps` entries before the `grep -vE` filter.
13. Quote/validate `excludeSubModuleDirs` entries spliced into the `case` glob.
14. Fix the "any depth" doc/comment vs `find -mindepth 3` mismatch in autoDiscoverScript.
15. Decide `goTarballVersion`+`goTarballHash` vs `goPkgOverride` — two knobs, one job; keep precedence documented AND mark one preferred in option docs.
16. Make the templ-committed exclusion list an option (`templCheckExcludePaths`, default `[".git", "test-assets"]`) instead of a hardcoded name consumers might collide with.
17. Consider gating the templ-committed walk behind `enableTempl` (consumers without templ skip the eval walk entirely).
18. Replace the `builtins.seq vendorHashWarning` placeholder-detection trick with `lib.warnIf`-style clarity.
19. Wire `checks.format` for THIS repo's own flake (treefmt check currently only reaches consumers via go-standard).
20. Read + audit `scripts/dashboard.sh` and `scripts/nix-lint.sh` (app-referenced shell, unreviewed).
21. Verify `nix run .#dashboard` / `.#lint` still function (not exercised this session).
22. `nix flake check --all-systems` leg: document the darwin/aarch64 skip or add a remote-builder CI job.
23. Confirm minimum-supported Nix version in README — context-realization-on-pathExists semantics changed underfoot today; consumers on older/newer Nix may see different failures.
24. Add the two `test-assets` fixture layouts to contributor docs (how to extend the templ-committed tests).
25. Template build-smoke: `templateEval` checks eval only; copy `templates/go-standard` into a scratch project and `nix build` it in CI.
26. `set -euo pipefail` audit across `scripts/*.sh`.
27. Single-package overlay eval test (only the monorepo overlay has one today).
28. go-standard: document WHY `devShells.default` is `mkShell` (CC needed for cgo) at the definition.
29. go-standard: `checks.format`/`build` interplay with consumer-added checks — document merge expectations.
30. Consider `follows` for a `systems` input in this repo's flake.nix (consistency with the checklist).
31. mkGoFlake: add the actual removal tracking (v1.0.0 milestone issue) the deprecation warning promises.
32. go-standard: make `meta.license` an option (default MIT) instead of extraMeta override.
33. Write the correction note for `0817f80`'s mechanism story (docs/, not history rewrite).
34. CHANGELOG entry for today's eval fixes (repo has CHANGELOG.md; nothing added yet).
35. FEATURES.md/TODO_LIST.md sync with the new test-assets fixture layout + walkTempl contract (docs-health pass on this repo).
36. Weekly lock-drift report (mirror CV's flake-lock-drift workflow) so input staleness/breakage is scheduled, not discovered.
37. `manPages` derivation: verify the two man pages still match current options (goTarball*/templCheck additions).
38. Auto-discovery: per-dep `excludeSubModuleDirs` override (current list is global).
39. Consider surfacing the discovered-module list as a build log line ("auto-discovered N sub-modules") for debuggability.
40. `verifyValidation` app: also assert the ERROR TEXT names the missing module (currently matches the generic message only).
41. Add a flake-level `checks.templ-fixtures` that walks `test-assets/` deliberately (so fixture breakage fails HERE, not silently in consumers).
42. README: document that `self.outPath` must be a real path (mock guidance for consumers' own module tests).
43. Review `pure-functions.nix` `repoName` for paths with <3 segments + `/vN` middle segments (partially covered; edge audit).
44. CV-side: update the CV status report's stale "push 7ecb92c" advice (superseded by this repo's HEAD).
45. CV-side AGENTS.md trap rows still owed: (a) scripted-edit backslash mangling → verify bytes, (b) View-cache staleness under daemon commits → verify with rg/sed, (c) heredoc backslash mangling in the bash tool → chr(92).
46. NixOS module hardening review: `modules/` has none today — if go-standard ever grows an nixosModule, systemd checklist applies (note only).
47. `flake-parts` bump follow-up: 31729ca changed evaluation forcing — audit other flakes in the fleet for the same mock-outPath pattern (SystemNix, cqrs-htmx, go-appkit consumers).
48. Keep `nix fmt` in the pre-commit path for this repo (verify hooks actually wired — untested claim).
49. Tag discipline: once the lock settles fleet-wide, cut the v1.0.0-rc the deprecation warning references.
50. Publish today's incident (lock bump → eval break → consumer-visible failure) as a SHORT postmortem doc — it is the perfect case study for "input bumps are eval changes".

## g) Questions I cannot figure out myself

1. **Push authority & ordering**: shall I push this repo's HEAD now (it is the unblock for CV's red `nix flake check` and full gate), and should CV's `nix flake lock update go-nix-helpers` + full gate + SystemNix bump follow immediately in that order — or do you want to drive the push yourself given the parallel session is still landing commits?
2. **Fixture ownership**: the parallel session is mid-edit on MY fixture dirs (adding `require github.com/a-h/templ` to `mock-templ-committed/go.mod`, simplifying the `generated` path expr, extending `.gitignore`). Should I stand down from this repo entirely until that session lands, or is concurrent work here expected and I should continue on non-overlapping items (7–16)?
3. **Templ check semantics**: is `walkTempl`/templ-committed intended to run for ALL consumers (current behavior), or gated behind `enableTempl`? And should the exclusion list (`test-assets`) become a public option (`templCheckExcludePaths`) — this decides items 16/17 and whether CV-class repos without templ pay the eval walk today.

---

*Point-in-time snapshot; claims re-verify at session start. Format note: user requested `.md`; the status-report skill's canonical HTML output was overridden by explicit instruction (flagged, not propagated back into the skill).*
