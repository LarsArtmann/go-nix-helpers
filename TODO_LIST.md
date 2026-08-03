# TODO List

> Short-term, actionable, bounded work for go-nix-helpers. For long-term vision,
> see `ROADMAP.md`; for shipped changes, see `CHANGELOG.md`.

## Status legend

| Status           | Meaning                                                     |
| ---------------- | ----------------------------------------------------------- |
| TODO             | Not started. Needs doing.                                   |
| IN_PROGRESS      | Actively being worked on.                                   |
| BLOCKED          | Cannot proceed, external dependency or decision needed.     |

## High impact

| Task                                                                                                            | Status  | Impact | Effort | Evidence                                                                              |
| --------------------------------------------------------------------------------------------------------------- | ------- | ------ | ------ | ------------------------------------------------------------------------------------- |
| Deepen module tests from eval-only to behavioral — verify `buildFlags`, `ldflags`, `nativeBuildInputs` actually reach `buildGoModule` | TODO    | High   | 3h     | `test-module.nix` — current 57 assertions check evaluation succeeds but not attribute values |
| Improve `enableCompletions` UX — fail loudly or warn when binary doesn't support `--completion` instead of silent no-op | TODO    | High   | 1h     | `modules/go-standard.nix` — `\|\| true` in `installShellCompletion` silently swallows failures |

## Medium impact

| Task                                                                                                                                   | Status  | Impact | Effort | Evidence                                                                        |
| -------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------ | ------ | ------------------------------------------------------------------------------- |
| Add `generate-flake.sh` smoke test to CI — run script, verify output is valid Nix, `nix flake check` passes                           | TODO    | Med    | 1h     | `.github/workflows/ci.yml` — script has had bugs (D4) CI would catch            |
| Add `userExtraBuildAttrs` merge protection — extend list attrs (e.g. `nativeBuildInputs`) instead of raw override                     | TODO    | Med    | 30min  | `modules/go-standard.nix` — consumer setting `extraBuildAttrs.nativeBuildInputs` would OVERRIDE module's list |
| Add FAQ entry for `vendorHash = null` (committed `vendor/`)                                                                            | TODO    | Med    | 15min  | `README.md` FAQ only covers hash mismatch                                       |
| Add FAQ entry for monorepo `vendorHash` sharing                                                                                        | TODO    | Med    | 15min  | `README.md` — multiple packages share one vendorHash, undocumented              |
| Document `enableCompletions` cobra/urfave/cli requirement in README options table                                                      | TODO    | Med    | 10min  | `README.md` — options table says "Install shell completions" without caveat     |
| Document `extraApps`/`extraChecks`/`extraFlake` removal in migration guide                                                              | TODO    | Med    | 20min  | `docs/migration-guide.md` — mkGoFlake had these, go-standard doesn't; no migration path documented |
| Namespace `repoName` by owner to prevent same-name different-owner collision                                                            | TODO    | Med    | 30min  | `mkPreparedSource.nix:repoName` — two forks with the same repo name would collide |
| Make `apps.fmt` conditional on at least one treefmt program enabled                                                                    | TODO    | Med    | 15min  | `modules/go-standard.nix` — `apps.fmt` always generated even if all programs disabled |
| Add macOS CI runner (`runs-on: macos-latest`)                                                                                          | TODO    | Med    | 30min  | `.github/workflows/ci.yml` — only `ubuntu-latest`                               |
| Add `flake.lock` freshness check to CI                                                                                                | TODO    | Med    | 30min  | `.github/workflows/ci.yml` — no `nix flake update --check` equivalent           |
| Dedup `requireDeps` against existing `require` lines in `go.mod`                                                                       | TODO    | Med    | 30min  | `mkPreparedSource.nix` — can emit duplicate require lines                       |

## Low impact

| Task                                                                                                                                 | Status  | Impact | Effort | Evidence                                                            |
| ------------------------------------------------------------------------------------------------------------------------------------ | ------- | ------ | ------ | ------------------------------------------------------------------- |
| Add remaining module option tests — `proxyVendor`, `ldflags` custom, `devShellExtraPackages`, `shellExtraEnv`/`autoGoPrivate`, `enableTempl`, `enableGopls`/`enableGovulncheck`, `systems` override | TODO    | Low    | 2h     | `test-module.nix` — 6 options untested                              |
| Add `generate-flake.sh` option to create `go.mod` skeleton                                                                            | TODO    | Low    | 15min  | `scripts/generate-flake.sh` — generates only `flake.nix`            |
| Add `generate-flake.sh` `--private-deps` support for go-standard template                                                              | TODO    | Low    | 20min  | `scripts/generate-flake.sh` — only handles `--private-deps` for `go-flake-parts` |
| Document `GOTOOLCHAIN = "local"` behavior and override in README                                                                      | TODO    | Low    | 10min  | `AGENTS.md` documents it; README does not                            |

## Blocked

| Task                                                                   | Status  | Impact | Effort | Evidence                                                                        |
| ---------------------------------------------------------------------- | ------- | ------ | ------ | ------------------------------------------------------------------------------- |
| Register `maintainers.larsartmann` in nixpkgs                          | BLOCKED | Low    | 30min  | Requires external PR to nixpkgs repo                                            |
| Real private-repo integration test in CI                               | BLOCKED | High   | 2h     | CI job scaffolded (`if: false`); needs SSH key secret (`DEPLOY_SSH_KEY`)       |
| Audit all downstream consumers for migration status and workarounds    | BLOCKED | Med    | 2h     | Requires access to 7+ downstream repos (BuildFlow, mr-sync, PMA, etc.)         |
| Real e2e consumer test through full build pipeline                     | BLOCKED | High   | 4h     | Needs mock Go project + flake.nix importing go-standard, built via `nix build` |
