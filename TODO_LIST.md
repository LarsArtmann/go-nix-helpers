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
| T1 | Smoke-eval 2–3 real consumers (erraudit, PMA, go-auto-upgrade) against the `goPkgAttr` auto default: eval + `nix build` + vendorHash intact | TODO   | 1h     | `docs/status/2026-09-24_*` f.1 — the default flip shipped with zero consumer verification ("biggest honest gap")                                              |
| T2 | Sweep consumer fleet for now-redundant `goPkgAttr = "go_1_26"` pins; remove                                | TODO   | 1h     | `docs/status/2026-09-24_*` f.2                                                                                                                               |
| T3 | Build-verify the 10 eval-only Tier A migrations (`nix build`, update vendorHash where the proxyVendor flip bites) | TODO   | 3h     | `docs/status/2026-08-10_16-50_*` C ("It evaluates" ≠ "it builds")                                                                                            |
| T4 | Migrate Tier B consumers to go-standard (KeyCountdown, StopTube, branching-flow, bank-sync, overview, BuildFlow) — G2 unblocks all | TODO   | 4h     | `docs/status/2026-08-10_11-02_*` Tier B table; G2 shipped `2f3b6b2`                                                                                          |
| T5 | Migrate Tier C consumers off deprecated `mkGoFlake` (Standup-Killer, crush-daily)                          | TODO   | 2h     | `mkGoFlake.nix` deprecation trace; only 2 repos remain on the deprecated path                                                                                 |
| T6 | Add `requireDeps` test assertion(s) — the option ships with ZERO coverage in `test-module.nix`            | TODO   | 15min  | Verified 2026-09-24: `grep requireDeps test-module.nix` → no matches; `docs/status/2026-08-10_16-50_*` E.6                                                    |
| T7 | CI guard: fail when `*_templ.go` is committed under `test-assets/mock-templ-missing-generated/` (the auto-commit daemon already re-added it once and turned moduleTest red) | TODO   | 30min  | AGENTS.md gotcha; `docs/status/2026-09-24_*` a.5, e.3                                                                       |

## Medium impact

| #  | Task                                                                                                       | Status | Effort | Evidence                                                                                                        |
| -- | ---------------------------------------------------------------------------------------------------------- | ------ | ------ | ---------------------------------------------------------------------------------------------------------------- |
| T8 | Extract shared `goBase` resolution helper into `pure-functions.nix`; use from both `modules/go-standard.nix:478` and `mkGoFlake.nix:98` (active split brain) | TODO   | 30min  | Verified 2026-09-24: ~15 near-identical lines in both files; `docs/status/2026-09-24_*` a.10                     |
| T9 | Test the `pkgs.go` fallback branch (`newestGoAttrName` → null → `pkgs.go`) — zero coverage today           | TODO   | 20min  | `docs/status/2026-09-24_*` b.11, f.7                                                                            |
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
