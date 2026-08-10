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
| H1 | Add `--go-mod` and `--private-deps` variants to CI smoke-test job                     | TODO   | 30min  | `.github/workflows/ci.yml` smoke-test job; manually verified but untested in CI |
| H2 | Add behavioral test for GOPRIVATE with custom `privateGlobPattern` (requires deps in test config) | TODO | 1h   | `test-module.nix`; option-to-output flow untested at behavioral level |
| H3 | Extend `extraBuildAttrs` merge protection to `buildInputs`, `checkInputs`, `configureFlags` | TODO | 30min | `modules/go-standard.nix` `userExtraBuildAttrs`; only `nativeBuildInputs`, `preBuild`, `postInstall` concatenate today |
| H4 | Add `shellcheck` to CI for `scripts/generate-flake.sh`                                | TODO   | 20min  | `.github/workflows/ci.yml`; shell scripts currently unlinted          |
| H5 | Add `shfmt` to treefmt programs for shell formatting                                  | TODO   | 20min  | `modules/go-standard.nix` treefmt config; no shell formatter currently |

## Medium impact

| #  | Task                                                                                  | Status | Effort | Evidence                                                              |
| -- | ------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| M1 | Add property test for `stripVersionSuffix` (idempotence, no `/vN` in output)         | TODO   | 30min  | `mkPreparedSource.nix` `stripVersionSuffix`; only example-based tests |
| M2 | Add property test for `repoName` (no `/` in output, deterministic)                    | TODO   | 30min  | `mkPreparedSource.nix` `repoName`; only example-based tests           |
| M3 | Add `vendorHash` placeholder detection (warn if still `sha256-AAA...` in consumer)     | TODO   | 30min  | No detection exists in `modules/go-standard.nix`                      |
| M4 | Add `nix flake show` test (verify all expected outputs exist)                         | TODO   | 30min  | No structural output test in `test-module.nix`                        |
| M5 | Update `docs/architecture.d2` to reflect `privateGlobPattern` and `enableNixfmt`     | TODO   | 20min  | `docs/architecture.d2`; neither option appears in diagram             |
| M6 | Add `--dry-run` flag to `generate-flake.sh` (preview without writing)                 | TODO   | 20min  | `scripts/generate-flake.sh`; no preview mode                          |
| M7 | Deepen behavioral tests — extract actual `buildGoModule` attr values (`buildFlags`, `ldflags`, `proxyVendor`) and assert on them | TODO | 1h | `test-module.nix`; meta propagation tested but build flags are eval-only |
| M8 | Add negative test for `enableCompletions` warning (mock binary without `--completion`) | TODO   | 30min  | `modules/go-standard.nix` completion check; no negative test           |
| M9 | Add test for `publicDeps` with `/v2` versioned module paths (exact-match `grep -vFx` limitation) | TODO | 20min | `mkPreparedSource.nix` `publicDeps`; uses exact match, versioned paths may not match |
| M10 | Add `treefmt.config` inspection test — verify enabled programs produce correct treefmt config | TODO | 30min | `test-module.nix`; treefmt config not inspected in tests             |

## Low impact / Polish

| #  | Task                                                                                  | Status | Effort | Evidence                                                              |
| -- | ------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| L1 | Add `--verbose` flag to `generate-flake.sh` (show created files)                      | TODO   | 15min  | `scripts/generate-flake.sh`                           |
| L2 | Add macOS CI badge to README                                                          | TODO   | 10min  | `README.md`; badges section                           |
| L3 | Add `--template` listing to `generate-flake.sh` help text                             | TODO   | 10min  | `scripts/generate-flake.sh` help output               |
| L4 | Add FAQ entry for `deps` with mixed owners (non-LarsArtmann private repos)            | TODO   | 15min  | `README.md` FAQ; only LarsArtmann pattern documented  |
| L5 | Clean up `collectMissingRequires` temp file in trap (`trap "rm -f ..." EXIT`)         | TODO   | 10min  | `mkPreparedSource.nix` `collectMissingRequires`; temp file leaks on error |
| L6 | Add `stripVersionSuffix` edge case tests (`v1`, `v100`, empty string, single segment) | TODO   | 15min  | `mkPreparedSource.nix` `stripVersionSuffix`          |
| L7 | Add `nix flake check --all-systems` to CI                                             | TODO   | 15min  | `.github/workflows/ci.yml`; only x86_64-linux checked |
| L8 | Cache nix-store in smoke-test CI job (speed up)                                       | TODO   | 15min  | `.github/workflows/ci.yml` smoke-test job             |
| L9 | Run integration tests on macOS (not just eval)                                        | TODO   | 30min  | `.github/workflows/ci.yml`; macOS runs `--no-build` only |
| L10 | Extract `postPatch` script from `mkPreparedSource` into separate `.sh` file          | TODO   | 30min  | `mkPreparedSource.nix`; 30+ lines of embedded shell   |

## Blocked

| Task                                                                | Status  | Impact | Effort | Evidence                                                                       |
| ------------------------------------------------------------------- | ------- | ------ | ------ | ------------------------------------------------------------------------------ |
| Register `maintainers.larsartmann` in nixpkgs                       | BLOCKED | Low    | 30min  | Requires external PR to nixpkgs repo                                           |
| Real private-repo integration test in CI                            | BLOCKED | High   | 2h     | CI job scaffolded (`if: false`); needs SSH key secret (`DEPLOY_SSH_KEY`)       |
| Audit all downstream consumers for migration status and workarounds | BLOCKED | Med    | 2h     | Requires access to 7+ downstream repos (BuildFlow, mr-sync, PMA, etc.)         |
| Real e2e consumer test through full build pipeline                  | BLOCKED | High   | 4h     | Needs mock Go project + flake.nix importing go-standard, built via `nix build` |
| Fix empty commit message in `df9a5ff`                               | BLOCKED | Low    | 15min  | Requires interactive rebase + force-push; user approval needed                 |
