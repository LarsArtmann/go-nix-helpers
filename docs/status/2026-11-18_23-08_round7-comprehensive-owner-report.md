# Status Report — Round 7 COMPREHENSIVE: v0.1.0 shipped, fleet pushed, mkGoFlake gone, what I got wrong

_Report written 2026-11-18 23:08 CET on owner demand ("FULL COMPREHENSIVE & DETAILED STATUS UPDATE!"). Covers the round-7 execution session 20:40–23:08 CET. The point-in-time execution report is `2026-11-18_23-05_round7-v010-cut-fleet-push-mkgoflake-removal-darwin-gaps.md` (same session, written 3 minutes earlier); this file is the comprehensive owner-facing view and supersedes nothing — both stand, cross-referenced._

**Headline:** the ENTIRE actionable list is finished and verified. The three round-6 owner questions are resolved BY EXECUTION: **v0.1.0 tagged + published + consumer-verified**, **36-repo work set pushed** (2 more follow-up pushes during CI triage), **A12 answered by ADR-0003's canon machinery** (three dated canon-advance rows recorded). **mkGoFlake is REMOVED** from master (last consumer migrated first). One NEW external blocker surfaced: **GitHub billing** — 13 repos' CI jobs were never started ("payments have failed / spending limit"). samber-linter's lint is still red after 4 fix iterations (a three-way paralleltest/golines/nolintlint tug-of-war — details in §d).

## a) FULLY DONE AND VERIFIED (this session)

| Item | Evidence |
| --- | --- |
| **v0.1.0 released** | ci-parity --full ALL GREEN → push `ad06738` → CI run 44403055250 success → annotated tag `v0.1.0` at `ad06738` → pushed → GitHub release (`--prerelease`, 0.x rule) → **consumer-style verification**: `nix flake check github:LarsArtmann/go-nix-helpers/v0.1.0 --no-build` EXIT=0 from a clean dir, tag resolves `ad06738489c…` |
| **mkGoFlake REMOVED** | Consumer scan: only comments in Standup-Killer/crush-daily; **ucr-archive was the last live consumer** → migrated to `flakeModules.go-standard` pinned at the v0.1.0 tag (BUILD=0, EVAL=0, pushed). Removed: `mkGoFlake.nix`, `lib.mkGoFlake` export + structural-check assertion, moduleTest eval smoke (**237 checks** now), `templates/go-flake-parts/`, CI template-smoke leg, `generate-flake.sh` go-flake-parts path, all doc rows. ci-parity --full green AGAIN after; CI green at `9c8724b` (run 44405224094) and at every later push (`badfbc7`, `6f7b02f` — gnh CI fully green all session: 6/6 runs success) |
| **update-vendor-hash app** | `go-standard.enableUpdateVendorHashApp` (default true): build → parse `got:` → substitute → re-verify; targets the OLD hash value (sibling FODs never corrupted), refuses shared values, flat vendorHash + go.mod only. Promotes bank-sync's private pattern. Docs: man page, FEATURES, CHANGELOG, flake-patterns (tag-pinned paired-relock recipe), migration-guide (intentional non-module builds note) |
| **36-repo push** | All fast-forward: 15 completionStyle repos, overview + crush-daily, branching-flow/testing/gogenfilter repairs, 4 unpinned repos (discordsync needed TWO rebases — origin moved twice; per-node flake.lock merge kept wave-1 pins AND the unpinned gnh), KeyCountdown, StopTube, mr-sync, wise-go, storbi, nsfw-classifier, sbts, Zlota44, SystemNix, crush-config, SKILLS, ucr-archive. Concurrent sessions' WIP (pim-sync ui.go, Zlota44 ci.yml/go.sum) deliberately left uncommitted |
| **5 darwin eval gaps closed** | crm (linux-only dprint/docs-gates shell tooling), PapDashboard (systems=linux, matching its linux-only package meta), file-and-image-renamer (chromium apps + 400-line verify gate + nixos-module check via optionalAttrs — the mkIf-undefined trap), KeyHolderAI (chromium shell dep), mr-sync (three NixOS checks). All `--all-systems --no-build` EXIT=0 |
| nsfw + sbts + gogenfilter bugs | nsfw checks.nix `unitConfig`→`serviceConfig` (canonical key; check builds green). sbts `biome.json` `tailwindDirectives: true` (Tailwind v4 entry parses; no format churn; 15-file set green). gogenfilter mkMdgo FOD hash (`sha256-L7VZ…`, devShell + validate-docs green: 34 valid/0 errors) |
| **A12 resolved via ADR-0003** | Found the fleet pin-canon ADR (`/home/lars/projects/docs/adr/0003-*.md`) + the concurrent A12 wave sessions. Answer: NO per-repo escapes — canon advances by recorded sweeps. Recorded three dated rows: gnh `1a553ce7`→`ad067384` (= v0.1.0 tag; new locks SHOULD pin the tag), treefmt-nix `0d6d739a`→`0ba5d672` (shfmt-flip caution: module pins the canon since 52dc6f8), templ-components `29cfdc07`→`97c49407` (= v1.27.0; bank-sync + crush-daily proven; ~20 repos converge on next sweeps) |
| CI triage + on-sight fixes | 13 "failures" = **billing** (jobs never started, empty steps arrays — infrastructure). journal = stale pre-push Dependabot run (no push CI). REAL failures fixed: **wise-go** stale go-branded-id/go-error-family pins re-pinned to the exact tag commits its own gate named (Dependency Pin Sync now green); **gogenfilter** A11y guard workflow path (exit-127 rot; guard passes locally) — the job then surfaced PRE-EXISTING astro-check-vs-TypeScript-7 debt → T73. samber-linter: 3 lint findings reduced through 4 iterations — STILL RED (§d.5) |
| Docs + battery | TODO_LIST: T60/T68/T69/T70/T71 flipped (round-6 stragglers), v0.1.0 row DONE, round-7 harvest rows T72–T83. Six inline verdicts stamped in three older live reports (one number-collision mistake fixed by text-anchored stamping, then strikethrough for the two the matcher wouldn't harvest). **docs-gates battery: ALL FIVE GATES GREEN** (freshness, audit-all, annotate, routing, cadence) |
| Lessons + records | serialize-flake-fetches → crush-config lessons.md (`928afa9`); SystemNix completions verdict row (its TODO, daemon-carried); /tmp session artifacts trashed |

## b) STILL OPEN AT REPORT TIME

| Item | State | What remains |
| --- | --- | --- |
| **GitHub billing** | 13 repos' CI jobs never started ("recent account payments have failed or your spending limit needs to be increased") | OWNER: fix billing/spending limit → `gh run rerun` the failed runs. Every pushed commit is local-green (build or full battery) |
| samber-linter lint | Red after 4 iterations; remaining: paralleltest (func missing Parallel) + nolintlint (directive unused) | The clean fix is restructuring TestExitCodeContract to run the binary WITHOUT t.Chdir (exec + absolute paths), enabling true t.Parallel — bounded, recorded as T84 (added with this report) |
| wise-go dprint-format | CI check fails: remote dprint plugin wasm fetch unstable in sandbox (exit 20; same drv pre-dates this session) | T83: local plugin paths (`nix build .#dprint-plugins` / BUILDFLOW_DPRINT_PLUGINS) |
| gogenfilter website CI | A11y step fixed; astro check vs TypeScript 7 | T73: pin TS 6 or adopt @astrojs/ts-content-mapper |
| Owner-gated rows | T51 (adopt-or-manual), T15 (build-time templ generate), won't-implement policy, df9a5ff history fix, nixpkgs maintainer (needs owner email/matrix), DEPLOY_SSH_KEY, T72 billing | all recorded BLOCKED in TODO_LIST |

## c) NOT STARTED (deliberately)

1. Fleet-wide 1a553ce7→v0.1.0 convergence sweep (34 top-level + long tail) — the drift gate's domain, next recorded sweep (T74).
2. templ-components v1.27.0 convergence (~20 repos) — T75.
3. overview corpus workstream (file-size 27, docs-gates, art-dupl 97) — T77, owning session.
4. index templCliPackage adoption — T82, optional (overlay achieves the same pin).

## d) WHAT I FORGOT / GOT WRONG (owner question #1, honest)

1. **The ci.yml over-cut:** regex surgery removed the WHOLE template-smoke job (72 lines) instead of the 6-line go-flake-parts step. Caught by diff review immediately, restored, redone surgically. Rule: diff-review EVERY structural cut before moving on.
2. **Number-collision annotation stamping:** my verdict stamps matched "N." by FIRST occurrence — three landed on the wrong list items inside the same reports. Fixed by full-text anchoring; two items needed strikethrough when the matcher refused the verdict form.
3. **The samber-linter iteration spiral (4 CI cycles):** I fixed findings one linter at a time against a version-skewed local toolchain (local golangci ≠ CI golangci), discovering paralleltest→nolintlint→golines interactions serially. Should have reproduced CI's golangci version locally FIRST, then designed the fix once. Two of the four cycles were avoidable.
4. **Daemon races kept eating my commits** (gogenfilter, nsfw, gnh batch, SystemNix, ucr?): 5 races this session. Content verified intact each time, but messages degraded to "chore: auto-commit". The fix recipe (chain add+commit, single command) was in AGENTS.md; I still lost races because pre-commit batteries take >60s. A `--no-verify` FIRST for repos with known-red batteries would have been faster and more honest than racing.
5. **gnh CI "FAILED" false alarm:** my `gh run watch` raced the run's start and reported failure on a run that was actually in_progress (it finished success). Should have checked run status, not just watch's exit code.
6. **Initial push estimate was scoped right, but I initially forgot** KeyCountdown/StopTube/sbts/wise-go/storbi from the push loop (they were named in §g.1) — caught in review, second loop pushed them.

## e) WHAT I COULD HAVE DONE BETTER (owner question #2, structural)

1. **CI-version parity before lint-fix loops:** pin the local golangci to CI's version (or run the fix IN CI's container) before iterating on lint findings — the samber-linter spiral is the proof.
2. **Billing should have been detected BEFORE the push wave:** the "job was not started" annotation was visible on the FIRST failed run; a pre-push `gh run list` canary on one repo would have flagged it. Now T80 (billing canary).
3. **The mkIf-undefined trap class** (three repos, three shapes) deserves a lint rule, not three manual fixes — T81.
4. **The nolint/Chdir conflict** is a fleet-wide Go-testing pattern problem (t.Chdir forbids Parallel; paralleltest demands it) — the exec-without-Chdir test shape should be the documented pattern in the how-to-golang skill.
5. **Two reports for one session** (23-05 + 23-08) is borderline redundancy; the 23-05 one should ideally have been the only one. Kept both because the owner demanded a distinct comprehensive file at 23:08.

## f) NEXT (all recorded as TODO_LIST rows T72–T84)

1. T72 OWNER: billing fix → rerun 13 workflows.
2. T84: samber-linter TestExitCodeContract restructure (exec, no Chdir, true Parallel).
3. T73 gogenfilter astro/TS7; T83 wise-go dprint local plugins.
4. T74 v0.1.0 convergence sweep; T75 templ-components v1.27.0 sweep.
5. T76 bank-sync update-vendor-hash adoption; T77 overview corpus (owning session); T78 branching-flow art-dupl; T79 docs-gates provenance auto-check; T80 billing canary; T81 mkIf lint rule; T82 index templCliPackage.

## g) QUESTIONS (owner-only)

1. **Billing:** please fix GitHub Actions billing/spending limit — it currently blocks CI verification on 13 pushed-green repos. I can drive all reruns the moment it clears.
2. (FYI, no answer needed) v0.1.0 is cut; ADR-0003 canon rows record gnh@v0.1.0 + treefmt-nix + templ-components advances — future sweeps converge the fleet on these.

**WAITING FOR INSTRUCTIONS.**
