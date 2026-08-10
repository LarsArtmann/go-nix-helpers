# Features

> Honest inventory of what this project does, by status. Generated from the
> actual Nix code and tests, not from marketing claims.

## Status legend

| Status                    | Meaning                                                      |
| ------------------------- | ------------------------------------------------------------ |
| 🟢 `FULLY_FUNCTIONAL`     | Works as intended, exercised by tests or daily use.          |
| 🟡 `PARTIALLY_FUNCTIONAL` | Ships but has known gaps, edge-case bugs, or missing pieces. |
| 🔴 `BROKEN`               | Present in code but not working / disabled / failing.        |
| ⚪ `PLANNED`              | Designed or documented but **not yet implemented** in code.  |

## Core: private Go dependency injection

| Feature                                           | Status                | Notes                                                                                                                          |
| ------------------------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Copy flake-input deps into `_local_deps/`         | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:193-200`                                                                                                 |
| Inject `replace` directives into `go.mod`         | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:205-213`, `234-236`                                                                                      |
| Recursive sub-module auto-discovery               | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:153-181`; excludes `example`/`testdata`/`vendor`/etc.                                                    |
| Explicit `subModules` merged with auto-discovered | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:219-230`, unified pipeline at `234-236`                                                                  |
| `/vN` major-version suffix handling               | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:111-126`; strips `/vN` from local dir, keeps in module path                                              |
| Strip stale absolute/relative local replaces      | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:260-264`; covers `/...`, `./...`, `../...`                                                               |
| Pseudo-version normalization                      | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:247-251`                                                                                                 |
| Build-time validation of private `require`        | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:269-301`; tested by `nix run .#verifyValidation`; `publicDeps` exclusion list available for public repos |
| `publicDeps` exclusion list                       | 🟢 `FULLY_FUNCTIONAL` | List of module paths excluded from private validation; forwarded through go-standard and mkGoFlake                             |
| Manual `requireDeps` injection                    | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:239-242`                                                                                                 |

## Flake-parts module: `go-standard`

| Feature                                                        | Status                    | Notes                                                                                     |
| -------------------------------------------------------------- | ------------------------- | ----------------------------------------------------------------------------------------- |
| One-line adoption via `flakeModules.go-standard`               | 🟢 `FULLY_FUNCTIONAL`     | `flake.nix:43-48`, `modules/go-standard.nix`                                              |
| Bundle `treefmt-nix` internally (3 inputs only)                | 🟢 `FULLY_FUNCTIONAL`     | `flake.nix:43-48`                                                                         |
| Configurable `systems` option (no longer hardcoded)            | 🟢 `FULLY_FUNCTIONAL`     | `go-standard.systems` option; defaults to `nix-systems/default`                           |
| Generate `packages`, `apps`, `devShells`, `checks`, `overlays` | 🟢 `FULLY_FUNCTIONAL`     | `modules/go-standard.nix` perSystem config                                                |
| Private deps via `deps` option                                 | 🟢 `FULLY_FUNCTIONAL`     | `modules/go-standard.nix` deps option                                                     |
| Auto-inject `GOPRIVATE` into devShells                         | 🟢 `FULLY_FUNCTIONAL`     | `modules/go-standard.nix` autoGoPrivate                                                   |
| Typed options for all config                                   | 🟢 `FULLY_FUNCTIONAL`     | `modules/go-standard.nix` options block                                                   |
| `enableCheck` option (control doCheck)                         | 🟢 `FULLY_FUNCTIONAL`     | Defaults to `true`                                                                        |
| `enableOverlay` option (toggle overlay generation)             | 🟢 `FULLY_FUNCTIONAL`     | Defaults to `true`; tested by `moduleTestNoOverlay`                                       |
| `buildFlags` option (Go build tags)                            | 🟢 `FULLY_FUNCTIONAL`     | Passed to `buildGoModule.buildFlags`                                                      |
| `version` option (override git-derived version)                | 🟢 `FULLY_FUNCTIONAL`     | Defaults to `self.rev or self.dirtyRev or "dev"`                                          |
| `enableGolangciLint` toggle                                    | 🟢 `FULLY_FUNCTIONAL`     | Conditionally includes golangci-lint in devShells and lint app                            |
| `enableGofumpt` / `enableGoimports` toggles                    | 🟢 `FULLY_FUNCTIONAL`     | Conditionally enabled in treefmt programs                                                 |
| `enableCompletions` option                                     | 🟡 `PARTIALLY_FUNCTIONAL` | Requires cobra/urfave/cli; emits a build-time warning with remediation options if binary doesn't support `--completion`. Check uses `timeout 10` to prevent hanging |
| Monorepo support (`packages` option)                           | 🟢 `FULLY_FUNCTIONAL`     | Multiple `buildGoModule` per repo; separate apps/overlays per package                     |
| `fmt` app (`nix run .#fmt`)                                    | 🟢 `FULLY_FUNCTIONAL`     | Wrapper around treefmt                                                                    |
| Module-level tests (options, types, outputs)                   | 🟡 `PARTIALLY_FUNCTIONAL` | `test-module.nix` with 74 assertions; includes behavioral tests for nativeBuildInputs concatenation; eval-only for other attrs (see TODO_LIST) |
| Real downstream consumer end-to-end test                       | ⚪ `PLANNED`              | Requires a real private-repo CI test job with SSH key secret                              |

## Templates

| Feature                                             | Status                    | Notes                                                           |
| --------------------------------------------------- | ------------------------- | --------------------------------------------------------------- |
| `templates/go-standard/flake.nix` (3-input minimal) | 🟢 `FULLY_FUNCTIONAL`     | Copy-paste quickstart, recommended                              |
| `templates/go-flake-parts/flake.nix` (manual full)  | 🟡 `PARTIALLY_FUNCTIONAL` | ⚠️ **Deprecated.** Marked with banner; migrate to `go-standard` |

## Developer scripts

| Feature                                              | Status                | Notes                                                                                   |
| ---------------------------------------------------- | --------------------- | --------------------------------------------------------------------------------------- |
| `scripts/dashboard.sh` — flake-status overview       | 🟢 `FULLY_FUNCTIONAL` | Supports `--check`, `--json`                                                            |
| `scripts/nix-lint.sh` — flake.nix linting            | 🟢 `FULLY_FUNCTIONAL` | Supports `--fix`, `--check`                                                             |
| `scripts/generate-flake.sh` — bootstrap new projects | 🟢 `FULLY_FUNCTIONAL` | Configurable: `--dir`, `--template`, `--no-push` (default), `--templ`, `--private-deps` |

## Self-hosting and quality gates

| Feature                                              | Status                    | Notes                                                                                                                           |
| ---------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `flake.nix` with `nix flake check` / `nix fmt`       | 🟢 `FULLY_FUNCTIONAL`     | Checks wired to `test.nix`, `test-module.nix`, formatter uses nixfmt                                                            |
| Integration test suite (`test.nix`)                  | 🟢 `FULLY_FUNCTIONAL`     | 6 scenarios: auto-discovery, explicit-only, validation, publicDeps exclusion, requireDeps dedup, multi-deps monorepo |
| Module test suite (`test-module.nix`)                | 🟡 `PARTIALLY_FUNCTIONAL` | 74 assertions; options, types, defaults, perSystem outputs, overlay, behavioral nativeBuildInputs test; remaining attrs eval-only |
| Negative-case validation runner (`verifyValidation`) | 🟢 `FULLY_FUNCTIONAL`     | Run outside sandbox via `nix run .#verifyValidation`                                                                            |
| GitHub Actions CI workflow for the repo itself       | 🟢 `FULLY_FUNCTIONAL`     | `.github/workflows/ci.yml` with format check, integration + module tests                                                        |
| Private-repo CI test job                             | 🟡 `PARTIALLY_FUNCTIONAL` | Scaffolded in CI workflow; disabled until SSH key secret is configured                                                          |

## Documentation & Community

| Feature                            | Status                | Notes                                                            |
| ---------------------------------- | --------------------- | ---------------------------------------------------------------- |
| `LICENSE` file (MIT)               | 🟢 `FULLY_FUNCTIONAL` | Added MIT license with copyright Lars Artmann                    |
| `CONTRIBUTING.md`                  | 🟢 `FULLY_FUNCTIONAL` | Dev setup, testing, code style, PR checklist                     |
| `docs/migration-guide.md`          | 🟢 `FULLY_FUNCTIONAL` | mkGoFlake, go-flake-parts, manual mkPreparedSource → go-standard |
| Architecture diagram               | 🟢 `FULLY_FUNCTIONAL` | `docs/architecture.svg` rendered from D2                         |
| README FAQ / Troubleshooting       | 🟢 `FULLY_FUNCTIONAL` | SSH errors, vendorHash, GOPRIVATE, validation errors             |
| `.github/ISSUE_TEMPLATE/`          | 🟢 `FULLY_FUNCTIONAL` | Bug report + feature request templates                           |
| `.github/PULL_REQUEST_TEMPLATE.md` | 🟢 `FULLY_FUNCTIONAL` | PR checklist with testing, formatting, docs sections             |
| `.github/CODEOWNERS`               | 🟢 `FULLY_FUNCTIONAL` | Auto-assign @LarsArtmann for review                              |
| Man pages                          | 🟢 `FULLY_FUNCTIONAL` | `docs/man/go-standard.5`, `docs/man/mkPreparedSource.5`          |

## Deprecated

| Feature                                     | Status                    | Notes                                                                 |
| ------------------------------------------- | ------------------------- | --------------------------------------------------------------------- |
| `mkGoFlake.nix` function-based predecessor  | 🟡 `PARTIALLY_FUNCTIONAL` | Emits `builtins.trace` deprecation warning; migration guide available |
| `templates/go-flake-parts/` manual template | 🟡 `PARTIALLY_FUNCTIONAL` | Marked deprecated with banner in README and flake.nix header          |
