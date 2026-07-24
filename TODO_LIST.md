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

| Task                                                                   | Status       | Impact | Effort | Evidence                                                            |
| ---------------------------------------------------------------------- | ------------ | ------ | ------ | ------------------------------------------------------------------- |
| Fix `defaultSystems` hardcoding in `go-standard`                       | 🟢 `DONE`    | High   | 15min  | `go-standard.systems` option added; `cfg.systems` used in config    |
| Create a real downstream consumer end-to-end test for `go-standard`    | 🔵 `BLOCKED` | High   | 2h     | Requires SSH key secret in CI; private-deps CI job scaffolded       |
| Delete or formally deprecate `mkGoFlake.nix`                           | 🟢 `DONE`    | High   | 30min  | `builtins.trace` deprecation warning added; migration guide written |
| Mark `templates/go-flake-parts/` as legacy or delete it                | 🟢 `DONE`    | High   | 30min  | Banner in README, deprecation comment in flake.nix header           |
| Add `LICENSE` file (MIT) and license badge                             | 🟢 `DONE`    | High   | 5min   | `LICENSE` file + MIT badge in README                                |
| Set up GitHub Actions CI for `nix flake check` on push/PR              | 🟢 `DONE`    | High   | 30min  | `.github/workflows/ci.yml` with format, tests, module checks        |
| Replace static "nix flake check" badge in README with dynamic CI badge | 🟢 `DONE`    | High   | 5min   | Dynamic GitHub Actions CI badge in README                           |
| Add `CONTRIBUTING.md`                                                  | 🟢 `DONE`    | High   | 30min  | `CONTRIBUTING.md` with dev setup, testing, style guide              |
| Add `.github` issue templates, PR template, and workflows              | 🟢 `DONE`    | High   | 1h     | Bug report, feature request, PR template, CODEOWNERS                |
| Add unit/integration tests for `go-standard` module outputs            | 🟢 `DONE`    | High   | 2h     | `test-module.nix` with 40+ assertions as flake checks               |
| Write migration guide from `mkGoFlake.nix` to `go-standard`            | 🟢 `DONE`    | High   | 1h     | `docs/migration-guide.md` with parameter mapping                    |

## Medium impact

| Task                                                                 | Status       | Impact | Effort | Evidence                                                           |
| -------------------------------------------------------------------- | ------------ | ------ | ------ | ------------------------------------------------------------------ |
| Make `scripts/generate-flake.sh` configurable and non-interactive    | 🟢 `DONE`    | Med    | 30min  | `--dir`, `--template`, `--no-push` (default), `--help` flags added |
| Add `enableCheck` option to `go-standard`                            | 🟢 `DONE`    | Med    | 30min  | Controls `doCheck` in `buildGoModule`; default `true`              |
| Add `enableOverlay` option to `go-standard`                          | 🟢 `DONE`    | Med    | 30min  | `lib.mkIf` conditional overlay; tested by `moduleTestNoOverlay`    |
| Add `version` option to override git-derived version                 | 🟢 `DONE`    | Med    | 30min  | `go-standard.version` option; defaults to `self.rev or "dev"`      |
| Support multiple packages in `go-standard` (monorepo binaries)       | 🟢 `DONE`    | Med    | 4h     | `packages` option generates separate buildGoModule per binary      |
| Audit all downstream consumers for manual `_local_deps/` workarounds | 🔴 `TODO`    | Med    | 2h     | Requires access to all downstream repos                            |
| Add architecture diagram to README                                   | 🟢 `DONE`    | Med    | 45min  | `docs/architecture.svg` rendered from D2, inlined in README        |
| Add troubleshooting/FAQ section to README                            | 🟢 `DONE`    | Med    | 45min  | SSH errors, vendorHash, GOPRIVATE, validation errors documented    |
| Add real private-repo integration test in CI                         | 🔵 `BLOCKED` | Med    | 2h     | CI job scaffolded (`if: false`); needs SSH key secret              |
| Add `buildFlags` option to `go-standard` for build tags              | 🟢 `DONE`    | Med    | 30min  | `go-standard.buildFlags` passed to `buildGoModule`                 |

## Low impact

| Task                                                           | Status    | Impact | Effort | Evidence                                                       |
| -------------------------------------------------------------- | --------- | ------ | ------ | -------------------------------------------------------------- |
| Add `enableGolangciLint` toggle to `go-standard`               | 🟢 `DONE` | Low    | 30min  | Conditionally includes golangci-lint in devShells and lint app |
| Add `enableGofumpt` / `enableGoimports` toggles in treefmt     | 🟢 `DONE` | Low    | 30min  | Both conditionally enabled in treefmt programs                 |
| Add `nix run .#fmt` alias app                                  | 🟢 `DONE` | Low    | 15min  | `apps.fmt` wraps treefmt                                       |
| Register `maintainers.larsartmann` in nixpkgs                  | 🔴 `TODO` | Low    | 30min  | Requires nixpkgs PR submission; external dependency            |
| Add shell completions for generated apps                       | 🟢 `DONE` | Low    | 1h     | `enableCompletions` option installs bash/zsh/fish completions  |
| Add man pages for `mkPreparedSource` and `go-standard` options | 🟢 `DONE` | Low    | 2h     | `docs/man/go-standard.5`, `docs/man/mkPreparedSource.5`        |
