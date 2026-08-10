# TODO List

> Short-term, actionable, bounded work for go-nix-helpers. For long-term vision,
> see `ROADMAP.md`; for shipped changes, see `CHANGELOG.md`.

## Status legend

| Status      | Meaning                                                 |
| ----------- | ------------------------------------------------------- |
| TODO        | Not started. Needs doing.                               |
| IN_PROGRESS | Actively being worked on.                               |
| BLOCKED     | Cannot proceed, external dependency or decision needed. |

## High impact

| #  | Task                                                                                  | Status | Effort | Evidence                                                              |
| -- | ------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| ~~H1~~ | ~~Implement G2: per-package `extraBuildAttrs` in monorepo `packages` submodule~~ | ~~DONE~~ | ~~1h~~ | **Shipped** `2f3b6b2`. 4 test assertions. |
| ~~H2~~ | ~~Migrate Tier A consumer repos to go-standard~~                                      | ~~DONE~~ | ~~5h~~ | **Shipped**: all 10 Tier A repos migrated (go-localsync, erraudit, project-meta, oxlint-auto-configure, project-dependency-graph, golangci-lint-auto-configure, go-humanize-linter, projects-management-automation, standard-bug-tracking-schema, go-auto-upgrade). All eval-verified. |
| ~~H3~~ | ~~Add template-output CI check (eval freshly generated project)~~                     | ~~DONE~~ | ~~30min~~ | **Shipped** `2f3b6b2`. 9th flake check. |

## Medium impact

| #  | Task                                                                                  | Status | Effort | Evidence                                                              |
| -- | ------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| ~~M1~~ | ~~Add `enableTestCheck` option~~                                                      | ~~DONE~~ | ~~30min~~ | **Shipped** `2f3b6b2`. Module option 38→38 (now 39 with requireDeps). |
| M2 | Migrate Tier B consumer repos (6 repos, modest complexity)                            | TODO   | 3h     | Fleet audit: KeyCountdown, StopTube, branching-flow, bank-sync, overview, BuildFlow. Some need G2 (H1 — done). |
| ~~M3~~ | ~~Clean up 5 existing module adopters~~                                               | ~~DONE~~ | ~~1h~~ | **Shipped**: 4/5 cleaned (lean-business-plan, storbi, template-arch-lint, terraform-diagrams-aggregator). index already clean. |
| M4 | Migrate Tier C consumer repos off deprecated `mkGoFlake` (Standup-Killer, crush-daily) | TODO   | 2h     | Only 2 repos still on deprecated path. Need G2 for subModules support. |
| -- | _(All medium-impact items from the Pareto plan M1–M10 are shipped — see CHANGELOG)_   | —      | —      | —                                                                     |

## Low impact / Polish

| #  | Task                                                                                  | Status | Effort | Evidence                                                              |
| -- | ------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| -- | _(L1–L9 shipped — see CHANGELOG. L10 **empirically rejected**: prototyped extraction to `scripts/post-patch.sh`, all 8 tests passed, but the result requires 11 env var declarations, 8 `eval` calls, and splits logic across 2 files — a Verschlimmbesserung. The inline `postPatch` is the idiomatic Nix `mkDerivation` pattern. See `docs/planning/2026-08-10_02-41_pareto-execution-plan.md` P12 for theoretical rationale)_ | — | — | — |

## Scripts and CI

| #  | Task                                                                                  | Status | Effort | Evidence                                                              |
| -- | ------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| -- | _(Shell scripts are linted via `nix run nixpkgs#shellcheck` in CI; `--dry-run` and `--verbose` have smoke-test coverage)_ | — | — | —                                                                     |

## Documentation

| #  | Task                                                                                  | Status | Effort | Evidence                                                              |
| -- | ------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| -- | _(D1 enableShfmt in migration-guide, D2 extraBuildAttrs in flake-patterns — both shipped — see CHANGELOG)_ | — | — | — |

## Blocked

| Task                                                                | Status  | Impact | Effort | Evidence                                                                       |
| ------------------------------------------------------------------- | ------- | ------ | ------ | ------------------------------------------------------------------------------ |
| Register `maintainers.larsartmann` in nixpkgs                       | BLOCKED | Low    | 30min  | Requires external PR to nixpkgs repo                                           |
| Real private-repo integration test in CI                            | BLOCKED | High   | 2h     | CI job scaffolded (`if: false`); needs SSH key secret (`DEPLOY_SSH_KEY`)       |
| ~~Audit all downstream consumers~~                                  | DONE    | Med    | 2h     | **Completed**: 34 repos audited. See `docs/status/2026-08-10_11-02_consumer-fleet-audit.md` and `docs/status/2026-08-10_14-39_fleet-audit-execution-and-module-gap-closure.md`. Gaps G1+G3 closed; G2+enableTestCheck tracked above (H1/M1). |
| Real e2e consumer test through full build pipeline                  | BLOCKED | High   | 4h     | Needs mock Go project + flake.nix importing go-standard, built via `nix build` |
| Fix empty commit message in `df9a5ff`                               | BLOCKED | Low    | 15min  | Requires interactive rebase + force-push; user approval needed                 |
