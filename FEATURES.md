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

| Feature                                           | Status                | Notes                                                                             |
| ------------------------------------------------- | --------------------- | --------------------------------------------------------------------------------- |
| Copy flake-input deps into `_local_deps/`         | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:193-200`                                                    |
| Inject `replace` directives into `go.mod`         | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:205-213`, `234-236`                                         |
| Recursive sub-module auto-discovery               | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:153-181`; excludes `example`/`testdata`/`vendor`/etc.       |
| Explicit `subModules` merged with auto-discovered | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:219-230`, unified pipeline at `234-236`                     |
| `/vN` major-version suffix handling               | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:111-126`; strips `/vN` from local dir, keeps in module path |
| Strip stale absolute/relative local replaces      | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:260-264`; covers `/...`, `./...`, `../...`                  |
| Pseudo-version normalization                      | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:247-251`                                                    |
| Build-time validation of private `require`        | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:269-301`; tested by `nix run .#verifyValidation`            |
| Manual `requireDeps` injection                    | 🟢 `FULLY_FUNCTIONAL` | `mkPreparedSource.nix:239-242`                                                    |

## Flake-parts module: `go-standard`

| Feature                                                                        | Status                    | Notes                                                                                    |
| ------------------------------------------------------------------------------ | ------------------------- | ---------------------------------------------------------------------------------------- |
| One-line adoption via `flakeModules.go-standard`                               | 🟢 `FULLY_FUNCTIONAL`     | `flake.nix:43-48`, `modules/go-standard.nix`                                             |
| Bundle `treefmt-nix` internally (3 inputs only)                                | 🟢 `FULLY_FUNCTIONAL`     | `flake.nix:43-48`                                                                        |
| Hardcoded default systems list                                                 | 🟡 `PARTIALLY_FUNCTIONAL` | `modules/go-standard.nix:43-48`; should use `import inputs.systems` per status report #2 |
| Generate `packages`, `apps`, `devShells`, `checks`, `overlays`                 | 🟢 `FULLY_FUNCTIONAL`     | `modules/go-standard.nix:318-385`                                                        |
| Private deps via `deps` option                                                 | 🟢 `FULLY_FUNCTIONAL`     | `modules/go-standard.nix:106-114`, `206-221`                                             |
| Auto-inject `GOPRIVATE` into devShells                                         | 🟢 `FULLY_FUNCTIONAL`     | `modules/go-standard.nix:310-316`                                                        |
| Typed options for `pname`, `vendorHash`, `src`, `subPackages`, `ldflags`, etc. | 🟢 `FULLY_FUNCTIONAL`     | `modules/go-standard.nix:51-187`                                                         |
| Real downstream consumer end-to-end test                                       | ⚪ `PLANNED`              | No real project in CI imports `flakeModules.go-standard` yet                             |

## Templates

| Feature                                             | Status                | Notes                               |
| --------------------------------------------------- | --------------------- | ----------------------------------- |
| `templates/go-standard/flake.nix` (3-input minimal) | 🟢 `FULLY_FUNCTIONAL` | Copy-paste quickstart, recommended  |
| `templates/go-flake-parts/flake.nix` (manual full)  | 🟢 `FULLY_FUNCTIONAL` | Legacy manual approach; still valid |

## Developer scripts

| Feature                                              | Status                    | Notes                                                                                                                      |
| ---------------------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `scripts/dashboard.sh` — flake-status overview       | 🟢 `FULLY_FUNCTIONAL`     | Supports `--check`, `--json`                                                                                               |
| `scripts/nix-lint.sh` — flake.nix linting            | 🟢 `FULLY_FUNCTIONAL`     | Supports `--fix`, `--check`                                                                                                |
| `scripts/generate-flake.sh` — bootstrap new projects | 🟡 `PARTIALLY_FUNCTIONAL` | Hardcoded project root; fragile `sed` for `--templ`; pushes to GitHub by default (`scripts/generate-flake.sh:28`, `76-83`) |

## Self-hosting and quality gates

| Feature                                              | Status                | Notes                                                       |
| ---------------------------------------------------- | --------------------- | ----------------------------------------------------------- |
| `flake.nix` with `nix flake check` / `nix fmt`       | 🟢 `FULLY_FUNCTIONAL` | Checks wired to `test.nix`, formatter uses nixfmt           |
| Integration test suite (`test.nix`)                  | 🟢 `FULLY_FUNCTIONAL` | `autoDiscovery`, `explicitOnly`, `verify`, `validationTest` |
| Negative-case validation runner (`verifyValidation`) | 🟢 `FULLY_FUNCTIONAL` | Run outside sandbox via `nix run .#verifyValidation`        |
| GitHub Actions CI workflow for the repo itself       | ⚪ `PLANNED`          | `docs/ci-workflow.yml` exists only as a consumer template   |

## Deprecated

| Feature                                    | Status                    | Notes                                                                                                             |
| ------------------------------------------ | ------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `mkGoFlake.nix` function-based predecessor | 🟡 `PARTIALLY_FUNCTIONAL` | Superseded by `go-standard`; still exported as `flake.lib.mkGoFlake` (`flake.nix:38`) with no deprecation warning |
