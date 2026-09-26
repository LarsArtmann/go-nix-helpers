# Status Report: Pareto Execution — E/F Workstreams, Test Repair, Tier A 10/10

**Session scope:** Resume the 2026-09-24/25 Pareto plan (E/F workstreams + backlog §f), execute and verify one step at a time. Host recovered MID-SESSION (binfmt restored, daemon restarted by ~05:00) unlocking local builds.

**Final state:** tree clean at `e886424`, master ahead 28 (NOT pushed — awaiting owner approval), full `nix flake check` ALL PASSED (all builds), `nix run .#verifyValidation` PASS, canary green-with-GC-warning.

## a) What got done

| Area                              | Outcome                                                                                                                                                                                                                                                                                                                       |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| E1–E4 docs-annotation gates       | `checks.docsAnnotations` (vendored check-rows.py + grep gate, attribution kept), guard-the-guard verified red on planted defects, exemption notes added, green in full check                                                                                                                                                  |
| 8 never-green assertions repaired | Root causes: wrong warning text, `.env` read after mkDerivation consumes it, `toString` of tryEval errors (always `""` on Nix 2.34). Now 139 moduleTest / 61 pureFunctions assertions, ALL green and BUILT                                                                                                                    |
| 2 real module bugs fixed          | `cgoEnabled` used `toString false` → `CGO_ENABLED=""` (silent no-op; now canonical `0`/`1`); completions postInstall comment hardcoded `--completion`                                                                                                                                                                         |
| F-tier                            | F1 spacing pass (28 files), F2 render-verify (5 tables, glow), F3 man checks, F4 symlinks, F5/F6 comments, F7 `__intentionallyOverridingVersion`, F8 nix-lint `go_1_XX`, F9 GO_LATEST from new `lib.newestGoAttr`, F11 correction note, F12 postmortem, F15 `passthru.go`, F16 stale-pin warning (`staleGoAttrName`, 6 tests) |
| systems option WIRED              | `go-standard.systems` was documented-but-dead; composite now maps it to flake-parts' `systems` (consumer-probe verified); our flake drops x86_64-darwin (F14 warning gone from check output)                                                                                                                                  |
| Old-nixpkgs CI guard              | `old-nixpkgs-module-test` job (2026-06 nixpkgs, go_1_26 era); it IMMEDIATELY caught the stale-pin test ignoring the floor interaction — assertion now encodes "eval survives above floor; floor-check throws below it", verified on BOTH pins                                                                                 |
| Tier A 10/10 (T3/C1–C10)          | All 7 remaining repos eval+build green, vendorHash intact: go-localsync, project-meta, oxlint-auto-configure, project-dependency-graph, golangci-lint-auto-configure, go-humanize-linter, standard-bug-tracking-schema                                                                                                        |
| C8 (sbts)                         | Hand-rolled modBuildPhase/preBuild removed; publicDeps extended with go-etag sub-modules (exact-match missed them — found by the fresh rebuild); lock bumped to a437284 (its go.mod floor 1.27.1 had outgrown the old rev's go_1_26); vendorHash updated; built green                                                         |
| nix-health.sh canary              | Born from the host incident; it is what DETECTED the host recovery mid-session                                                                                                                                                                                                                                                |
| Docs                              | AGENTS (counts 139/61, 5 new gotchas incl. tryEval-messages and the clean-worktree recipe), README, man pages, CHANGELOG (Fixed+Added), FEATURES, TODO_LIST (26 rows removed across both sessions; T15 preserved as Blocked-pending-owner)                                                                                    |

## b) Verification trail (all tool-output, this session)

`nix flake check` (full, builds) → **all checks passed** (twice: after E/F, after systems+CI changes). `nix run .#verifyValidation` → PASS. moduleTest on old nixpkgs pin → green. Consumer probe: `packages.x86_64-darwin` correctly absent with `systems = ["x86_64-linux"]`. 7/7 Tier A builds exit 0. sbts final build exit 0. Docs gates green. `nix fmt` canonical.

## c) Honest caveats

- The last session's "eval-verified" claim for the D-tier suite was WRONG — 8 assertions had never been green and hid the cgoEnabled bug. They were committed while the host was down. Lesson recorded in the postmortem + AGENTS.
- buildflow `nix-hash-fix` looped (5 runs) on a check-dependency classification bug in sbts; the hash applied was the tool's own reported `got:` value (deterministic across its two attempts), verified by rebuild. BuildFlow repo owns the classifier fix.
- glow echoes `~~` markers literally (no strikethrough ANSI) — tables render with intact shapes; nothing was broken to fix.
- F13 (CV lock+vendorHash proof): no CV flake consumes go-nix-helpers (`~/projects/cv` has no go-nix-helpers input) — the watchlist item's premise is stale; dropping it.

## d) Not done (blocked on owner)

1. **Push master** (28 commits: the D-tier suite + tonight) — CI would validate end-to-end and unblock the T34 option sweep (goExperiment/completionStyle across consumers) since options only exist pushed.
2. **T15** (templ generate in module builds): propose won't-implement — confirm or reject.
3. G-tier: v0.1.0 tag, mkGoFlake + old template deletion, nixpkgs maintainer PR, SSH CI job, df9a5ff rebase.

## e) Next actions (unblocked, in order)

1. T4: Tier B migrations (KeyCountdown, branching-flow, StopTube, overview, bank-sync, BuildFlow)
2. T5: Tier C off mkGoFlake (Standup-Killer, crush-daily) → zero mkGoFlake consumers
3. T33: module test for the systems mapping
4. #46: re-run the consumer attr-probe after future nixpkgs bumps (the 10/10 proof relied on no-newer-go existing)

_Session ended clean: tree clean, nothing pushed, all claims above backed by tool output from this session._
