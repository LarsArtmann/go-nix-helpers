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
| -- | _(All high-impact items from the Pareto plan H1–H5 are shipped — see CHANGELOG)_      | —      | —      | —                                                                     |

## Medium impact

| #  | Task                                                                                  | Status | Effort | Evidence                                                              |
| -- | ------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| -- | _(All medium-impact items from the Pareto plan M1–M10 are shipped — see CHANGELOG)_   | —      | —      | —                                                                     |

## Low impact / Polish

| #   | Task                                                                                  | Status | Effort | Evidence                                                              |
| ---- | ------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| L10 | Extract `postPatch` script from `mkPreparedSource` into separate `.sh` file           | TODO   | 30min  | Deliberately skipped — see `docs/planning/2026-08-10_02-41_pareto-execution-plan.md` for rationale |

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
| Audit all downstream consumers for migration status and workarounds | BLOCKED | Med    | 2h     | Requires access to 7+ downstream repos (BuildFlow, mr-sync, PMA, etc.)         |
| Real e2e consumer test through full build pipeline                  | BLOCKED | High   | 4h     | Needs mock Go project + flake.nix importing go-standard, built via `nix build` |
| Fix empty commit message in `df9a5ff`                               | BLOCKED | Low    | 15min  | Requires interactive rebase + force-push; user approval needed                 |
