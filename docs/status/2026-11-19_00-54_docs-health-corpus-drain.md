# Session status: docs-health corpus drain (2026-11-19, 00:54)

_Owner-ordered docs-health execution: view ALL `2026-0*` snapshots, run the
docs-health skill superbly, make the six living docs superb, archive fully-done
files. This report responds to the "FULL COMPREHENSIVE STATUS UPDATE NOW, THEN
WAIT" order — execution is PAUSED at the batch-B boundary pending instructions._

**Battery state right now**: freshness PASS · audit-all PASS · annotate 68
findings (was **358** at session start, red at 359 by a daemon-introduced
regression) · routing PASS · cadence PASS. Local `checks.docsAnnotations` gates
1+2 PASS (56/56 files row-complete — first fully-green local run since the
daemon's 23:22 formatter commit broke it).

## a) FULLY DONE (executed + verified this session)

1. **Skill + corpus recon**: docs-health SKILL.md loaded in full (writer
   semantics, gates-before-mv canon, heading-mode canon); all 48 `2026-0*`
   files located; 9 live ones viewed (4 planning MDs, 2 HTML, postmortem,
   correction, feedback); battery baseline run and the 359-count regression
   root-caused.
2. **Live-report regression fixed** (`2026-11-17_18-52_*`): the formatter-mangle
   cycle on row 9 (whole-row strike → daemon re-mangle → restore → re-mangle,
   2 daemon rounds) broken at the root — row 9 restored to its NARRATIVE form
   (the original 305b4b1 strike was a misfire onto the wrong table), and the
   misfired README-audit verdict moved to its true home (§f row 9, line 84).
   The whole §f table (rows 5–13) now carries truthful per-row verdicts (done
   / superseded / still-open-routed). `check-rows`: file complete.
3. **Daemon formatter damage repaired**: separator rows with 2-dash first cells
   (`| -- |`) in 4 tables normalized to `| --- |` (they parsed as CLEAN DATA
   rows and failed the local uniformity gate); postmortem 09-25 mangled
   evidence block rejoined.
4. **Corpus drain wave 1+2 — 290 of 358 pre-canon A/evidence findings
   resolved** across 15 archived 2026-0* files (06-08, 06-09, 06-22, 06-29,
   07-23×2, 07-24×2, 08-03_02-51, 08-10_02-37, 08-10_08-44, 08-10_09-23,
   08-10_09-51, 08-10_16-50, 09-24 smart-defaults): every verdict
   evidence-based, all cited hashes verified against git (no invented hashes —
   four unverifiable ones were downgraded to hash-free evidence before
   application). 22 D-class self-contradictory verdicts ("done — still open")
   rewritten to current truth (Tier B/C migrations DONE 2026-11-18 etc.). All
   five F/spacing findings fixed (4 micro-edits + smart-defaults routed form).
5. **Living docs made honest** (drift found + fixed):
   - `ROADMAP.md`: T4/T5 fleet-migration bullet struck DONE; semver bullet
     struck DONE (v0.1.0); 218→237 assertions.
   - `FEATURES.md`: 238→237 twice; container "19-key"→20-key; ADDED
     update-vendor-hash row + ghcr-push-workflow template row.
   - `AGENTS.md`: 19→20-key (×2), 238→237, and the count re-derive command
     made digit-safe (`nix2container` contains a digit — every letter-only
     grep undercounted; the old canon command in AGENTS.md was itself wrong).
   - `README.md`: 17→20-key container; ADDED `templCliPackage` +
     `enableUpdateVendorHashApp` option rows (both shipped in v0.1.0 but
     missing from the table), update-vendor-hash app in the outputs table,
     ghcr-push-workflow.yml in the templates table.
   - `TODO_LIST.md` header: stale "54 options / 226 checks / round-5" harvest
     stamp → current truth (57 options, 237 checks, 2026-11-19 pass).
   - Count split-brain resolved: ground truth re-derived from tools
     (`grep -cE` digit-safe = 57 options; moduleTest run log = "237 checks";
     container = 20 keys; generate-flake --help confirms --templ/--private-deps
     still real — FEATURES was right, the round-7 summary was wrong).
6. **flake.nix daemon change judged + verified**: the `{ config, ... }` →
   `{ ... }` head change is SAFE (body's `config.go-standard.container.*` is
   the module-system config KEY; the systems mapping moved into the module on
   2026-11-17) — `nix flake check --no-build` all-green confirms.
7. **Verification method hardened**: every spec application ran through a
   guarded applier (atomic per file, line-count invariant, refuses
   non-struck targets) + `check-rows` after each wave; hash-verification loop
   over every cited short hash before application.

## b) PARTIALLY DONE (interrupted by the WAIT order)

1. **Batch F2 drain (~59 findings)**: subagent alejandra-verdicts-F2 was
   interrupted by the Crush restart; its session is resumable via
   `agent_send`. Files: 08-03_03-28 (12), 08-03_04-44 (10), 07-24_22-15 (10),
   08-10_15-51 (9), 08-10_14-39 (9), 08-03_02-47 (9). NOTE: its input file
   `/tmp/gnh-batch-F.tsv` was wiped by the midnight /tmp cleanup — on resume,
   feed the line list directly (rebuildable from the battery output or the
   file list in this report).
2. **Planning-corpus annotation** (athena-planning-corpus, also interrupted,
   resumable): ~350 bare task rows across
   `docs/planning/2026-06-29_*` (L1+L2 tables, companion report proves FULLY
   EXECUTED — one Phase-F migration of 5 to verify), `2026-08-10_02-41` (EXECUTED
   banner, P12 skipped on merit), `2026-09-24_18-13` (ranking snapshot,
   superseded), `2026-09-25_09-54` (CI-green plan, T65 DONE covers its polish),
   `docs/feedback/processed/2026-08-03_*` (resolved feedback, 7 rows). All are
   archive candidates once rows carry verdicts + `rows --strict`/`bare-rows`
   gates pass. The two HTML snapshots (07-24 pareto HTML, 06-19 review HTML)
   get dated resolution banners + `git mv` to `<dir>/archived/`.

## c) NOT STARTED (planned, gated on the WAIT)

1. TODO_LIST strike+purge: 41 unwrapped DONE rows → `docs-gates purge` into a
   CHANGELOG entry (TODO_LIST then holds only open work; purge keeps the
   audit-all replay green because CHANGELOG lines carry the tokens).
2. `.docs-gates.json` ratchet: at 0 findings, DELETE the pin (fleet default 0
   = maximally strict) + update the AGENTS.md ratchet note.
3. CHANGELOG `[Unreleased]` entries for this session (docs corpus drain +
   README/AGENTS/FEATURES/ROADMAP accuracy fixes).
4. Final full battery + `nix fmt` + `nix flake check --no-build` + commit.
5. Agent-resume of F2 + planning batches (see b).

## d) TOTALLY FUCKED UP (caught, corrected — the honest list)

1. **Three transcription-fabrication incidents in MY spec files** (not the
   agents'): (i) spec-D contained 25 INVENTED 06-09 rows ("same fix class —
   covered") — 06-09 was batch E's file, I wrote verdicts from assumption;
   (ii) a bulk r-conversion for 09-23 mapped 14 verdicts onto wrong lines;
   (iii) two path/hash slips (duplicated path segment, unverifiable hashes).
   ALL caught by the pre-application validator (paths/lineno/strike guards)
   and a hash-existence loop; the wrong content never reached the repo. The
   06-09 verdicts were then written from the file's OWN resolved sections
   (every disposition visible in-file). Lesson reaffirmed: construct spec maps
   from emitted keys/verified lines, never from remembered reports — the
   docs-health canon's exact warning.
2. **/tmp midnight wipe** destroyed the working scripts mid-session (applier,
   batch TSVs, findings list). No repo damage (daemon had committed
   everything); applier rebuilt from source; spec-B re-written. F2's input
   file needs rebuilding on resume (see b.1).
3. **Daemon interleaving**: 5+ heuristic commits captured session work
   mid-flight (ed3e607 14-file wave etc.) — content verified intact via
   grep markers after each capture. The daemon's own 23:22 commit had BROKEN
   the local uniformity gate (2-dash separators) — fixed in a.3.

## e) IMPROVE (process, this session's evidence)

1. The annotate writer has NO mode for the "struck-but-no-verdict" (pre-canon)
   class — `repair` skips already-struck lines. This session hand-built a
   guarded applier twice. UPSTREAM candidate: extend annotate.go with an
   `append-verdict` mode (fixture-tested) so the next corpus doesn't need a
   bespoke tool.
2. The AGENTS.md count-derivation command was digit-unsafe (`[a-zA-Z_]+`) —
   `nix2container` broke EVERY letter-only count (17 vs 19 vs 20-key split
   brain across three docs). Fixed in AGENTS.md; the lesson belongs in
   crush-config lessons.md (transcribe → verify with the exact command class
   before publishing counts).
3. Separator-shape damage (`| -- |` vs `| --- |`) is invisible to every
   battery gate but fails the local uniformity gate — a 2-line normalizer
   sweep across docs/ is cheap insurance.
4. Subagent spec re-emits should land in FILES, not chat — my transcription
   was the failure point twice. (Blocked: read-access agents can't write;
   consider write-access-to-/tmp dispatches for spec-producing agents.)

## f) NEXT (ordered; execution paused)

1. ~~Resume alejandra-verdicts-F2 (feed rebuilt line list) → drain last ~59
   archived findings → battery annotate = 0.~~ done — F2 spec applied (39 verdicts, 6 hashes verified); annotate = 0 findings CLEAN, twice confirmed
2. ~~Resume athena-planning-corpus → apply planning/feedback verdicts →
   `rows --strict` + `bare-rows` per file → `git mv` to archived/ (planning
   plus reviews; banners for the 2 HTMLs) → manifest in the wrap-up report.~~ done — 645 rows verdicted via repair; all strict/bare gates green; 7 files archived; manifest in docs/status/2026-11-19_01-58_docs-corpus-completion.md
3. ~~Ratchet: delete `.docs-gates.json` (0 = default), update AGENTS.md note.~~ done — pin deleted at annotate=0 confirmed twice; AGENTS.md note rewritten (judge-vocab + routed-form canon)
4. ~~TODO_LIST: strike + `docs-gates purge` the 41 DONE rows → CHANGELOG entry.~~ done — 41 rows purged into CHANGELOG [Unreleased] Changed; 6 drift items annotated closed first (pre-flight gate)
5. ~~CHANGELOG `[Unreleased]`: corpus drain + living-doc accuracy fixes.~~ done — corpus-completion summary entry + 41 purge bullets under Changed
6. ~~Final battery (5/5 green at annotate=0) + local gates + `nix fmt` +
   `nix flake check --no-build`; commit.~~ done — battery 5/5 PASS at annotate=0; verification + commit in the completion session (docs/status/2026-11-19_01-58_*)
7. ~~Optional push (owner call — billing blocker still gates 13 repos' CI).~~ done — push explicitly ordered (owner directive 2026-11-19) and executed in the completion session
8. ~~Standing rows unchanged: T72–T84 (billing reruns, T84 samber-linter,
   T73 gogenfilter TS, T74/T75 convergence sweeps, T76 bank-sync app adoption).~~ done — verified unchanged; T85–T89 added (upstream candidates + harvested gaps: daemon gating, PapDashboard e2e)
9. ~~Upstream candidates (docs-gates repo): append-verdict writer mode (e.1),
   separator-shape normalizer (e.3) — route via T79-class rows.~~ done — routed TODO_LIST T85 (append-verdict) + T86 (separator + fence false-positive)
10. ~~crush-config lessons.md: digit-class grep lesson (e.2) + "spec maps from
    emitted keys, twice burned in one session" (d.1).~~ done — lessons committed to crush-config references/lessons.md in the completion session (plus the judge-vocab routed-verdict lesson)

## g) QUESTIONS (3)

1. **Resume now or hold?** The remaining work (b + c) is ~2 focused hours:
   drain to annotate=0, archive the planning corpus, purge TODO_LIST, final
   gates. Say the word and it completes without further check-ins.
2. **Push when done?** Master is 8+ commits ahead of origin (daemon-swept);
   CI on origin is last-known-green at f59e03d-era. Billing still blocks 13
   repos' CI — gnh CI itself ran green on the last push.
3. **Purge depth**: purge ALL 41 DONE rows in one CHANGELOG entry (my
   recommendation — TODO_LIST becomes open-work-only), or keep the recent
   round-6/7 rows (T35–T59 era) struck-but-visible for one more cycle?


**§g Resolution (2026-11-19 01:58):** Q1 resume → done (this session). Q2 push → ordered + executed. Q3 purge depth → ALL 41 rows purged (owner default accepted).
