# TODO List

> Short-term, actionable, bounded work for go-nix-helpers. For long-term vision,
> see `ROADMAP.md`; for shipped changes, see `CHANGELOG.md`.
> Last docs-health harvest: 2026-09-24 (from `docs/status/2026-09-24_*` and
> `2026-09-07_*`, verified against code the same day).

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
| T9 | Test the `pkgs.go` fallback branch (`newestGoAttrName` → null → `pkgs.go`) — zero coverage today           | TODO   | 20min  | `docs/status/2026-09-24_*` b.11, f.7; PARTIALLY DONE 2026-09-24 via `goBaseFrom` stub tests (no-branch → `pkgs.go` asserted; `mkGoFlake` eval smoke still open) |
| T10 | Any eval smoke check for `mkGoFlake.nix` (zero coverage; contains new auto-default logic)                 | TODO   | 30min  | `docs/status/2026-09-24_*` b.2, f.8                                                                             |
| T11 | Harden the templ-committed negative test to assert the throw MESSAGE (intended-throw vs accidental-eval-error) | TODO   | 30min  | `docs/status/2026-09-07_*` b.3, e.7                                                                            |
| T12 | Escape ERE metacharacters in `publicDeps` entries before the `grep -vE` filter (dots are wildcards)        | TODO   | 15min  | `docs/status/2026-09-07_*` c.4; `mkPreparedSource.nix` validateScript                                            |
| T13 | `goExperiment` / `cgoEnabled` / `completionStyle` options (7/10 Tier A repos repeat GOEXPERIMENT boilerplate; cobra completions need subcommand style) | TODO | 2h | `docs/status/2026-08-10_16-50_*` E.9–E.11, F.10–F.12                                             |
| T14 | `proxyVendor` trace warning when deps force it to `false` (silent behavior change on migration)            | TODO   | 15min  | `docs/status/2026-08-10_16-50_*` E.8, F.14                                                                      |
| T15 | Integrate `templ generate` into `modBuildPhase` when `enableTempl = true` (standard-bug-tracking-schema needed a manual override) | TODO | 30min | `docs/status/2026-08-10_16-50_*` E.10, F.15                                                                     |
| T16 | Eval-time go.mod floor check: warn/throw when the resolved toolchain is below the consumer's `go.mod` floor | TODO   | 2h     | `docs/status/2026-09-24_*` e.5; ROADMAP Theme 6                                                                 |
| T17 | Trash `result`, `result-1..3`, `result-auto`, `result-verify`, `result-vv` symlinks; gitignore `result*`   | TODO   | 5min   | Verified 2026-09-24: 7 symlinks in repo root (untracked)                                                        |

## Low impact / Polish

| #  | Task                                                                                                              | Status | Effort | Evidence                                              |
| -- | ----------------------------------------------------------------------------------------------------------------- | ------ | ------ | ----------------------------------------------------- |
| T18 | Document the `-mindepth 3` root-skip assumption in `autoDiscoverScript` (comment or named variable)              | TODO   | 10min  | `docs/status/2026-08-12_11-01_*` e.1, f.2             |
| T19 | Fix the "ALL go.mod at any depth" comment vs `find -mindepth 3` mismatch in `autoDiscoverScript`                  | TODO   | 5min   | `docs/status/2026-09-07_*` c.6                        |
| T20 | Quote/validate `excludeSubModuleDirs` custom values spliced into the `case` glob (metachars break it)             | TODO   | 15min  | `docs/status/2026-09-07_*` c.5                        |
| T21 | `verifyValidation`: also assert the error TEXT names the missing module (generic-message match only today)        | TODO   | 15min  | `docs/status/2026-09-07_*` f.40                       |
| T22 | Silence or properly set `__intentionallyOverridingVersion` in the goPkgOverride test (warning noise per check log) | TODO   | 10min  | `docs/status/2026-09-24_*` f.14                       |
| T23 | Generalize `nix-lint.sh` `go_1_26-outline` message pattern to `go_1_XX-outline`                                  | TODO   | 10min  | `docs/status/2026-09-24_*` f.15                       |
| T24 | Old-nixpkgs pinned CI matrix job for moduleTest (proves auto-default + fallback degrade gracefully)              | TODO   | 1h     | `docs/status/2026-09-24_*` e.4, f.11                  |
| T25 | Derive `dashboard.sh` `GO_LATEST` from nixpkgs instead of a manual-bump default (this exact default rotted twice before; the 2026-09-24 fix only made the default auto-derivable) | TODO | 30min | `docs/status/2026-09-24_*` f.16; `scripts/dashboard.sh` |
| T26 | Normalize `1.~~` → `1. ~~` list-marker spacing across all annotated reports (markdown ordered-list rendering is broken on struck items) | TODO | 15min | `docs/status/2026-09-24_18-06_*` b.2 — inherited from the skill tooling format |
| T27 | Render-verify the 5 largest struck tables (16-50, 22-45, 02-51, 21-31, 23-04) in a markdown preview | TODO | 20min | `docs/status/2026-09-24_18-06_*` b.1 — markers-inside-cells never visually checked |
| T28 | Groff-validate both man pages (`MANWIDTH=80 man --local-file`) after the goTarball additions | TODO | 5min | `docs/status/2026-09-24_18-06_*` b.3 — `.BR` entries added without running man |
| T29 | Add in-file exemption notes to archived 07-38 §B and 06-51 "What went well" (why items stay bare) | TODO | 10min | `docs/status/2026-09-24_18-06_*` c.3 — future gates will re-flag them |
| T30 | Wire `check-rows.py` + archived grep-gate into a flake check (vendor the scripts into `scripts/`) so annotation uniformity is CI-enforced | TODO | 1h | `docs/status/2026-09-24_18-06_*` f.5 — would have caught the case-bug at pass one |
| T31 | Write the correction note for `0817f80`'s wrong mechanism story (docs/, never rewrite others' commits) | TODO | 15min | `docs/status/2026-09-07_*` b.6 |
| T32 | Write the lock-bump postmortem (lock bump → eval break → consumer-visible failure; "input bumps are eval changes") | TODO | 30min | `docs/status/2026-09-07_*` f.50 |

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
