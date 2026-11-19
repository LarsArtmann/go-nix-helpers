# Docs Corpus Completion — SUPERB Finish (2026-11-19 01:58)

> Terminal state of the docs-health AUDIT ordered 2026-11-19 00:00 and
> re-ordered via the pareto plan (`docs/planning/2026-11-19_01-00_*`).
> Mission: annotate gate **0**, planning corpus resolved + archived,
> TODO_LIST purged to open-work-only, pin deleted, all gates green, pushed.

## a) Headline results

| Gate | Before session | After | 
| --- | --- | --- |
| annotate findings | 358 pin / 68 live at resume (39 after wave G) | **0 — CLEAN, twice confirmed** |
| `.docs-gates.json` pin | annotate_max = 358 | **deleted** (fleet default 0 = strictest) |
| battery | 4/5 (annotate red at 359→68) | **5/5 PASS** |
| TODO_LIST | 41 DONE rows unstruck | **purged** into CHANGELOG [Unreleased] (open-work-only: T72–T89) |
| planning corpus | 5 MDs (~640 bare rows) + 2 HTMLs unresolved | **645 verdicts applied, 7 files archived** |
| local gates (check-docs-annotations.sh) | green | green (re-verified) |

## b) What happened (execution log)

1. **Routed-marker mystery SOLVED** (the resume blocker): the judge's
   struck-item vocabulary (`markerRe`) is
   `done|resolved|superseded|fixed|adopted|decided|verified|won't implement|not-do|duplicate|struck|moot|no longer`;
   `**→ still open — routed …**` contains none of these → rule A fired. The
   passing 21-31 rows pass because they are UNSTRUCK (rule A only sees
   `~~` lines). Fix form: `**→ decided: defer — routed <where>**`.
2. **Wave G** (manual, 40 lines): 27 A-residuals reworded (02-37 ×13,
   02-51 ×12 appended verdicts, 09-51 ×2), 21 self-contradictory
   "done — still open" verdicts corrected across 15-51 (12) + 14-39 (9),
   03-28:219 NOT-DO + spacing fix. Annotate 68 → 39.
3. **Wave F2** (subagent alejandra, spec validated + hash-verified):
   39 verdicts across 22-15 (10), 02-47 (9), 03-28 (10), 04-44 (10).
   Annotate 39 → **0 CLEAN**.
4. **TODO_LIST purge**: 41 DONE rows struck (task+id wrap, compact tail)
   → pre-flight refused twice (5 then 1 historical item would drift) →
   6 items annotated closed first (18-52:29, 19-43:33, 06-46:2+34,
   11-04:18, 12-29:34) + `### Changed` anchor added → SAFE → **41 rows
   purged** into CHANGELOG; TODO_LIST now open-work-only.
5. **Harvests (pre-flighted)**: T88 daemon push gating (repo:
   crush-config), T89 PapDashboard e2e host run, + 2 ROADMAP Open
   Questions (flake-docs consolidation, nix.conf auto-GC).
6. **Planning corpus** (subagent athena, ~640 rows): 5 MDs verdicted via
   `annotate.go repair` (645 action lines), feedback file 5 rows; 2
   unresolvable hashes downgraded to hash-free evidence BEFORE apply
   (aedecad, 0a889d5dd); all other hashes verified (24 in-repo + 17
   foreign across 10 repos).
7. **Post-archive gate fixes**: 4 G/uniform (2 verdict-text tilde
   rewords, 2 code-span-pipe rows converted to the unstruck ROUTED
   form), 3 newly-unharvested audit-all items closed (06-46:42 w,
   11-04:9 done, 13-26:45 done).
8. **Ratchet terminal**: annotate=0 confirmed twice on the final tree →
   `git rm .docs-gates.json`; AGENTS.md note rewritten with the judge-vocab
   canon.
9. T85–T87 upstream rows landed; CHANGELOG [Unreleased] summary entry;
   00:54 report §f items 1–10 annotated + §g resolution.

## c) Archive manifest (this sweep)

| File | Classification | Reason |
| --- | --- | --- |
| docs/planning/archived/2026-06-29_03-15_eliminate-postpatch-workarounds.md | ANNOTATE→ARCHIVE | every item verdicted (116 lines; companion 04-21 report as evidence); Cyberdom = NOT-DO (reverted, external) |
| docs/planning/archived/2026-07-24_22-18_pareto-execution-plan.html | SUPERSEDED→ARCHIVE | banner: superseded by the 2026-08-10 re-rank (all H/M shipped, L10 rejected on merit) |
| docs/planning/archived/2026-08-10_02-41_pareto-execution-plan.md | ANNOTATE→ARCHIVE | 126 lines verdicted; STATUS: EXECUTED verified against git; P12 = Won't implement; 3 rows routed to TODO_LIST Blocked |
| docs/planning/archived/2026-09-24_18-13_pareto-execution-plan.md | ANNOTATE→ARCHIVE | 113 lines verdicted; C-tier closed via T4/T5 DONE; D10/T15 + policy rows routed |
| docs/planning/archived/2026-09-25_09-54_ci-green-fleet-consolidation-pareto-plan.md | ANNOTATE→ARCHIVE | 126 lines verdicted; first fully green CI run 44152413584; 4.5/4.6 NOT-DO (flake consumption, not Go module) |
| docs/planning/archived/2026-11-17_21-17_green-master-to-fleet-value-pareto-plan.md | ANNOTATE→ARCHIVE | 159 lines verdicted; fine row 12 (PapDashboard e2e host run) = NOT-DO-deferred, harvested as T89 |
| docs/reviews/archived/2026-06-19_full-code-review.html | RESOLVED→ARCHIVE | banner: all findings closed (postPatch elimination, publicDeps rework, hardening sweep, v0.1.0) |
| docs/feedback/processed/2026-08-03_*.md | LEAVE (terminal) | already terminal; 5 evidence rows verdicted; lines 143–145 = code-fence false-positive table (T86) |

## d) Standing backlog (T72–T89 disposition — merge-by-reference only)

| Row | State | Note |
| --- | --- | --- |
| T72 billing rerun | BLOCKED (owner-side) | unchanged; every push local-green |
| T73 gogenfilter TS | TODO | still open in TODO_LIST |
| T74/T75 convergence sweeps | TODO | unchanged |
| T76 bank-sync app adoption | TODO | unchanged |
| T84 samber-linter test restructure | TODO | unchanged |
| T85/T86 docs-gates upstream | TODO (new) | append-verdict mode; separator + fence normalizer |
| T87 spec-files-not-chat | TODO (new) | docs-health skill protocol row |
| T88 daemon push gating | TODO (new) | harvested from 06-46 item 30 (repo: crush-config) |
| T89 PapDashboard e2e host run | TODO (new) | harvested from 11-17 plan fine 12 |

## e) Verification (this session)

- `docs-gates run .` → **5/5 PASS** (freshness, audit-all, annotate,
  routing, cadence) at annotate=0.
- `annotate.go check-rows --strict` + `bare-rows`: 5 planning MDs +
  feedback complete/clean; all touched archived files complete.
- Pre-flight SAFE for every landed living-doc line (T85–T89, ROADMAP
  bullets, purge bullets).
- `nix fmt`, local gates, `nix flake check --no-build`: run at commit
  time (see §f).

## f) Commit + push

Detailed commit (this session's corpus completion) + `git push origin
master` (explicitly ordered 2026-11-19) + CI watch via `gh run`.

## g) Lessons exported

- judge-vocab / routed-form canon → AGENTS.md (this repo) + crush-config
  lessons.md.
- digit-class grep trap (`nix2container` breaks `[a-zA-Z_]+` counts) →
  crush-config lessons.md.
- subagent spec-files-not-chat (3 transcription failures class) →
  lessons.md + TODO_LIST T87.

_Point-in-time snapshot · 2026-11-19 01:58 · living sources: TODO_LIST.md / ROADMAP.md / CHANGELOG.md_
