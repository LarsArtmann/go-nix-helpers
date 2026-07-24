# TODO List

> Short-term, actionable, bounded work for go-nix-helpers. For long-term vision,
> see `ROADMAP.md`; for shipped changes, see `CHANGELOG.md`.

## Status legend

| Status           | Meaning                                                     |
| ---------------- | ----------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                                   |
| 🟡 `IN_PROGRESS` | Actively being worked on.                                   |
| 🔵 `BLOCKED`     | Cannot proceed, external dependency or decision needed.     |
| 🟢 `DONE`        | Completed. Remove from this list and log in `CHANGELOG.md`. |

## High impact

| Task                                                                  | Status    | Impact | Effort | Evidence                                                            |
| --------------------------------------------------------------------- | --------- | ------ | ------ | ------------------------------------------------------------------- |
| Fix `defaultSystems` hardcoding in `go-standard`                      | 🔴 `TODO` | High   | 15min  | `modules/go-standard.nix:43-48`; should use `import inputs.systems` |
| Remove committed `test-result` symlink from git                       | 🔴 `TODO` | High   | 5min   | `git ls-files test-result` shows it is tracked                      |
| Create a real downstream consumer end-to-end test for `go-standard`   | 🔴 `TODO` | High   | 2h     | No project in CI imports `flakeModules.go-standard` yet               |
| Delete or formally deprecate `mkGoFlake.nix`                          | 🔴 `TODO` | High   | 30min  | `flake.nix:38` still exports `flake.lib.mkGoFlake`                  |
| Mark `templates/go-flake-parts/` as legacy or delete it               | 🔴 `TODO` | High   | 30min  | Template still shows 5-input manual pattern without legacy note      |
| Add `LICENSE` file (MIT) and license badge                            | 🔴 `TODO` | High   | 5min   | No `LICENSE` file in repo root                                      |
| Set up GitHub Actions CI for `nix flake check` on push/PR             | 🔴 `TODO` | High   | 30min  | `docs/ci-workflow.yml` exists only as a consumer template              |
| Replace static "nix flake check" badge in README with dynamic CI badge | 🔴 `TODO` | High   | 5min   | `README.md:3` uses static shields.io badge                           |
| Add `CONTRIBUTING.md`                                                 | 🔴 `TODO` | High   | 30min  | No contributor guide exists                                          |
| Add `.github` issue templates, PR template, and workflows             | 🔴 `TODO` | High   | 1h     | No `.github/` directory exists                                       |
| Add unit/integration tests for `go-standard` module outputs           | 🔴 `TODO` | High   | 2h     | `test.nix` only tests `mkPreparedSource`; module itself untested     |
| Write migration guide from `mkGoFlake.nix` to `go-standard`             | 🔴 `TODO` | High   | 1h     | `mkGoFlake.nix` is deprecated but no migration doc exists            |

## Medium impact

| Task                                                                  | Status    | Impact | Effort | Evidence                                                            |
| --------------------------------------------------------------------- | --------- | ------ | ------ | ------------------------------------------------------------------- |
| Make `scripts/generate-flake.sh` configurable and non-interactive     | 🔴 `TODO` | Med    | 30min  | `scripts/generate-flake.sh:28`, `76-83` hardcode path and push by default |
| Add `enableCheck` option to `go-standard`                             | 🔴 `TODO` | Med    | 30min  | Module always runs `doCheck = true` in `buildGoModule`               |
| Add `enableOverlay` option to `go-standard`                           | 🔴 `TODO` | Med    | 30min  | `flake.overlays.default` always generated (`modules/go-standard.nix:383-385`) |
| Add `version` option to override git-derived version                   | 🔴 `TODO` | Med    | 30min  | `modules/go-standard.nix:200` derives from `self.rev or self.dirtyRev` |
| Support multiple packages in `go-standard` (monorepo binaries)         | 🔴 `TODO` | Med    | 4h     | Currently one `buildGoModule` per consumer                             |
| Audit all downstream consumers for manual `_local_deps/` workarounds    | 🔴 `TODO` | Med    | 2h     | Status reports identified ~5 genuinely necessary cases               |
| Add architecture diagram to README                                    | 🔴 `TODO` | Med    | 45min  | README lacks visual overview of module flow                          |
| Add troubleshooting/FAQ section to README                             | 🔴 `TODO` | Med    | 45min  | Private-dep failures are common; no FAQ exists                       |
| Add real private-repo integration test in CI                          | 🔴 `TODO` | Med    | 2h     | Current tests use mocked deps only (`test.nix:19-59`)                |
| Add `buildFlags` option to `go-standard` for build tags               | 🔴 `TODO` | Med    | 30min  | `templates/go-flake-parts/flake.nix:64-65` has build tags; module does not |

## Low impact

| Task                                                                  | Status    | Impact | Effort | Evidence                                                            |
| --------------------------------------------------------------------- | --------- | ------ | ------ | ------------------------------------------------------------------- |
| Add `enableGolangciLint` toggle to `go-standard`                      | 🔴 `TODO` | Low    | 30min  | Linter is always included in devShell/apps (`modules/go-standard.nix:329-333`) |
| Add `enableGofumpt` / `enableGoimports` toggles in treefmt            | 🔴 `TODO` | Low    | 30min  | Treefmt always enables both (`modules/go-standard.nix:374-378`)     |
| Add `nix run .#fmt` alias app                                         | 🔴 `TODO` | Low    | 15min  | Consumers must run `nix fmt` at top level; app alias is convenience  |
| Register `maintainers.larsartmann` in nixpkgs                         | 🔴 `TODO` | Low    | 30min  | `AGENTS.md:86` notes the handle is unregistered                       |
| Add shell completions for generated apps                                | 🔴 `TODO` | Low    | 1h     | No completions provided                                               |
| Add man pages for `mkPreparedSource` and `go-standard` options        | 🔴 `TODO` | Low    | 2h     | No man pages exist                                                    |
