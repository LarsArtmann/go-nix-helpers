# Status 2026-11-18 12:29 — T50 bank-sync migration GREEN (battery all-pass), T5 half-landed, go-standard silent-empty-bin bug found+fixed

Session: TODO round 3, ~11:15–12:29 CET. Predecessor: `2026-11-18_11-04_todo-round2-ci-green-t49-closed-t50-bank-sync-migration.md`.

## a) Fully done (this session)

| Item                                                 | Evidence                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| cqrs-lint FOD root-caused + FIXED                    | Binary reports `go-finding: 1.15.1`; `.#cqrs-lint`/`.#erraudit` build green; new vendorHash `sha256-nR3Jo…` via canonical dance                                                                                                                                                                                                                                                                                                                    |
| Root cause: content-addressed FOD cache reuse        | Old `vendorHash` (2026-08-29) made nix reuse cached old-graph output (`8dhxdk3v`, deriver `zxrcf69v`) against the new prepared source → `go: inconsistent vendoring` in the PACKAGE build. This is AGENTS/05 gotcha "FOD output paths are keyed by vendorHash" — re-derived from scratch before re-reading the canon (self-critique below)                                                                                                         |
| Companion inputs aligned to canon rev                | `go-finding-lint` v1.15.0 → v1.15.1 (toolsdk v1.16.0 verified ancestor of the v1.15.1 tag); lock `49669e36`                                                                                                                                                                                                                                                                                                                                        |
| Freeze-era stale docs rewritten                      | flake.nix input comment (freeze rationale marked OBSOLETE — the templ v0.3.1100 migration IS taken now), cqrs-lint block comment + `version = "unstable-6f8dd604"`, witness note, CI workflow rev/parity assertions (`.github/workflows/ci.yml`), AGENTS/05 lines (pin policy: NO frozen-rev exceptions remain)                                                                                                                                    |
| templ v0.3.1100 lockstep completed in bank-sync      | Repo `go.mod` tidy (ambient = pinned go 1.27.3): uniform templ-components submodules v1.27.0, a-h/templ v0.3.1100; `_templ.go` regenerated with templ v0.3.1100 (3 files, old symbols gone)                                                                                                                                                                                                                                                        |
| cqrs-htmx v4.15.0 → v4.16.0 + go-sse v0.6.2 → v0.7.0 | v4.15.0's tree still required templ v0.3.1070 (13 stale symbol refs) — v4.16.0 is the first root tag with regenerated dashboardui; root delta vs v4.15.0 is ONLY go-sse v0.7.0. Alignment check green (`cqrs-htmx v4.16.0 == lock 1d8c8b68d`, submodule tag v4.16.0)                                                                                                                                                                               |
| Main vendorHash dance                                | `sha256-wmjPuA…` → `sha256-IGUPQ…` (alignment run BEFORE dance, per canon)                                                                                                                                                                                                                                                                                                                                                                         |
| Catalog regenerated                                  | `bank-sync catalog -o docs/catalog` (asyncapi.json updated) → catalog-drift check green                                                                                                                                                                                                                                                                                                                                                            |
| **bank-sync FULL battery GREEN**                     | `catalog-drift cqrs-lint-vendor-witness dep-alignment pinned-tree format golangci-config image-oci container-structure lint test build vendor-hash bank-sync-image cqrs-lint erraudit` — exit 0 (12:29). Binary present in `bin/`, help renders                                                                                                                                                                                                    |
| **go-standard silent-empty-bin bug found + fixed**   | Module default `subPackages = ["."]` built only the module root → cmd/-layout repos got a green build with EMPTY bin/ (caught by bank-sync's catalog-drift invoking the binary). Default now `[]` (nixpkgs auto-discovery semantics), monorepo `packages.<name>` entries same; man page + moduleTest assertion updated (test green). Committed by daemon as `517db1c` (my message lost — content intact)                                           |
| Standup-Killer flake migrated off mkGoFlake          | Full rewrite to go-standard (treefmt-nix + systems inputs dropped, real-flake go-nix-helpers input + follows, all dep/subModule/publicDeps/GOEXPERIMENT→goExperiment/doCheck→enableCheck=false+enableTestCheck=true mappings, requestid-no-name-leak check preserved as perSystem check). Lock updated (unused inputs pruned). FOD hash shifted exactly as the go-nix-helpers-input-bump lesson predicts → new hash applied (build pending, see b) |

## b) Partially done

| Item              | State                        | Remaining                                                                                                                                                                                                                                                                                                                                                                                         |
| ----------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T5 Standup-Killer | Flake + lock + hash done     | Rebuild `.#default`, then full `nix flake check`; the requestid check + hermetic test never ran                                                                                                                                                                                                                                                                                                   |
| T5 crush-daily    | Flake REWRITTEN (unverified) | `nix flake update` not run (systems/treefmt still in lock); NO build attempted; `config.go-standard.goPkg or pkgs.go_1_27` in perSystem apps is UNVERIFIED and likely wrong (transposed option may not expose goPkg in perSystem scope — was written at speed, flagged self-critique)                                                                                                             |
| T50 bank-sync     | Battery green LOCALLY        | `nix flake check --no-build` full-matrix not re-run in final state; `nix develop` eval not re-verified; repo go.mod/go.sum tidy changes + catalog + regenerated templ files are daemon-committed as mid-edit heaps (no coherent unit commit — daemon protocol note owed); bank-sync was PUSHED to origin by something (daemon — verified `master...origin/master` even at ~11:20, I did not push) |

## c) Not started (this session)

T4 remainder (KeyCountdown, StopTube, branching-flow, overview, BuildFlow) · T34 GOEXPERIMENT/completionStyle fleet sweep · T52 dockerTools block sweep · T57 post-push flake-update sweeps · T60 fleet audit re-run · T71 heading-mode canon · T41 multi-arch manifest · T42 container.fromImage · docs batch (AGENTS.md corrections+counts, TODO_LIST statuses, CHANGELOG, FEATURES) · owed TABLE VIEW report · final ci-parity + push + CI.

## d) Totally fucked up / mistakes

1. **Re-derived a documented root cause from scratch.** The FOD-cache-reuse mechanism is verbatim AGENTS/05 line 18 ("bumping a tool input while keeping its old vendorHash makes Nix reuse the cached FOD silently"). I spent ~6 tool roundtrips (deriver forensics, ancestry checks) BEFORE re-reading the gotchas file that stated the answer. Read the repo canon FIRST.
2. **Unverified code written to disk (crush-daily).** The `config.go-standard.goPkg or pkgs.go_1_27` app wiring was never evaluated; daemon commits whatever is on disk. Should have eval-checked before writing the second migration.
3. **Piped exit-code lie re-hit** (twice: `nix build ... | tail; echo EXIT=$?` reads tail's status). Known gotcha, still burned a roundtrip on it.
4. **jq filter mangled by shell** (`.nodes.go-finding-lint.locked.rev` → "function not defined: lint/0") — quoting, my fault.
5. **Daemon commit-message quality lost** on the go-standard fix (`517db1c` "chore: auto-commit" instead of the explanatory message) — I chained add+commit but the daemon had already swept the files. Verify by subject-not-hash cuts both ways.
6. **subPackages default changed for monorepo `packages` entries without a consumer audit** — justified as visible-wrong-beats-silent-empty, moduleTest green, but no sweep of existing consumers relying on the `["."]` default. Risk carried, not closed.
7. **Background jobs left uncollected across the interruption** — battery3 + Standup-Killer build were running when the report was ordered (collected immediately after; both resolved, one green one hash-mismatch).

## e) What to improve

- **Consult AGENTS gotchas before diagnosing** anything FOD/vendor related in LarsArtmann repos — the canon is denser than my forensics.
- **Eval-verify each migration immediately** (`nix flake check --no-build` is cheap) before moving to the next repo; never leave written-but-never-evaluated flakes for the daemon to commit.
- **The go-standard module could refuse empty-bin builds**: `subPackages` auto-discovery that finds zero main packages should THROW (eval-time or post-build guard) — the bank-sync failure mode (green build, empty bin/) should be unrepresentable. Candidate TODO.
- **update-vendor-hash script pattern-matching** (`vendorHash = "`) breaks on `import ./vendorHash.nix` consumers (crush-daily) — either teach the script or migrate crush-daily to an inline hash during T5 completion.
- **A `--fod`-aware drift canary**: CI job that greps `cqrs-lint version` companion output against the flake input (bank-sync CI does this; generalize).

## f) Next (top 50, Pareto-ordered)

1. Collect/verify Standup-Killer rebuild with new hash → full `nix flake check`
2. Fix crush-daily perSystem goPkg access (likely `pkgs.go_1_27` direct) → `nix flake update` → eval → build
3. crush-daily hash dance (vendorHash.nix vs script pattern — reconcile)
4. crush-daily: anticipate the SAME templ/dashboardui trap (cqrs-htmx master + templ-components v1.26.0); likely cqrs-htmx v4.16.0 bump + templ regen + goldens
5. bank-sync: full `nix flake check --no-build` (+ `--all-systems`) final-state
6. bank-sync: verify `nix develop` evals again
7. bank-sync: daemon-protocol coherent commit note (mid-edit heap context)
8. bank-sync: push state audit (daemon pushed mid-edit states? billing-disabled CI = no oracle — flag to owner)
9. go-nix-helpers: push `517db1c` (established pattern, CI as oracle) + `gh run` watch
10. go-nix-helpers: `scripts/ci-parity.sh` (shellcheck + nix fmt + docs gates) before push
11. go-nix-helpers: full `nix flake check` on the subPackages change
12. go-nix-helpers: AGENTS.md gotcha entry (silent-empty-bin lesson + subPackages default change)
13. go-nix-helpers: TODO_LIST status updates (T49 done, T50 done, T5 partial)
14. go-nix-helpers: CHANGELOG + FEATURES for subPackages fix
15. go-nix-helpers: migration-guide bank-sync partial-adoption case study
16. go-nix-helpers: migration-guide subPackages-default note (behavior change)
17. Owner question: A12 canon fleet update (templ-components v1.27.0, cqrs-htmx v4.16.0, go-sse v0.7.0, go-finding v1.15.1)
18. Owner question: push approvals (Standup-Killer, crush-daily, KeyHolderAI, bugtracker, SKILLS, bank-sync)
19. Owner question: subPackages default — audit-first or ship?
20. Empty-bin build guard in go-standard (see e)
21. T4: KeyCountdown migration
22. T4: StopTube migration
23. T4: branching-flow migration
24. T4: overview migration
25. T4: BuildFlow migration (early-adopter `--override-input` recipe T47–T49)
26. T34: GOEXPERIMENT → goExperiment sweep (both new migrations already use canon form)
27. T34: completionStyle = "subcommand" sweep (cobra repos)
28. T52: hand-rolled dockerTools block sweep
29. T57: fleet `nix flake update` sweeps (pull 517db1c after push)
30. T60: consumer fleet audit re-run (auto-default + container checklist items)
31. T71: heading-mode canon (annotate.go, SKILLS repo)
32. T41: multi-arch manifest app (skopeo copy --all)
33. T42: container.fromImage (distroless base)
34. v0.1.0 tag decision for go-nix-helpers
35. Owed inline TABLE VIEW report (Pareto + M/F summary)
36. /tmp cleanup: banksync-old, templ-components-v1260/v1270, gf-anc, cqrshtmx, fod.json, dance logs
37. Standup-Killer: requestid-no-name-leak check green verify
38. Standup-Killer: TestCheckinCommand pre-existing failure — still parked (doCheck=false, tracked separately)
39. crush-daily: dependency-pins flake check (templ CLI pin parity) verify post-migration
40. bank-sync: templ-committed/freshness check status in their battery (verify present post-migration)
41. bank-sync: status report in ITS docs/status convention
42. Standup-Killer + crush-daily: status reports per their conventions
43. moduleTest count re-derive (assertion changed; docs say 218 — now 219?)
44. docs-gates battery run (go-nix-helpers) after this report
45. mkGoFlake consumer count re-check — T5 completion drops it to ZERO → plan removal release
46. Fleet-wide vendorHash drift sweep after go-nix-helpers push (input bump shifts hashes, bank-sync lesson 17)
47. Consider `nix fmt` pre-commit for foreign-repo edits (daemon swept tab-drift twice before)
48. Update `.docs-gates.json` annotate ratchet if this report adds markers (should not)
49. Skolem/`subPackages`-style silent-failure audit across other go-standard options (what else can build green-but-empty?)
50. Session-memory: record "read AGENTS gotchas first" as a standing rule in this repo's AGENTS.md

## g) Questions for the owner

1. **Push approvals**: bank-sync master was PUSHED (by the daemon/concurrent actor — not me) while mid-edit heaps landed; Standup-Killer/crush-daily/KeyHolderAI/bugtracker/SKILLS have unpushed or daemon-pushed local work. Which repos am I cleared to push, given billing-disabled CI on several?
2. **A12 canon**: bank-sync now runs templ-components v1.27.0 + cqrs-htmx v4.16.0 + go-sse v0.7.0 + go-finding-lint v1.15.1 (adr/0003 said v1.26.0). Update the canon fleet-wide, or keep per-repo escapes?
3. **subPackages default change** (["."] → [] = nixpkgs auto-discovery) is committed on go-nix-helpers master-local: ship as-is, or audit monorepo `packages` consumers first (and do you want the empty-bin hard-fail guard, item 20)?
