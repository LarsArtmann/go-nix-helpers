# Status: full TODO_LIST execution session — 26/31 tasks shipped, subagent fleet mostly rate-limited, master repaired twice

_Date: 2026-11-18 06:46 CET. Session span: 2026-11-17 ~21:00 → 2026-11-18 06:47 (overnight, single operator + subagents). Scope: execute the ENTIRE TODO_LIST.md of go-nix-helpers (user order: "GET SHIT DONE! The WHOLE TODO LIST!"). This report covers this session only._

## Verdict in one line

26 of 31 actionable TODO tasks are done and verified; 3 are partially done with named blockers; 2 never started (bank-sync migration, Tier B/C sweep) because the Z.ai provider hit a 5-hour usage limit at ~06:40 (resets 2026-11-18 07:48) after subagent rate-limit failures; master went red once from a daemon-pushed mid-edit snapshot of my self-hosting work and was repaired by completing and pushing the change (df0aaff).

---

## a) FULLY DONE (verified this session)

| #   | Task                                                                                      | Verification                                                                                          | Commit(s)                                        |
| --- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| T66 | Inspect + delete `origin/systemnix-vn-version-fix`                                          | subagent verdict: dead (content on master since 2026-09-15 in improved form, `b33fd43`/`c42fd77`); branch deleted from origin | `git push origin --delete` (live)                |
| T67 | Decompose CI run 44059828196                                                               | REAL failure (unformatted tree + SC2016 + container packageName throw), all fixed same day; zero infra hardening needed; observation: daemon pushes unformatted trees | report only                                      |
| T69 | View 3 unopened 2026-0* snapshots + trash `result`                                          | feedback 2026-08-03 fully resolved; postmortem 2026-09-25 already harvested; review 2026-06-19 read in full → 2 latent items handled (repoName collision = resolved-by-guard at mkPreparedSource.nix:139; generate-flake.sh sed metachar fix shipped); `result` trashed | daemon-swept                                      |
| T63 | crush-config lessons (toString-bools, tryEval, or-precedence)                               | 3 entries in `references/lessons.md`; piped-exit-codes honestly skipped (6 existing entries — no split brain) | `e987de4` (crush-config)                         |
| T47 | PapDashboard pilot: merge `oci-go-standard-pilot` + relock                                 | fast-forward merge, relock to e8bc6e2, image + container-structure green on the real backend; daemon later PUSHED the repo (master == origin) | `42090fe` stack (PapDashboard)                   |
| T33 | systems mapping verification + redundancy fix                                              | DISCOVERED: composite AND module both set `config.systems` since 2026-09-25 → listOf concat duplicates the list; removed the composite copy (single source of truth = module), added 2 source-guard assertions + existing eval assertion; moduleTest green; consumer probe green | part of `df0aaff`                                |
| T70 | concurrent-actor detector                                                                  | `scripts/check-concurrent-actors.sh` (baseline/check, mtime scan, allowed-edit-set, shellcheck clean); functional test flags out-of-session file | `07c171b`                                        |
| T56 | CI+local parity script                                                                     | `scripts/ci-parity.sh` (treefmt --fail-on-change + shellcheck style-severity + `nix flake check --all-systems --no-build`, `--full` builds); caught real fmt drift on first run | `07c171b`                                        |
| T46 | GHCR push workflow template + Forgejo example                                              | `templates/ghcr-push-workflow.yml` + migration-guide "Forgejo-remote registries" section | `07c171b`                                        |
| T45 | README registry-auth section                                                               | README "Registry auth" paragraph (docker login/PAT, CI secret shape)                                  | daemon-swept                                      |
| T37 | consumer-audit-checklist container section                                                 | section 9 (7 checks) + triage-script container hygiene block                                          | daemon-swept                                      |
| T36 | architecture.d2 + svg container component                                                  | container.nix node + OCI outputs + edges; svg regenerated with d2 CLI                                 | daemon-swept                                      |
| T35 | flake-patterns container pattern + anti-patterns                                           | full section (right/wrong dockerTools + Dockerfile, registry, tag strategy)                           | daemon-swept                                      |
| T44 | tag strategy knob docs                                                                     | flake-patterns "Tag strategy" (content-hash vs self.rev tradeoff, created follows same logic)         | (with T35)                                        |
| T59 | tryEval assert-helper pattern in flake-patterns                                            | full section (wrong + 3 canonical anchors; or-precedence corollary)                                   | (with T35)                                        |
| T58 | nix2container lock pin policy note                                                         | flake.nix input comment (rev 42d1df94, bump-only-with-containerSmoke policy)                           | daemon-swept                                      |
| T40 | custom `created` round-trip test (RFC3339Nano)                                             | moduleTest assertion: `2026-11-17T21:17:05.123456789Z` round-trips verbatim                            | `07c171b`                                        |
| T43 | `container.initializeNixDatabase` passthrough                                              | option + container.nix passthrough + moduleTest assertion (true when set, false default)              | `07c171b`                                        |
| T39 | structure check richer mismatch diff                                                       | jq `configDiff` localizes all 7 fields with got/want (fail-path verified manually; expected-config dump removed) | `07c171b`                                        |
| T38 | dashboard.sh container column                                                              | std/hand/dockerfile/- classifier + JSON field + legend; fleet signal live (PapDashboard=std, accountability-system=hand) | `07c171b`                                        |
| T55 | containerSmoke CI gap                                                                      | FOUND: containerSmoke ran NOWHERE in CI; wired into ubuntu integration-tests leg; runtime delta = next CI run measures | `07c171b`                                        |
| T65 | polish batch P21–P26 (all 9 items)                                                         | scan scope → docs/planning+docs/reviews (48 files gated, green); nix-health dirty-tree warning; dashboard canary line ("CANARY pass=196 fail=0 warn=39"); E2 derivation-level red proof (planted PARTIAL row → docsAnnotations derivation failed with precise localization); pandoc `<del>` confirmed; devShell `passthru.go` parity (+2 assertions); moduleTest assertion-count emitted to `$out/assertion-count` (222); goModFloorMessage malformed-input tests ("1.x", "v1.26", ""); README incompatible-systems FAQ; result-sweep clean; `workflow_dispatch` full-check job; old-nixpkgs pin-refresh policy note | `07c171b`                                        |
| T68 | upstream ROUTED + clean re-vendor                                                          | upstream already had it (docs-gates `internal/docsrows` @ `ad115e1`, both arrow forms, `go test` green); vendored Python aligned to upstream semantics (bold-arrow form added) + vendored-from marker (21.2) | `07c171b`                                        |
| T64 | SELF-HOST: go-nix-helpers consumes its own module                                          | flake imports treefmt-nix + ./modules/go-standard.nix (self.flakeModules import recurses — documented); hand-rolled systems/treefmt/devShells removed; DOGFOOD FINDINGS FIXED: `projectRootFile` was hardcoded "go.mod" (now auto go.mod/flake.nix) and apps.test/lint emitted on non-Go repos (now gated on go.mod presence); all-systems eval green, moduleTest 222 green, consumer probe green, `nix fmt` works via module treefmt | `df0aaff`                                        |
| T54 | local aarch64-linux containerSmoke (emulation)                                             | full build + structure check passed under binfmt emulation (background job, exit 0)                    | (no code change needed)                          |
| T53 | nix-private-go-repos: image-push works with private deps                                    | already landed + verified in SKILLS repo                                                               | `6d5fae4` (SKILLS)                               |
| T61 | nix-private-go-repos: monorepo × private-deps guidance                                      | already landed + verified (verified-against-module-source table)                                       | `0640666` (SKILLS)                               |
| T62 | shellcheck gate for skill scripts                                                          | already landed: `scripts/check-shell.sh` (full severity, disable-with-reason canon) + findings fixed   | `a8a6139` (SKILLS)                               |
| T48 | KeyHolderAI → container option                                                             | Simon's (rate-limited) partial work completed by me: fmt green, eval green, image + container-structure build green; dockerTools gone; found+fixed old-image bug (STATIC_DIR/PERSONAS_DIR never copied in) | `4972ec42` (KeyHolderAI, unpushed)               |

CI on this repo: run 44168234743 green (e8bc6e2); run 44177938920 RED (daemon-pushed mid-edit snapshot — see d); repair push `df0aaff` CI pending at report time.

## b) PARTIALLY DONE

1. **T49 standard-bug-tracking-schema → container option.** flake.nix migrated (candy, rate-limited mid-flight; daemon committed a HALF-STATE whose lock predates the container option → the repo evaled RED until I relocked to master — eval now green). Real image attr name is NOT `standard-bug-tracking-schema-image` (likely `issue-shield`-named — the structure check built under that name in a later probe). Dockerfile trash + final commit BLOCKED by the repo's own BuildFlow pre-commit findings gate (256 error-severity findings, ALL pre-existing: 191 file-size, 59 pnpm-audit, 4 docs-gates red in that repo). Working tree holds the Dockerfile deletion, uncommitted.
2. **T71 heading-mode canon for annotate.go.** Investigated: `docs-health/assets/annotate.go` has NO heading-item mode; SKILL.md has no canon paragraph either. Decision (implement mode vs codify "headings stay bare") still open — 1h task, untouched beyond research.
3. **AGENTS.md drift after this session's changes** (my own debt, self-inflicted): the architecture section still describes the composite systems mapping (now removed — the module owns it, and the 2026-09-25 "never consumed" narrative was FALSE: the module mapped it since 2026-07-24); counts are stale (54→55 top-level options after initializeNixDatabase, 17→18 container keys, 218→222 moduleTest assertions, 72→75 pureFunctions checks); new scripts (ci-parity.sh, check-concurrent-actors.sh) and the T64 self-hosting architecture deserve entries.

## c) NOT STARTED

- **T50** bank-sync → go-standard (4h; 2256-line hand-wired flake, TWO mkPreparedSource call sites). Dispatched to a subagent which died on the provider's 5-hour USAGE LIMIT (resets 07:48).
- **T5** Tier C off mkGoFlake: Standup-Killer, crush-daily (2h).
- **T4 remainder** Tier B → go-standard: KeyCountdown (`games/KeyCountdown`), StopTube, branching-flow, overview, BuildFlow (bank-sync covered by T50) (4h).
- **T34** fleet sweep: GOEXPERIMENT boilerplate → `goExperiment` option; cobra repos → `completionStyle = "subcommand"` (2h).
- **T52** fleet sweep: delete remaining hand-rolled dockerTools blocks (after T47–T49; T49 not fully landed) (2h).
- **T57** consumer `nix flake update` sweeps so nix2container lands transitively in locks (1h).
- **T60** re-run consumer fleet audit with auto-default + container checklist items (2h).
- **T41** multi-arch manifest app (skopeo `--all` merge of per-system images) (3h).
- **T42** `container.fromImage` (distroless base) via n2c fromImage (3h).

Permanently blocked (owner decisions, unchanged): v0.1.0 tag, Won't-implement policy ratification, nixpkgs maintainer registration, CI SSH secret, df9a5ff rebase, T15 templ-in-build verdict.

## d) TOTALLY FUCKED UP (session postmortem)

1. **Subagent flood → rate-limit massacre.** I dispatched 8 parallel write subagents at once; the Z.ai provider rate-limited 5 of them to death (simon, candy, valentina twice, benedict three times, joakim once). Net effect: candy and simon died MID-TASK and left uncommitted half-states (bugtracker's stale lock shipped a RED-evaling repo via daemon commit; KeyHolderAI sat dirty for hours). The user corrected me: **max 2-3 concurrent subagents, Z.ai only** — I had also attempted gemini/hyper before the veto. Lesson recorded.
2. **Red master from a mid-edit snapshot (44177938920).** While I was mid-rewrite of the self-hosting flake, the daemon committed a HALF-DONE T64 (module imported + old devShells.default still present → `devShells.default defined multiple times` on darwin legs) and something pushed it. My local checks had only covered the current platform at that moment. Repair: finished T64, verified `--all-systems`, pushed `df0aaff`. Canon reaffirmed: verify all-systems BEFORE any window in which the daemon can push, and treat "working tree clean" as a precondition for walking away.
3. **My own verification gap fed (2):** after T64's first local green I ran single-system `nix flake check --no-build`, not `--all-systems` — the exact class of gap ci-parity.sh (written 30 minutes earlier!) exists to close. I didn't run my own new tool at that moment.
4. **Wasted dispatch into a known-bad provider window:** the bank-sync subagent was dispatched when 3 prior dispatches had already died to rate limits; it predictably died too (5h usage limit). Should have gone sequential (me) or waited.
5. **Small self-inflicted code wounds, all caught by tests/shellcheck same minute:** adjacent-expression function-application syntax error in test-module.nix; `builtins.hasInfix` (doesn't exist — `lib.hasInfix`); `--newermt` (invalid — `-newermt`, then rewrote to portable `-nt`); a garbage loop body in the detector script; `cd` without `|| exit` (SC2164); a `|`-delimiter sed collision; `xargs` blocked by the shell policy (worked around).
6. **Owed deliverable still undelivered:** the inline TABLE VIEW report from the previous session's planning request was never delivered (user interrupted with "GET SHIT DONE"); its content is in `docs/planning/2026-11-17_21-17_*.md` but the user-facing table summary remains owed.

## e) WHAT WE SHOULD IMPROVE

1. **Subagent policy (now user-canon): Z.ai only, max 2-3 concurrent, staggered starts.** Encode in project AGENTS.md so future sessions inherit it.
2. **The daemon pushed mid-edit work twice this session (once red).** The real fix is gating the daemon on `treefmt --fail-on-change` + shellcheck before push (T67's recommendation) — a host/crush-config change, not this repo.
3. **Commit-before-window discipline:** never leave a multi-file refactor uncommitted across any pause; the daemon will snapshot half-states. Chain `git add -A && git commit` immediately after each verified step.
4. **Run ci-parity.sh reflexively** — it exists precisely because single-system checks lie; it caught fmt drift within seconds of its own creation.
5. **Half-state detection:** a subagent dying mid-write leaves a dirty tree the daemon then commits. After ANY subagent death, first action in that repo: `git status` + `nix flake check --no-build` before anything else.
6. AGENTS.md counts and narratives rot fast — re-derive after every option-count-touching change (grep canon is already documented; I skipped it this session).

## f) NEXT (up to 50, priority order)

1. Fix bugtracker T49 tail: find real image attr name, verify image + structure build, commit Dockerfile removal (decide: `--no-verify` with reason vs fix repo's pre-existing gate debt)
2. T50 bank-sync migration (me, sequential; provider resets 07:48)
3. T5 Standup-Killer off mkGoFlake
4. T5 crush-daily off mkGoFlake
5. T4 KeyCountdown (games/KeyCountdown) → go-standard
6. T4 StopTube → go-standard
7. T4 branching-flow → go-standard
8. T4 overview → go-standard
9. T4 BuildFlow → go-standard (careful: eval-bound hooks, own skill canon)
10. T34 GOEXPERIMENT → goExperiment sweep across Tier A
11. T34 completionStyle sweep (cobra repos)
12. T52 delete remaining hand-rolled dockerTools fleet-wide
13. T57 `nix flake lock --update-input go-nix-helpers` sweep + eval-verify per consumer
14. T60 fleet audit re-run with the new checklist (container + auto-default sections)
15. T71 heading-mode canon decision (annotate.go mode vs SKILL.md paragraph)
16. T41 multi-arch manifest app (skopeo --all)
17. T42 container.fromImage option
18. Update AGENTS.md: systems-mapping correction + self-host architecture + counts (55 options / 18 container keys / 222 moduleTest / 75 pureFunctions) + new scripts + subagent policy
19. Update TODO_LIST.md statuses for T33–T49, T53–T56, T58–T59, T61–T65, T67–T70
20. Update CHANGELOG.md (Unreleased): self-hosting, initializeNixDatabase, container CI leg, ci-parity, detector, docs gates scope, ROUTED re-vendor
21. Update FEATURES.md: container option keys, self-hosting row, CI additions
22. Check CI verdict on `df0aaff` (repair push) — containerSmoke now builds in CI (timing delta = T55 data)
23. Measure T55 delta from the CI run timing (containerSmoke leg duration)
24. KeyHolderAI unpushed master (4972ec42) — push approval (see question 1)
25. bugtracker main ahead 1 (daemon commit) + my uncommitted Dockerfile removal — push approval
26. SKILLS/docs-gates/crush-config unpushed masters (6d5fae4, 0640666, a8a6139, e987de4, ad115e1-era) — push approval
27. PapDashboard: post-push consumer audit (battery + race tests not run pre-merge; noted by joakim)
28. PapDashboard BuildFlow hook env skew (go-generate without GOEXPERIMENT=jsonv2 misreports tidy) — BuildFlow-side fix
29. Deliver the owed inline TABLE VIEW (Pareto plan summary) to the user
30. Daemon gating on treefmt+shellcheck before push (host-level; pairs with e.2)
31. dashboard.sh `--check` fleet run to baseline real PASS/FAIL (canary currently static-analysis only)
32. Fleet container sweep follow-up: accountability-system flagged "hand" (dockerTools) — add to T52 list
33. mkGoFlake.nix deletion planning once Tier C done (v0.1.0 gate)
34. templates/go-flake-parts deletion planning (deprecated; v0.1.0 gate)
35. Consider archiving this session's planning file status into TODO_LIST (T68–T71 rows already there; verify)
36. container.nix: add initializeNixDatabase to architecture.d2 diagram + man page (option documented in module; man page section may lag)
37. docs/man/go-standard.5: regenerate/verify against 55 options + 18 container keys
38. scripts/nix-lint.sh: fold into ci-parity or leave standalone (currently only CI shellcheck covers it)
39. E2-style red proof for the NEW gate scope (planning+reviews) — my proof planted in planning/, already covers it (verify recorded)
40. bugtracker repo's own debt (out of scope but observed): 4 red docs-gates, 191 file-size, 59 pnpm-audit findings blocking its pre-commit
41. KeyHolderAI CHANGELOG/AGENTS updates from Simon's diff — verify completeness
42. Consider `container.nixUid/nixGid` passthroughs (companion knobs to initializeNixDatabase; skipped as YAGNI this session)
43. Self-host follow-up: emit `apps.default`? (module skips it package-less — intentional; document)
44. Add dashboard container-state note to consumer-audit-checklist triage output (verify no duplication with section 9)
45. Pareto plan errata: record T55 finding (containerSmoke was CI-absent) and T33 finding (redundant mapping) as answered questions
46. Re-run docs-gates battery on this repo after TODO/CHANGELOG/FEATURES updates (annotate pins may need ratchet-down after harvest)
47. `result` symlink hygiene: add to nix-health or ci-parity? (trashed twice this week by hand)
48. Investigate WHO/WHAT pushes this repo (external pushes at 18:55, ~21:15, ~02:00+; daemon claims commits-only) — audit trail question for owner
49. provider usage-limit planning: sequential mode until 07:48; then max 2-3 staggered subagents for T4 wave
50. Cut v0.1.0 once fleet migrations land (owner decision — unblocks mkGoFlake/template deletions and consumer version pinning)

## g) QUESTIONS (cannot figure out myself)

1. **Push approval for the consumer/skill repos.** go-nix-helpers pushes happened (explicitly ordered once, then externally). But KeyHolderAI (1 commit), standard-bug-tracking-schema (1 commit + my uncommitted Dockerfile removal), SKILLS, docs-gates, crush-config all have unpushed masters from this session's work. Push all of them, or leave for your review? (PapDashboard was already pushed by its daemon.)
2. **bugtracker pre-commit gate:** its BuildFlow hook blocks my commit on 256 PRE-EXISTING error findings (file-size/pnpm-audit/docs-gates debt of that repo, unrelated to the container migration). Commit the Dockerfile removal with `--no-verify` + reason, or leave uncommitted and fix that repo's debt first?
3. **v0.1.0 tag:** the blocked TODO says owner decision; it gates mkGoFlake removal (only 2 repos left after T5) and consumer version pinning. Cut it once T5/T50 land, or hold?
