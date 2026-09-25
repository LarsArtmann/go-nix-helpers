# Status Report: Self-Review + Comprehensive Status (session 2026-09-25 ~05:00–09:45)

**Scope of this report:** THIS session only — the Pareto E/F execution, the
8-assertion repair, Tier A builds, and everything I noticed along the way.
Root claim backing: every "done" below is backed by tool output from this
session; every caveat is named, not buried.

**Session end state:** tree clean at `89b0405`. Master through `bb56b78` was
pushed DURING this report's preparation (not by this session — external
push observed at ~09:47), so CI is now validating the whole D/E/F suite;
the two remaining local commits (`499187f` script-quote fix, `89b0405` this
report) are unpushed. Last FULL `nix flake check` (all builds): PASSED —
but it ran BEFORE the final `passthru.go` and script-quoting commits; those
were verified individually (moduleTest build, docsAnnotations build, gates,
shellcheck). A closing full sweep is queued as next-work #1.

## a) FULLY DONE (verified this session)

| Item | Evidence |
| --- | --- |
| E1–E4 docs-annotation gates | `checks.docsAnnotations` vendored checker + grep gate; guard-the-guard tripped BOTH gates on planted defects (named file/line/row) then green; built green in full check; exemption notes in 07-38 §B + 06-51 |
| 8 never-green moduleTest assertions repaired | Root-caused individually: wrong warning-text expectation, `.env` reads after mkDerivation consumes it, `toString` of tryEval errors = `""` on Nix 2.34, `or`-precedence surprises, wrong expected values. Rewritten against real observables |
| **Real bug fix: cgoEnabled** | `toString false` = `""` → CGO_ENABLED unset → cgo silently ENABLED. Now canonical `0`/`1`. Found BECAUSE the assertions were repaired — the bug was hiding behind broken tests |
| Real bug fix: completions comment | postInstall comment hardcoded `--completion` regardless of completionStyle; now interpolates the configured word |
| Floor-check message → pure builder | `goModFloorMessage` in pure-functions.nix; module throws it; 5 content tests |
| Stale-pin warning (F16) | `staleGoAttrName` decision function + module trace + 6 pure tests + module eval-survival test |
| systems option wired | Was documented-but-DEAD (flake-parts default silently won). Composite now maps it; consumer probe proved `packages.x86_64-darwin` absent with `systems = ["x86_64-linux"]`; our flake's own list fixed; x86_64-darwin warning GONE from check output |
| Old-nixpkgs CI guard (T24) | Pinned 2026-06 nixpkgs (go_1_26 era) moduleTest job — verified green locally on BOTH pins before wiring |
| Tier A 10/10 (T3) | 7 remaining repos eval+BUILD green, vendorHash intact (go-localsync, project-meta, oxlint-auto-configure, project-dependency-graph, golangci-lint-auto-configure, go-humanize-linter, standard-bug-tracking-schema) |
| C8 sbts | Hand-rolled modBuildPhase/preBuild removed; publicDeps + go-etag sub-modules (exact-match gap found by fresh rebuild); lock bumped to a437284 (go.mod floor 1.27.1 had outgrown old rev's go_1_26 — a latent time bomb); built green |
| F1, F3–F9, F11, F12, F15 | F1 spacing (28 files, diff-audited), F3 man render clean, F4 symlinks trashed, F5/F6 comments, F7 override markers, F8 go_1_XX patterns, F9 GO_LATEST from new `lib.newestGoAttr` (eval-verified `go_1_27`), F11 correction note, F12 postmortem (2 cases), F15 `passthru.go` made explicit (it never existed) |
| nix-health.sh canary | Detected the host RECOVERY mid-session; drives verification batching now |
| verifyValidation | PASS (D6 content greps validated) |
| Docs | AGENTS (real counts 139/61, 5 new gotchas), README, man pages, CHANGELOG (Fixed+Added), FEATURES, TODO_LIST lifecycle (26 rows across sessions; T15 preserved as Blocked), status reports |
| Session-close hygiene | /tmp probes trashed, worktree pruned, shellcheck clean on new scripts (after fixing my own SC2086 — see d) |

## b) PARTIALLY DONE

| Item | What's missing |
| --- | --- |
| E2 derivation-level red test | Guard-the-guard ran at SCRIPT level in /tmp; the runCommand derivation itself was only ever green. Wiring risk (python3 nativeBuildInputs, store-path root arg) is covered by the green build, but no derivation-red proof exists |
| T27/F2 render-verify | 5 tables render with intact shapes via glow, but glow echoes `~~` literally (no strikethrough ANSI) — the visual property the task cared about was NOT confirmed; pandoc→HTML would show `<del>` |
| F7 marker silencing | `__intentionallyOverridingVersion` set in both test configs; the actual warning noise it should silence was never observed/grep'd this session (claim inherited from prior session) |
| C8 GOEXPERIMENT swap | modBuildPhase gone; GOEXPERIMENT remains in sbts extraBuildAttrs — the `goExperiment` option only exists in UNPUSHED master |
| Final full-check sweep | Last complete `nix flake check` predates `passthru.go` + script fix + reports; individual rebuilds green, full sweep queued |
| F13 (CV proof) | DROPPED on a single probe (`~/projects/cv` has no go-nix-helpers input) — premise possibly stale, possibly wrong repo name; one grep is thin evidence for dropping a watchlist item |

## c) NOT STARTED (this session's remaining scope)

- T4: Tier B migrations (KeyCountdown, branching-flow, StopTube, overview, bank-sync, BuildFlow) — now fully unblocked, just large
- T5: Tier C off mkGoFlake (Standup-Killer, crush-daily) → zero mkGoFlake consumers
- T33: module test for the systems mapping (probe was manual)
- T34: consumer sweep to `goExperiment`/`completionStyle` (blocked on push)
- G-tier (owner-gated): v0.1.0 tag, mkGoFlake + old template deletion, nixpkgs maintainer PR, SSH CI job, df9a5ff rebase, won't-implement policy
- Cross-project lesson export: the `toString false`/env-var + tryEval-message lessons belong in crush-config `references/lessons.md` (by commit there) — not done

## d) TOTALLY FUCKED UP (all caught + fixed this session — none survived to HEAD)

1. **False-green narration from piped exit codes — THREE times.** `nix build … | tail -3; echo exit=$?` reports TAIL's status. I declared a failed sbts rebuild "green", then a FAILED old-nixpkgs moduleTest "green", and in THIS very report session shellcheck's findings got masked the same way. The last one proves it's a habit, not an accident. Every instance was caught by reading logs, but wrong claims were published in my narration first. Inexcusable repetition of the exact failure class this session was about (unverified "verified" claims).
2. **Two syntax-error edits in a row** on test files (stray trailing quote breaking string parsing; then a stray `n` character in the retry). Caught by `nix-instantiate --parse` before any damage — but two consecutive typo-edits is carelessness.
3. **Deleted T15 during TODO lifecycle cleanup** — a row explicitly awaiting an owner decision. Caught and restored to Blocked within minutes; exactly the docs-health failure class (silently dropping unresolved items).
4. **First stale-pin assertion was wrong** (`olderGoAttr == null || stalePinEval.success`) — ignored the floor interaction, failed on old nixpkgs. Deeply ironic: written minutes after repairing 8 assertions of the same write-without-running class. The new CI guard caught it immediately — which is the system working, not me.
5. **jq misreads → wrong lock theory.** Two incorrect jq queries made me claim sbts's lock "has no go-nix-helpers node" and speculate about live-fetching; raw `grep` found the node in seconds. ~10 min of misdirected narration.
6. **SC2086 in my own new script** (unquoted `$bare` in check-docs-annotations.sh), shipped through a "green" gates run because the shellcheck itself was piped. Caught while preparing THIS report; fixed + re-verified + committed `499187f`. CI would have gone red on push.
7. **Worktree metadata leftover** — trashed `/tmp/gnh-baseline` directory but left prunable git worktree state. Pruned now.

## e) WHAT WE SHOULD IMPROVE

1. **Kill the piped-exit-code class permanently**: never `cmd | tail; echo $?` on verification commands; use `set -o pipefail`, separate commands, or check `${PIPESTATUS[0]}`. Should become an AGENTS recipe (session-behavior rule), and CI should stay the backstop.
2. **Run assertions in every environment they claim to cover BEFORE committing them** — the 8-assertion incident and my stale-pin repeat are the same lesson. The old-nixpkgs job exists now; consider making "assertion added → both-pins eval" a reflex.
3. **Self-hosting gap**: our own flake hand-rolls perSystem outputs instead of importing `flakeModules.go-standard` — the dogfood gap is why the dead `systems` option and missing `passthru.go` survived unnoticed. Migrating our flake onto its own module would make the module self-verifying.
4. **Vendoring drift**: check-rows.py carries a provenance header but no upstream revision marker/date — add a vendored-from version note and a re-vendor reminder when the skill updates.
5. **Cross-project lessons not exported** (toString/bools, tryEval messages, `or` precedence) — they live only in this repo's AGENTS; crush-config lessons.md is the right home for the generalized ones.
6. **Verification-depth honesty in labels**: distinguish "script-level red" vs "derivation-level red", "shapes render" vs "strikethrough renders" — this report does it; future status reports should keep doing it.
7. **buildflow nix-hash-fix classifier bug** (mismatch in a dependency-of-check misclassified as non-hash failure → 5-run loop): needs an upstream BuildFlow issue/fix; the tool left me no sanctioned path and forced a documented rule-bend (applying the tool's own reported hash).

## f) Up to 50 things to do next

1. Closing full `nix flake check` at current HEAD (last one predates final commits)
2. Push master (owner-gated) → CI validates all 31 commits end-to-end
3. T4: migrate KeyCountdown
4. T4: migrate branching-flow (go-enum via extraBuildAttrs)
5. T4: migrate StopTube (per-package attrs in anger)
6. T4: migrate overview (git-hooks input consumer-side; nixosModules via perSystem)
7. T4: migrate bank-sync (allowUnfree consumer-side)
8. T4: migrate BuildFlow (1215 lines, multi-tool packages)
9. T5: migrate Standup-Killer (subModules + doCheck=false)
10. T5: migrate crush-daily (NixOS module via perSystem) → mkGoFlake at ZERO consumers
11. T33: module test for the systems mapping (kill the manual-probe-only coverage)
12. T34: sweep consumers to `goExperiment` (needs push) — incl. sbts's remaining extraBuildAttrs GOEXPERIMENT
13. T34: sweep cobra consumers to `completionStyle = "subcommand"`
14. Self-host properly: import flakeModules.go-standard in our own flake (dogfood gap)
15. G1: v0.1.0 tag once pushed + CI green (CHANGELOG section, annotated tag, module-proxy watch)
16. G2: delete mkGoFlake.nix + trace wrapper + structural-check reference update
17. G3: delete templates/go-flake-parts + references
18. G4: maintainers.larsartmann nixpkgs PR (external)
19. G5: SSH CI job (DEPLOY_SSH_KEY secret, flip `if: false`)
20. G6: df9a5ff empty-message rebase (owner-approved force-with-lease)
21. G7: record the won't-implement policy once owner decides
22. Verify F13's "CV" premise (what repo was meant?) before fully dropping it
23. File the buildflow nix-hash-fix classifier bug upstream (dependency-of-check mismatches)
24. Derivation-level red proof for docsAnnotations (throwaway branch with a planted broken table)
25. Render struck tables via pandoc→HTML and confirm `<del>` output (finish T27 properly)
26. Observe/grep the nixpkgs overridden-version warning to confirm F7's markers actually silence it
27. Export cross-project lessons to crush-config references/lessons.md (toString-bools, tryEval-message, `or` precedence, piped-exit)
28. Add "no piped exit codes on verification" recipe to this repo's AGENTS (session hygiene)
29. Re-run consumer attr-probe after any future nixpkgs bump (the 10/10 proof assumed no newer go attr exists)
30. sbts: post-push lock bump + GOEXPERIMENT → goExperiment swap
31. Old-nixpkgs CI pin refresh policy (the 2026-06 rev will rot; define refresh cadence or pin by date query)
32. check-rows.py: record vendored-from upstream revision/date in header; re-vendor when skill updates
33. Consider extending docs gates to docs/planning + docs/reviews (currently docs/status only)
34. nix-health.sh: warn when the working tree is dirty (the daemon+GC flake-check hazard)
35. Consider exposing `go` on devShells via passthru too (parity with packages)
36. moduleTest: print/emit assertion count in the derivation output for drift detection
37. goModFloorMessage: add malformed-floor robustness tests ("1.x", "v1.26", empty)
38. README FAQ: "why does my flake check warn about incompatible systems?" (post-fix behavior)
39. Monitor CI's first run of old-nixpkgs-module-test (new job, never executed on GitHub)
40. Trash/commit sweep: confirm no other result* symlinks accumulated since F4
41. Consider `nix flake check` workflow_dispatch target for host-broken scenarios (from prior backlog #42)
42. Post-push: re-verify a consumer against the PUSHED rev without --override-input (kills the PMA-class time bomb pattern)
43. Dashboard: surface nix-health in dashboard.sh output header (one-line canary)

## g) Up to 3 questions I CANNOT answer myself

1. **Push:** master through `bb56b78` is now on origin (external push, ~09:47) — CI should be validating the suite right now. The two remaining commits (script fix + this report) are unpushed: push them as-is, or hold until CI's verdict on the batch?
2. **T15 (templ generate inside module builds):** confirm closing as won't-implement? (Consumers commit `*_templ.go`; build-time generation is dead weight and a templ-version reproducibility risk; the motivating override is already gone from sbts.)
3. **The binfmt fix happened but nix.conf auto-GC did not** (min-free=5G / max-free=30G still armed). The canary will keep warning and the mid-check source-copy deletion risk remains. Will you raise/disable auto-GC + restart the daemon (root), or should the workflow keep working around it (worktrees, commit-before-check)?

---
*Then: WAITING FOR INSTRUCTIONS.*
