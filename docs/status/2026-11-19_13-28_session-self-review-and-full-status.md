# Session Self-Review + Full Status — Docs Corpus Completion aftermath (2026-11-19 13:28)

> Ordered: "What did you forget? What could you have done better?" then a
> full a–g status. Scope: THIS session's run only (resume at ~07:00 →
> push 07:33 → now). Repo state: clean at `d1c7429`, CI 44480563020 green,
> battery 5/5, annotate gate 0, pin deleted.

## a) FULLY DONE (verified green, no follow-ups owed)

1. **Routed-marker mystery SOLVED** (the resume blocker): judge vocab is
   closed (`done|resolved|…|no longer`); `**→ still open — routed …**` fails
   rule A on struck rows; unstruck lines skip rule A entirely. Canon written
   into AGENTS.md.
2. **Annotate gate 358 → 0, confirmed twice on the final tree.**
3. **Wave G** (manual, guarded): 27 A-residuals reworded, 21
   self-contradictory "done — still open" verdicts fixed, 03-28:219
   NOT-DO + F/spacing repair. 68 → 39.
4. **Wave F2** (subagent + my validation): 39 verdicts, 6 hashes
   existence-checked. 39 → 0.
5. **TODO_LIST purge**: 41 DONE rows → CHANGELOG `[Unreleased]` Changed;
   TODO_LIST now open-work-only (T72–T89). Two pre-flight refusal rounds
   resolved by closing 6 drift-bound items honestly first.
6. **Planning corpus**: 645 rows verdicted via `annotate.go repair`
   (2 unresolvable hashes downgraded BEFORE apply); strict + bare gates
   green; 7 files archived with banners; manifest in the 01-58 report.
7. **Ratchet pin `.docs-gates.json` deleted**; AGENTS note rewritten.
8. **Harvests** (all pre-flighted SAFE): T85–T87 upstream/process rows,
   T88 daemon gating, T89 PapDashboard e2e, 2 ROADMAP Open Questions.
9. **CHANGELOG** summary + purge bullets; **00:54 report** §f 1–10
   annotated + §g resolution; **01-58 wrap-up report** with archive
   manifest + backlog table.
10. **3 lessons** committed to crush-config lessons.md (`ddaa19a`).
11. **Ship**: commit `d1c7429` pushed; CI all jobs ✓ (2m14s); battery 5/5;
    local gates 1+2 PASS (59 files); ci-parity ALL GREEN; flake check
    --no-build green.
12. **Vendored check-rows.py**: ledger exemption ported from upstream
    docsrows semantics (with comment provenance), 16 short separators
    normalized across 6 files.

## b) PARTIALLY DONE

1. **T86 (separator + fence normalizer)**: the ledger half is ported, but
   the separator normalization was an AD-HOC /tmp script (gone on reboot),
   not a reusable normalizer, and the code-fence false positive (feedback
   2026-08-03 lines 143–145) remains un-suppressed. T86 stays open,
   correctly.
2. **Wave-G evidence citations**: verdicts cite `test-module.nix:367-371`
   style line refs verified by grep existence, but I did NOT re-open each
   cited line number. Tests exist; exact line refs may drift ±.
3. **Purge bullet fidelity**: bullets carry compact tails ("DONE
   2026-11-18"); the detailed evidence columns were dropped (they live in
   git history + reports). Information was graduated, not lost — but the
   CHANGELOG is less rich than the TODO rows were.

## c) NOT STARTED (deliberately, this session)

1. ROADMAP errata note (A21) — judged covered by the 01-00 plan's own
   Errata section; no ROADMAP edit made.
2. The 06-29 informational sub-bullets (31–33, 36–38, 61–64) left bare on
   the subagent's "informational restatement" judgment — gates pass them;
   the strict "every item resolved" bar would strike them. Never audited
   by me personally.
3. No python regression test for the check-rows.py ledger port.

## d) TOTALLY FUCKED UP (caught and fixed in-session — but they were MY bugs)

1. **Ledger marker misplacement (18-52)**: my insert script's `i > 100`
   guard exempted the WRONG table; fixed only after the gate complained.
   Root error: I didn't verify placement immediately after the edit.
2. **00:54 §f annotation regressions ×2**: (a) the continuation line
   `+ reviews; …` parsed as a NEW BULLET, splitting a multi-line strike →
   rule A finding; (b) "unchanged" note token matched 0 living lines →
   routing FAIL. Lesson: annotations ARE edits the gates parse — I
   annotated without pre-flighting my own annotation text.
3. **First purge strike shape broke the drift model twice** (5 then 1
   items would drift) — I had to learn the pre-flight contract by refusal
   instead of reading `preflight.go` FIRST. Two extra gate cycles.
4. **18-52/19-43 single-row strikes broke gate 2** (mixed tables in live
   reports) — I struck rows without checking what gate 2 does with live
   ledgers; fixed via unstruck-routed + ledger exemption (the right shape
   I should have started with, given I'd just learned rule A skips
   unstruck lines).
5. **Fix-loop churn**: the last 4 battery/local-gate rounds each caught a
   regression introduced by my PREVIOUS fix (G/uniform → routing → gate 2
   ×2). Each batch should have ended with the FULL gate suite, not
   sequential discovery.

## e) WHAT WE SHOULD IMPROVE (systemic, from this session)

1. **Annotations are gate-visible edits** — the docs-health skill should
   say: pre-flight or at least battery-check after annotating LIVE
   reports, not just archived ones.
2. **`repair` dry-run prints counts only** — no per-line preview (unlike
   `status-items --verify`). Upstream gap; folds into T85.
3. **Session tooling evaporates**: applier, wave scripts, spec TSVs live
   in /tmp. A `scripts/annotate-tools/` home (or folding append-verdict
   upstream, T85) would stop rebuilding the same tools.
4. **Vendored check-rows.py drifts silently** — it predates the ledger
   exemption; alignment is a manual "byte-aligned at 7f06fbc" claim that
   rots. Either re-vendor mechanically from upstream on every docs-gates
   release or generate it.
5. **Multi-line strikes + bullet-shaped continuation lines** (`+ …`,
   `* …`) are a parser trap — worth a writer-side lint (continuation
   lines inside a strike must not start with a bullet char).

## f) NEXT (up to 50; priority order, TODO_LIST ids where they exist)

1. T72: billing fix → rerun the 13 never-started CI workflows (owner-side)
2. T84: samber-linter TestExitCodeContract restructure (exec + abs paths)
3. T85: docs-gates append-verdict repair mode (+ verbose dry-run)
4. T86: separator normalizer as a reusable script + code-fence table
   suppression in rows scanners (ledger half already ported)
5. T87: SKILLS docs-health spec-files-not-chat canon
6. T88: crush-config daemon push gating (treefmt+shellcheck pre-push)
7. T89: PapDashboard OCI e2e host run (image-load, compose up, probe)
8. Blocked: nixpkgs maintainer PR (maintainers.larsartmann)
9. Blocked: SSH private-repo CI test (DEPLOY_SSH_KEY)
10. Blocked: df9a5ff empty-commit rebase (owner approval)
11. Owner: Won't-implement policy parameters (ROADMAP open question)
12. Owner: flake-docs consolidation decision (ROADMAP)
13. Owner: nix.conf auto-GC threshold (ROADMAP)
14. T51: Code-Quality-Agent + website adopt-or-manual (BLOCKED, owner)
15. Python regression test for the check-rows.py ledger port
16. Push crush-config `ddaa19a` (lessons) — committed, unpushed
17. Archive the 01-00 SUPERB plan (fully executed now) at next harvest
18. Audit the 06-29 informational sub-bullets decision (c.2)
19. Verify wave-G line-number citations (b.2)
20. Next harvest: 01-58 report is the newest status report (open §f = none;
    backlog table rows route to TODO_LIST — already landed)
21. Zero-main-packages hard-fail guard (AGENTS subPackages gotcha backlog)
22. ~~container.nixUid/nixGid passthroughs — revisit on consumer demand~~ done — covered by the 06-46:42 Won't-implement verdict (the revisit-on-demand escape is recorded there)
23. docs-gates upstream issue: G/uniform vs pipe-in-code-span (the `\|`
    escape doesn't help; routed-row remedy documented in AGENTS)
24. docs-gates upstream: fence-aware rows scanner (subset of T86)
25. T73: gogenfilter TS sweep
26. T74/T75: convergence sweeps
27. Sweep remaining `TODO_LIST T4/T5`-style references in older live
    reports for stale-pointer wording (cosmetic; gates green)
28. Consider annotating the 12-29/13-26 reports' remaining §f items at
    next harvest (they were partially closed this session)

(29–50: nothing further honestly actionable — the TODO_LIST open set is
T72–T89 + Blocked + the 4 owner questions above; inventing more would be
padding.)

## g) QUESTIONS (cannot figure out myself)

1. **Push crush-config?** `ddaa19a` (3 lessons) is committed but unpushed —
   your global config repo; the push order covered go-nix-helpers only.
   Push it now?
2. **Archive the 01-00 SUPERB plan now or at the next harvest ritual?**
   It is fully executed as of `d1c7429`; canon says archive when resolved,
   but it is <1 day old and is this session's own artifact.
3. **Won't-implement policy (ROADMAP open question)**: age threshold / cap
   / owner sign-off for "dormant — dropped" verdicts — the standing ~120
   unilateral verdicts need your parameters; I cannot set policy.

_Point-in-time snapshot · 2026-11-19 13:28 · living sources: TODO_LIST.md / ROADMAP.md / CHANGELOG.md_
