# Pareto Execution — Session Status Report #2 (post-interruption wrap-up)

**Date:** 2026-09-25 04:39 CEST
**Predecessor:** `docs/status/2026-09-25_04-33_pareto-execution-session-interrupted.md`
**Scope:** This report CORRECTS and SUPERSEDES the 04:33 report where they
conflict, covers the final wrap-up work (D13–D15 verification, commit), and
adds the honest what-was-forgotten / what-to-improve self-review demanded by
the session prompt.

---

## a) FULLY DONE (session total, code-verified)

- **A1–A6 (P1, 1% → 51%):** goPkgAttr auto-default verified on erraudit, PMA,
  go-auto-upgrade: lock bumped to master (1964f4f), eval green, **full `nix
  build` green, vendorHash intact**. PMA proves `requireDeps` from remote
  master with no pin (genuine auto-default exercise).
- **A7–A10 (P2):** 15-pin inventory → attr-probe (no go_1_28/1_29 in ANY
  consumer nixpkgs → removal provably toolchain-neutral) → pins + stale
  comments removed in **14 repos**, all eval-verified, daemon-committed
  (spot-checked). crush-daily deferred (mkGoFlake; dies in C26).
- **B1–B9 (P3–P5):** requireDeps module coverage (default, postPatch
  forwarding, Test 5 sibling dedup); `checks.templFixtureGuard` verified
  red+green; `pure-functions.goBaseFrom` unified toolchain resolution
  (mkGoFlake gains the tarball patch-swap). **moduleTest 121→123,
  pureFunctions 41→50** (from build logs, before the host broke).
- **D1–D4:** `goExperiment` / `cgoEnabled` / `completionStyle` (module = 44
  options), build-env + devShell + postInstall propagation tested; README /
  man / CHANGELOG / AGENTS / FEATURES updated.
- **D5–D9, D11, D12:** templ-committed throw-message assertion;
  verifyValidation names the missing module; publicDeps ERE-escaping;
  excludeSubModuleDirs eval-time validation + adversarial test; proxyVendor
  trace warning; pkgs.go fallback via goBaseFrom stubs; mkGoFlake eval smoke
  (treefmt-nix stubbed — real module pulls its own locked inputs).
- **D13–D15 (finished after the 04:33 report):** Eval-time go.mod floor check
  implemented + 2 tests + docs (man EVAL-TIME CHECKS section, README FAQ
  entry, CHANGELOG). **Verified green** via clean-worktree check at c6b63ef
  (which contained all code; 72184a3 added only docs/report).
- **D10:** investigated and consciously redesigned — sbts commits its
  `*_templ.go` (verified), so module-side `templ generate` would be dead
  weight + reproducibility risk; resolution = remove the vestigial consumer
  override during C8. Awaiting owner confirmation (question g.3).
- **Commits:** a437284 (B-tier) + 72184a3 (floor check + report #1) mine;
  daemon heuristic commits carry the D-tier edits. **Nothing pushed** (per
  standing instruction). Working tree clean at 04:39.

## b) PARTIALLY DONE

- **C1–C10 (Tier A build-verification):** 3/10 (erraudit, PMA,
  go-auto-upgrade). The 7-repo background loop was lost (see d.3) and is now
  double-blocked (binfmt + GC flake check).
- **D6 execution:** verifyValidation script hardening is committed but the
  script itself (`nix run .#verifyValidation`) has NOT been executed this
  session — blocked with all local builds.
- **README paragraph near-miss:** while inserting the FAQ entry I briefly
  clipped the SSH-error explanation paragraph; caught and restored
  immediately. Final file verified re-read — no residual damage.

## c) NOT STARTED

C11–C26 (Tier B/C migrations: KeyCountdown, branching-flow, StopTube,
overview, bank-sync, BuildFlow, Standup-Killer, crush-daily), E1–E4
(annotation gates in CI), F1–F16 (docs cosmetics, hygiene, records,
watchlist), G1–G7 (blocked enablers). Full list in report #1 §f (50 items,
still accurate).

## d) TOTALLY FUCKED UP (honest, with corrections)

1. **Host Nix environment collapsed mid-session (EXTERNAL, root required).**
   Two distinct root causes, both introduced by the 04:06 daemon restart:
   - **All local builds fail**: `/run/binfmt` gone; `/etc/nix/nix.conf:28`
     binds it into every sandbox; untrusted users cannot override.
     Fix: `sudo systemctl restart systemd-binfmt.service`.
   - **`nix flake check` flaky-to-broken**: daemon-side auto-GC (`max-free =
     30G` vs 145G store) deletes unrooted source copies between eval and
     check phases → `path ...-source is not valid`, now deterministic even
     from clean worktrees. Fix (root): raise/disable auto-GC thresholds in
     nix.conf and restart the daemon.
2. **My wrong root-cause hypothesis (corrected):** I blamed D13's
   `self.outPath + "/go.mod"` pathExists pattern for the check failures —
   even accused myself of violating walkTempl's documented rule. Bisect
   disproved it (failure persisted with the floor check disabled); the
   clean-worktree pass then disproved the dirty-tree-only theory; the final
   deterministic failures exposed the GC as the real cause. Cost: ~30 min of
   debugging on a wrong theory, one status report (#1) published with a
   diagnosis I had to correct 5 minutes later.
3. **Background job loss:** the Tier A build loop (shell 087) vanished with
   its logs — likely reaped when the daemon/host churned. Its 7 builds never
   ran and were silently missing from my accounting until report #1.
4. **Commit races with the auto-commit daemon:** twice my staged heredoc
   commits no-op'd (daemon had just swept the index) and `git log -1` then
   showed the daemon's hash, briefly convincing me my commit had landed.
   Lesson applied too late: chain `git add -A && git commit` in ONE command
   and verify by commit SUBJECT, not position.
5. **Unverified assumption in report #1:** I wrote "nixpkgs bump fixed it /
   uncommitted lock bump is in the tree" — the bump was actually a NO-OP
   (4975466 is the current unstable tip; `nix flake update nixpkgs` exit 0,
   no change). I reported an action I did not verify. Corrected in report #1
   via edits, re-stated here so the correction is on the record.

## e) WHAT WE SHOULD IMPROVE

- **Verify host health before long batches** (binfmt present, daemon age,
  store size vs max-free, GC activity). A 10-second canary would have saved
   ~90 minutes across this session. → f.1.
- **Never report an action as done without its observable effect** (the
  no-op flake update). Check the diff/rev AFTER the command, always.
- **Hypothesis discipline:** I had three theories (pathExists-context,
  dirty-tree race, GC) and jumped to publishing the first. Cheap decisive
  experiments (disable-the-feature bisect, clean worktree) existed for all
  three; run them BEFORE writing conclusions into reports.
- **Verification recipe under daemon pressure:** evaluate from
  `git worktree add /tmp/x HEAD` (no daemon interference) — worked when
  nothing else did; now also flaky due to GC, so pair with f.1.
- **CI is the build oracle now:** the host cannot build; GitHub Actions can.
  Pushing master (needs approval) would validate the entire D-tier suite
  end-to-end within minutes.

## f) Up to 50 things to do next

1. ROOT: `sudo systemctl restart systemd-binfmt.service` (restores all local builds)
2. ROOT: fix nix.conf auto-GC thresholds (`max-free` 30G → e.g. 200G, or drop auto-GC) + daemon restart (stabilizes flake check)
3. Add `scripts/nix-health.sh` canary (binfmt, daemon age, store vs max-free, free disk) — run before verification batches
4. Re-run full `nix flake check` + `nix run .#verifyValidation` after host fix (validates D6 content check + suite)
5. Re-attempt Tier A builds C1–C9 for the 7 remaining repos (foreground, per-repo logs — no long-lived background loops)
6. vendorHash fixes via `buildflow -s nix-hash-fix --fix` where bites occur; commit per repo
7. C10: record 10/10 Tier A matrix in TODO_LIST T3 evidence
8. C8: remove sbts's vestigial templ/GOEXPERIMENT extraBuildAttrs override (goExperiment option replaces it)
9. Close g.3 → if approved, mark T15 won't-implement-with-reason in TODO_LIST
10. C11–C12: migrate KeyCountdown (eval+build+commit)
11. C13–C14: migrate branching-flow (go-enum via extraBuildAttrs)
12. C15–C16: migrate StopTube (G2 per-package attrs in anger)
13. C17–C18: migrate overview (git-hooks input consumer-side; nixosModules via perSystem)
14. C19–C20: migrate bank-sync (allowUnfree consumer-side)
15. C21–C23: migrate BuildFlow (1215 lines; multi-tool packages via G2)
16. C24: migrate Standup-Killer (subModules + doCheck=false)
17. C25–C26: migrate crush-daily (NixOS module via perSystem; removes its pin) → mkGoFlake ZERO consumers
18. E1: vendor check-rows.py + grep-gate wrapper into scripts/ (docs-health attribution)
19. E2: checks.docs-annotations over docs/status/
20. E3: guard-the-guard (un-strike → red → restore)
21. E4: exemption notes (07-38 §B, 06-51 went-well)
22. F1: `^(\s*\d+)\.~~` → `$1. ~~` corpus pass
23. F2: render-verify 5 largest struck tables
24. F3: MANWIDTH=80 groff check (man pages gained 3+2 new entries tonight)
25. F4: trash 7 `result*` symlinks + gitignore
26. F5–F6: autoDiscoverScript mindepth + header comments
27. F7: `__intentionallyOverridingVersion` in goPkgOverride test (warning noise observed live in eval output)
28. F8: nix-lint go_1_XX-outline generalization
29. F9: dashboard.sh GO_LATEST from attrNames
30. F10: old-nixpkgs pinned CI matrix job (moduleTest only)
31. F11: docs/corrections/0817f80 note (indented-string interpolation)
32. F12: docs/postmortems/lock-bump case study — now with THIS session's GC/binfmt material as a second case
33. F13: CV lock+vendorHash proof
34. F14: x86_64-darwin warning root-cause
35. F15: passthru.go exposure audit (packages.default.go confirmed to exist)
36. F16: warn when goPkgAttr pin < nixpkgs newest
37. After owner decisions: G1 v0.1.0 tag → G2/G3 deletions (mkGoFlake + go-flake-parts template); G4 maintainers PR; G5 SSH CI; G6 df9a5ff; G7 policy
38. TODO_LIST row removals after build-verify: T11, T12, T14, T20, T9, T10 (eval-verified tonight; remove only when built or owner-accepted)
39. FEATURES.md rows: floor check, hardened validations, new options (after build-verify)
40. AGENTS.md gotcha: clean-worktree verification recipe + daemon commit-race pattern
41. AGENTS.md gotcha: host binfmt/GC incident + the two root fixes
42. Consider making `nix flake check` a CI-required workflow_dispatch target for exactly this "host broken, CI is the oracle" scenario
43. Sweep consumers: GOEXPERIMENT boilerplate → `goExperiment` option (7/10 Tier A repeat it)
44. Sweep cobra consumers → `completionStyle = "subcommand"`
45. Migration guide: requireDeps snippet (PMA is the only consumer — copy its pattern)
46. Re-run the consumer attr-probe after any future nixpkgs bumps (tonight's probe was against pins that all resolved go_1_27; a future newest-go jump reintroduces vendorHash risk the sweep's proof relied on not existing)
47. Delete /tmp/flaketest probe + /tmp/mkgoflake_block.nix leftovers
48. Push master after approval → CI validates D-tier suite end-to-end
49. Self-review this status report pair for docs-health annotation discipline once items resolve
50. (Reserved — nothing further invented; the 49 above are real and sourced)

## g) Up to 3 questions

1. **Host repair:** Will you run the two root fixes (binfmt restart; nix.conf
   auto-GC thresholds + daemon restart), or should all remaining local
   verification wait indefinitely? Without at least the binfmt fix, no
   consumer migration (C-tier) can be honestly completed.
2. **Push for CI validation:** Master now carries the entire D-tier suite,
   eval-verified but never BUILD-verified (host broke first). May I push so
   GitHub Actions becomes the build oracle? (You said don't push unless
   asked — asking.)
3. **D10 redesign:** Confirm closing T15 (templ generate in module builds)
   as won't-implement — consumer-side vestigial-override removal in C8
   instead — given the templ-committed contract makes build-time generation
   dead weight and templ-version-dependent output a reproducibility risk.

---

*Session ended clean: tree clean at 72184a3, nothing pushed, all findings
on the record in this report pair.*
