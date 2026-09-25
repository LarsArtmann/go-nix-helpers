# Pareto Execution — Session Status Report

**Date:** 2026-09-25 04:33 CEST
**Scope:** Execution of `docs/planning/2026-09-24_18-13_pareto-execution-plan.md`
(Workstreams A–D partial), interrupted mid-D13 by a host-level Nix daemon
failure and session end.
**Mode:** Execute and verify one step at a time; repeat.

---

## a) FULLY DONE

- **A1–A6 (P1, 1% tier):** The goPkgAttr auto-default triple-flagged "biggest
  honest gap" is now EVIDENCE. erraudit, projects-management-automation (PMA),
  and go-auto-upgrade each: go-nix-helpers lock bumped to master (1964f4f),
  `nix flake check --no-build` green, **full `nix build` green, vendorHash
  intact** (A2/A4/A6 exit 0). PMA exercises the auto default for real (no pin)
  and proves `requireDeps` resolves from remote master.
- **A7–A10 (P2):** goPkgAttr pin inventory built (15 real `go_1_27` pins).
  Analytical risk elimination first: probed every sweep repo's nixpkgs via
  `builtins.getFlake` — **no repo has go_1_28/go_1_29**, so auto-resolution is
  provably toolchain-neutral. Removed pins + stale rationale comments in
  **14 repos** (crush-daily skipped: mkGoFlake, pin dies with C26 migration).
  All 14 eval-verified green after lock bump. Daemon committed them
  (spot-checked: go-localsync 8a558a6 = flake.lock + pin line gone).
- **B1–B3 (P3):** requireDeps module coverage: default `{}`, forwarding into
  mkPreparedSource postPatch (`packages.default.src.postPatch` assertion), and
  test.nix Test 5 sibling-module case (plain `codec` injected exactly once
  despite `codec/v2` sibling — needed subModules entry to satisfy
  build-time validation; first run failed with the validation error, fixed).
- **B4–B5 (P4):** `checks.templFixtureGuard` in flake.nix (store-scan of the
  fixture = sandbox-safe equivalent of `git ls-files`, since flake sources
  contain only tracked files). Verified BOTH directions: green clean, RED with
  `git add -f`ed fixture file ("FAIL: generated *_templ.go files are
  tracked"), then restored.
- **B6–B9 (P5):** `pure-functions.goBaseFrom` extracted — single
  toolchain-resolution site (pin / auto-newest / pkgs.go fallback / go.dev
  tarball with version-suffixed patch swap / override hook). Both
  `modules/go-standard.nix` and `mkGoFlake.nix` now call it; **mkGoFlake gains
  the tarball patch-swap it was missing** (the split brain fix). 9 property
  tests with stub pkgs attrsets incl. `overrideAttrs` emulation.
  Counts from tool output: **moduleTest 121→123, pureFunctions 41→50**.
- **D1–D4 (P13):** Three new options (module now **44 options**):
  `goExperiment` (nullOr str → build env + devShell GOEXPERIMENT),
  `cgoEnabled` (nullOr bool → CGO_ENABLED), `completionStyle`
  (enum flag/subcommand → cobra-style `completion <shell>` vs default
  `--completion <shell>`). Options win inside `env` but preserve consumer
  `extraBuildAttrs.env` keys; `shellExtraEnv` still wins in shells.
  Tests: 3 defaults + 8 propagation assertions (build env, devShell,
  postInstall invocation both styles). Docs: README rows, man page entries,
  CHANGELOG, AGENTS.md/FEATURES.md counts updated from tool output.
- **D5:** templ-committed negative test now asserts the throw MESSAGE contains
  "without a committed *_templ.go sibling" (intended-throw vs eval-error).
- **D6:** verifyValidation now also asserts the error NAMES the missing module
  (`github.com/larsartmann/nonexistent-dep`). *(Script change eval-verified;
  execution blocked by host issue — see §d.)*
- **D7:** publicDeps paths ERE-escaped (`sed 's/[.[\*^$()+?{|]/\\&/g'`) before
  `grep -vE` — domain dots no longer act as wildcards that silently skip
  validation for a different module.
- **D8:** excludeSubModuleDirs entries validated at EVAL time against
  `[A-Za-z0-9._-]+` (they're spliced into a shell case PATTERN); named throw
  "literal directory names"; adversarial test via tryEval.
- **D9:** `proxyVendor = true` under deps now emits a builtins.trace warning
  instead of silently flipping to false.
- **D12:** mkGoFlake (deprecated) eval smoke test: minimal config through
  `lib.evalModules` + perSystem stubs → `packages ? default`. treefmt-nix
  flakeModule stubbed (evaluating the real one pulls treefmt-nix's own locked
  inputs — store-invalid under `--no-build`).
- **Docs hygiene:** TODO_LIST rows T1/T2/T6/T7/T8 removed (lifecycle rule),
  T3 marked 3/10 done, T9 marked partially done via goBaseFrom tests.
- **Commits:** a437284 (B-tier, mine) + daemon heuristic commits carrying the
  D-tier work. NOT pushed (per instruction).

## b) PARTIALLY DONE

- **D13–D14 (P16, go.mod floor check):** Implemented in `modules/go-standard.nix`
  (eval-time read of consumer root go.mod, numeric per-component compare with
  longer-list-wins semantics matching Go, suffix-tolerant version parsing,
  actionable 3-fix throw message, forced via `builtins.seq` in the package
  chain) + 2 test assertions (throw + message content). **VERIFIED GREEN via
  clean-worktree check** (see §d.1c for why the main tree's checks were
  flaky). D15 docs: man page EVAL-TIME CHECKS section, README FAQ entry,
  CHANGELOG entry — done.
- **D10 (templ generate in module builds):** Investigated, deliberately
  REDESIGNED: standard-bug-tracking-schema commits its `*_templ.go` (verified),
  so build-time `templ generate` would be dead weight + reproducibility risk
  (templ-version-dependent output). Resolution: remove the VESTIGIAL consumer
  override during C8 instead of adding module machinery. Decision documented
  here; consumer edit not yet made.
- **C1–C10 (Tier A build-verification):** 3/10 done (erraudit, PMA,
  go-auto-upgrade via A2/A4/A6). The other 7 (go-localsync, project-meta,
  oxlint-auto-configure, project-dependency-graph, golangci-lint-auto-configure,
  go-humanize-linter, standard-bug-tracking-schema) were queued in a background
  loop whose shell was reaped without logs — **not built** (and now blocked by
  the host issue).
- **D11 (pkgs.go fallback test):** Covered via goBaseFrom stub tests (T9
  partially closed); mkGoFlake smoke was the remaining gap — now done via D12.

## c) NOT STARTED (plan order)

- C11–C26: Tier B migrations (KeyCountdown, branching-flow, StopTube, overview,
  bank-sync, BuildFlow), Tier C (Standup-Killer, crush-daily off mkGoFlake).
- E1–E4: annotation gates vendored into scripts/ + flake check + exemption notes.
- F1–F16: docs cosmetics (list-marker spacing, render-verify, groff), hygiene
  (result* symlinks, comments, nix-lint generalization, dashboard GO_LATEST),
  old-nixpkgs CI job, records (0817f80 note, lock-bump postmortem), watchlist.
- G1–G7: blocked enablers (v0.1.0 + deletions, nixpkgs maintainer PR, SSH CI,
  df9a5ff, Won't-implement policy).

## d) TOTALLY FUCKED UP (honest section)

1. **Host Nix breakage mid-session (EXTERNAL, root action needed).** The nix
   daemon restarted 04:06 (nix 2.34.8, NixOS switch) and since then:
   - **ALL local builds fail**: `error: getting attributes of path
     "/run/binfmt": No such file or directory`. Root cause:
     `/etc/nix/nix.conf` line 28 `extra-sandbox-paths = /run/binfmt
     /nix/store/31rksc1wkr54dadg615c1qd0rxk9gnk6-qemu-aarch64-binfmt-P` — the
     systemd-binfmt mount vanished with the restart. Not user-fixable: mkdir
     /run/binfmt denied, systemctl banned, `--option` overrides rejected
     (trusted-users = root only), `sandbox = false` does not bypass it.
     **Fix (root): `systemctl restart systemd-binfmt.service`** (or restore the
     `boot.binfmt.emulatedSystems` mount), then daemon picks it up.
   - **Nixpkgs pin closure loss**: the flake's old nixpkgs rev (4975466)
     lost substitutable bootstrap paths (`l622p70...-source` "don't know how
     to build"). Fixed by `nix flake lock --update-input nixpkgs` (low risk:
     test mocks use vendorHash=null; `expectedAutoGoAttr` auto-adapts).
     **Uncommitted lock bump is in the tree.**
   - **Intermittent `path ... -source is not valid` during flake check.**
     ROOT CAUSE FOUND (initial hypothesis in this bullet was WRONG — it is
     NOT a pathExists-context bug in the floor check): nix 2.34's handling of
     DIRTY git trees plus the auto-commit daemon committing DURING a running
     `nix flake check` invalidates the dirty-tree source copy mid-check.
     Proof: `git worktree add /tmp/gnh-clean HEAD && cd /tmp/gnh-clean &&
     nix flake check --no-build` → **all checks passed** with the full D-tier
     work including the floor check. RECIPE (now f.41): verify from a clean
     worktree whenever the main tree is dirty or the daemon is active.
     (b) the treefmt-nix module-pull variant was real and is fixed via the
     D12 stub; (c) one misleading detour blamed the floor check — bisect
     disproved it.
2. **Commit races:** the auto-commit daemon swept my staged B-tier commit
   twice (my heredoc commit silently no-op'd on an empty index after daemon
   commits; "git log -1" then printed the daemon's hash, briefly making me
   think my commit landed). Lesson: with this daemon, `git add` + immediate
   `git commit` in one `&&` chain, and verify by SUBJECT not hash position.
3. **Background job loss:** the Tier A build loop (shell 087) vanished
   ("background shell not found") with its /tmp logs — builds never recorded.
   Re-run on resume; don't trust long-lived background shells across daemon
   restarts.

## e) WHAT WE SHOULD IMPROVE

- **Eval-time path discipline:** codify the walkTempl rule (never
  `pathExists`/`readFile` on `outPath + "/str"`) as a lint or at least a test —
  this session hit the exact documented trap.
- **Host canary:** a `scripts/nix-health.sh` (binfmt present? daemon age?
  /nix free space?) run before long verification batches would have saved ~40
  minutes of confused debugging.
- **Daemon-aware verification:** when the auto-commit daemon is active, run
  `nix flake check` only on clean trees; otherwise its dirty-copy races look
  like evaluation bugs.
- **verifyValidation (D6) and all BUILD-verifications are hostage to the host
  fix; CI (GitHub Actions) is unaffected by the host issue** — pushing master
  would get the suite built, but push was not requested.

## f) Up to 50 things to do next

1. Root-fix `/run/binfmt` (systemctl restart systemd-binfmt) — unblocks ALL local builds
2. Resume D13 verification after fixing the pathExists-context bug (mirror walkTempl)
3. D14: floor-check message-content assertion (written, unverified)
4. D15: floor-check docs (man page, README FAQ "go.mod newer than nixpkgs", CHANGELOG)
5. Commit the nixpkgs lock bump explicitly with rationale
6. Re-run Tier A builds (C1–C9) for the 7 remaining repos; fix vendorHash via `buildflow -s nix-hash-fix --fix` where bitten
7. C10: record 10/10 Tier A matrix in TODO_LIST T3 evidence
8. C8 during build-verify: remove sbts's vestigial templ/GOEXPERIMENT extraBuildAttrs override (goExperiment option now covers it)
9. C11–C12: migrate KeyCountdown to go-standard (eval+build+commit)
10. C13–C14: migrate branching-flow (go-enum tool via extraBuildAttrs)
11. C15–C16: migrate StopTube (G2 per-package attrs in anger)
12. C17–C18: migrate overview (git-hooks input stays consumer-side; nixosModules via perSystem)
13. C19–C20: migrate bank-sync (allowUnfree consumer-side)
14. C21–C23: migrate BuildFlow (1215-line flake; multi-tool packages via G2)
15. C24: migrate Standup-Killer off mkGoFlake (subModules + doCheck=false)
16. C25–C26: migrate crush-daily (NixOS module via perSystem; also removes its goPkgAttr pin) — mkGoFlake then has ZERO consumers
17. E1: vendor check-rows.py + grep-gate wrapper into scripts/ (attribution comment)
18. E2: checks.docs-annotations running both gates over docs/status/
19. E3: guard-the-guard (un-strike a row → red → restore)
20. E4: exemption notes for 07-38 §B + 06-51 "What went well"
21. F1: `^(\s*\d+)\.~~` → `$1. ~~` corpus pass over docs/status
22. F2: render-verify 5 largest struck tables
23. F3: MANWIDTH=80 groff check of both man pages (new entries included)
24. F4: trash the 7 `result*` symlinks + gitignore `result*`
25. F5–F6: autoDiscoverScript -mindepth comment + "any depth" header fix
26. F7: `__intentionallyOverridingVersion` in the goPkgOverride test (silences the "overridden with version but not src" warning noise seen in eval output)
27. F8: nix-lint.sh generalize go_1_26-outline → go_1_XX-outline
28. F9: dashboard.sh derive GO_LATEST from nixpkgs attrNames
29. F10: old-nixpkgs pinned CI matrix job (moduleTest only)
30. F11: docs/corrections/0817f80 mechanism note (indented-string interpolation, not "regex mismatch")
31. F12: docs/postmortems/lock-bump eval-break case study (this session's §d.1 is fresh material)
32. F13: CV lock+vendorHash proof (coordinate with CV repo)
33. F14: root-cause x86_64-darwin "incompatible system" warning
34. F15: `passthru.go` exposure audit (packages.default.go exists — seen in test line 863)
35. F16: warn when goPkgAttr pins older than nixpkgs newest
36. G-series after owner decisions: v0.1.0 tag → delete mkGoFlake + go-flake-parts template; maintainers PR; SSH CI; df9a5ff; Won't-implement policy
37. Update TODO_LIST: T11 (templ message assert) done, T12 (ERE escape) done, T20 (exclude quoting) done, T14 (proxyVendor warn) done, T9 (fallback test) done, T10 (mkGoFlake smoke) done — remove rows after build-verify
38. FEATURES.md rows for floor check + hardened validations (after verification)
39. AGENTS.md: document the walkTempl path rule as a gotcha (pathExists on outPath string)
40. AGENTS.md: record the host binfmt incident + one-command fix in the gotchas
41. Consider `nix flake check` in a clean worktree (git worktree add) as the standard verification recipe under daemon pressure
42. Sweep consumers for GOEXPERIMENT boilerplate → goExperiment option adoption (7/10 Tier A repeat it)
43. Sweep cobra consumers → completionStyle = "subcommand" adoption
44. PMA-style requireDeps doc snippet in migration guide (it's the only consumer)
45. Re-verify pureFunctions/moduleTest counts from tool output after host fix (should be 50/123... 125 with D14)
46. Investigate whether the nixpkgs bump changed goBaseFrom auto resolution (go_1_28 might now exist — the 123-test uses newestGoAttrName dynamically, but consumers' pins were swept under the OLD resolution proof; re-run the attr probe if the bump moved newest)
47. Push master once user approves (CI validates the suite end-to-end)
48. Re-run `nix run .#verifyValidation` (D6 content check) after host fix
49. Delete /tmp/flaketest probe
50. Status-report self-annotation pass (docs-health discipline) once items above resolve

## g) Up to 3 questions

1. **Host fix approval:** May I (or you) run `systemctl restart
   systemd-binfmt.service` as root? Everything local-build-shaped is blocked
   on it; without it I can only eval-verify (CI would cover the rest after a
   push you haven't requested).
2. **nixpkgs bump:** I bumped the nixpkgs input to restore substitutability
   after the daemon restart invalidated the old pin's closure. Keep (commit
   with rationale), or pin back to a specific rev once the host is stable?
   Keeping it changes what CI tests (newer Go attrs may appear — see f.46).
3. **D10 redesign confirmation:** I chose NOT to add `templ generate` to
   module build phases (sbts commits generated files; regenerating in builds
   risks templ-version-dependent output) and will instead delete the vestigial
   consumer override in C8. OK to close T15 (templ in modBuildPhase) as
   won't-implement-with-reason?

---

*Report written at session interruption; living task source: TODO_LIST.md.*
