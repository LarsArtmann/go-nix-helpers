# TODO List

> Short-term, actionable, bounded work for go-nix-helpers. For long-term vision,
> see `ROADMAP.md`; for shipped changes, see `CHANGELOG.md`.
> Last docs-health harvest: 2026-09-25 (22 rows removed — shipped in the
> 2026-09-24/25 D/E/F sessions and recorded in CHANGELOG.md).

## Status legend

| Status      | Meaning                                                 |
| ----------- | ------------------------------------------------------- |
| TODO        | Not started. Needs doing.                               |
| IN_PROGRESS | Actively being worked on.                                |
| BLOCKED     | Cannot proceed, external dependency or decision needed. |

## High impact

| #  | Task                                                                                                      | Status | Effort | Evidence                                                                                                                                                     |
| -- | --------------------------------------------------------------------------------------------------------- | ------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| T3 | Build-verify the 10 eval-only Tier A migrations (`nix build`, update vendorHash where the proxyVendor flip bites) | TODO   | 3h     | `docs/status/2026-08-10_16-50_*` C ("It evaluates" ≠ "it builds"); 3/10 done 2026-09-24 (erraudit, PMA, go-auto-upgrade — eval+build green, vendorHash intact) |
| T4 | Migrate Tier B consumers to go-standard (KeyCountdown, StopTube, branching-flow, bank-sync, overview, BuildFlow) — G2 unblocks all | TODO   | 4h     | `docs/status/2026-08-10_11-02_*` Tier B table; G2 shipped `2f3b6b2`                                                                                          |
| T5 | Migrate Tier C consumers off deprecated `mkGoFlake` (Standup-Killer, crush-daily)                          | TODO   | 2h     | `mkGoFlake.nix` deprecation trace; only 2 repos remain on the deprecated path                                                                                 |

## Medium impact

| #  | Task                                                                                                       | Status | Effort | Evidence                                                                                                        |
| -- | ---------------------------------------------------------------------------------------------------------- | ------ | ------ | ---------------------------------------------------------------------------------------------------------------- |
| T24 | Old-nixpkgs pinned CI matrix job for moduleTest (proves auto-default + fallback degrade gracefully)              | TODO   | 1h     | `docs/status/2026-09-24_*` e.4, f.11                  |
| T27 | Render-verify the 5 largest struck tables (16-50, 22-45, 02-51, 21-31, 23-04) in a markdown preview | TODO | 20min | `docs/status/2026-09-24_18-06_*` b.1 — markers-inside-cells never visually checked |
| T33 | Wire `go-standard.systems` mapping verification into `test-module.nix` (the composite mapping is verified by CI + the 2026-09-25 consumer probe, but not by a module test) | TODO | 30min | commit `105c981`+ — probe was manual; regression coverage missing |
| T34 | Sweep consumers: GOEXPERIMENT boilerplate → `goExperiment` option; cobra repos → `completionStyle = "subcommand"` (7/10 Tier A repeat it) | TODO | 2h | `docs/status/2026-08-10_16-50_*` E.9–E.11; options shipped 2026-09-24 |

## Low impact / Polish

| #  | Task                                                                                                              | Status | Effort | Evidence                                              |
| -- | ------------------------------------------------------------------------------------------------------------------ | ------ | ------ | ----------------------------------------------------- |
| T34b | Remove sbts's vestigial templ/GOEXPERIMENT extraBuildAttrs override (`standard-bug-tracking-schema/flake.nix` ~90-106) — `goExperiment` option replaces it | TODO | 15min | `docs/status/2026-09-25_04-39_*` f.8; D10 redesign |
## Decided against / rejected

| Task                                            | Reason                                                                                                                                                             |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Extract `postPatch` to a separate `.sh` (old L10) | Empirically rejected 2026-08-10: prototype passed all tests but needs 11 env vars, 8 `eval` calls, splits logic across 2 files — a Verschlimmbesserung. Inline `postPatch` is the idiomatic pattern. |

## Blocked

| Task                                          | Status  | Impact | Effort | Evidence                                                       |
| --------------------------------------------- | ------- | ------ | ------ | --------------------------------------------------------------- |
| Register `maintainers.larsartmann` in nixpkgs | BLOCKED | Low    | 30min  | Requires external PR to nixpkgs repo                           |
| Real private-repo integration test in CI      | BLOCKED | High   | 2h     | CI job scaffolded (`if: false`); needs SSH key secret (`DEPLOY_SSH_KEY`) |
| Fix empty commit message in `df9a5ff`         | BLOCKED | Low    | 15min  | Requires interactive rebase + force-push; user approval needed  |
| Cut first tagged release (v0.1.0)             | BLOCKED | Medium | 30min  | Owner decision — unlocks the `mkGoFlake` removal contract and consumer version pinning |
| Decide the Won't-implement policy (age threshold / cap / owner sign-off for "dormant — dropped") | BLOCKED | Low | 15min | Owner decision — ~120 unilateral verdicts were stamped during the 2026-09-24 annotation pass |
| T15: `templ generate` in `modBuildPhase` when `enableTempl` | BLOCKED | Low | 30min | Owner decision pending (2026-09-25 §g.3: propose won't-implement — consumers commit `*_templ.go`; build-time generation is dead weight + templ-version reproducibility risk; C8/T34b removes the motivating override instead) |
