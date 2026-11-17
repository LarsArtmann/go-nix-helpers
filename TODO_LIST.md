# TODO List

> Short-term, actionable, bounded work for go-nix-helpers. For long-term vision,
> see `ROADMAP.md`; for shipped changes, see `CHANGELOG.md`.
> Last docs-health harvest: 2026-11-17 (container-foundation report harvested: 25 rows T35–T59; report items f/1–f/5, f/31, g/3 annotated resolved inline).

## Status legend

| Status      | Meaning                                                 |
| ----------- | ------------------------------------------------------- |
| TODO        | Not started. Needs doing.                               |
| IN_PROGRESS | Actively being worked on.                               |
| BLOCKED     | Cannot proceed, external dependency or decision needed. |

## High impact

| #  | Task                                                                                                                               | Status | Effort | Evidence                                                                      |
| -- | ---------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | ----------------------------------------------------------------------------- |
| T4 | Migrate Tier B consumers to go-standard (KeyCountdown, StopTube, branching-flow, bank-sync, overview, BuildFlow) — G2 unblocks all | TODO   | 4h     | `docs/status/2026-08-10_11-02_*` Tier B table; G2 shipped `2f3b6b2`           |
| T5 | Migrate Tier C consumers off deprecated `mkGoFlake` (Standup-Killer, crush-daily)                                                  | TODO   | 2h     | `mkGoFlake.nix` deprecation trace; only 2 repos remain on the deprecated path |

## Medium impact

| #   | Task                                                                                                                                                                                                                                 | Status | Effort | Evidence                                                                                                   |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ | ------ | ---------------------------------------------------------------------------------------------------------- |
| T33 | Wire `go-standard.systems` mapping verification into `test-module.nix` (the composite mapping is verified by CI + the 2026-09-25 consumer probe, but not by a module test)                                                           | TODO   | 30min  | commit `105c981`+ — probe was manual; regression coverage missing                                          |
| T34 | Sweep consumers: GOEXPERIMENT boilerplate → `goExperiment` option; cobra repos → `completionStyle = "subcommand"` (7/10 Tier A repeat it; sbts's extraBuildAttrs GOEXPERIMENT included — its modBuildPhase override is already gone) | TODO   | 2h     | `docs/status/2026-08-10_16-50_*` E.9–E.11; options shipped 2026-09-24; requires go-nix-helpers master push |

## Container foundation (2026-11-17 harvest)

> From `docs/status/2026-11-17_15-00_oci-container-foundation.md` (§f backlog, §g questions). The `container` option (nix2container) is built, tested (218 moduleTest assertions, containerSmoke against the real backend), and green at HEAD — everything below ships AFTER the pending push approval (§g.1).

| #   | Task                                                                                                                            | Status  | Effort | Evidence                                                                |
| --- | ------------------------------------------------------------------------------------------------------------------------------- | ------- | ------ | ----------------------------------------------------------------------- |
| T35 | docs/flake-patterns.md: container pattern + anti-patterns (Dockerfile, dockerTools for shipping)                                | TODO    | 1h     | report f/6                                                              |
| T36 | docs/architecture.d2 + svg: add container.nix component                                                                         | TODO    | 30min  | report f/7                                                              |
| T37 | docs/consumer-audit-checklist.md: add container section                                                                         | TODO    | 30min  | report f/8                                                              |
| T38 | scripts/dashboard.sh: container column across fleet                                                                             | TODO    | 1h     | report f/9                                                              |
| T39 | Structure check: richer mismatch diff (jq-driven localization instead of dumping both configs)                                  | TODO    | 1h     | report f/10, e/4                                                        |
| T40 | Test custom `created` round-trip (RFC3339Nano edge)                                                                             | TODO    | 30min  | report f/11                                                             |
| T41 | Multi-arch manifest app: merge per-system images into one tag (skopeo copy --all)                                               | TODO    | 3h     | report f/13                                                             |
| T42 | `container.fromImage` (distroless base) via n2c fromImage/pullImageFromManifest                                                 | TODO    | 3h     | report f/14                                                             |
| T43 | `container.initializeNixDatabase` passthrough (CI images)                                                                       | TODO    | 1h     | report f/15                                                             |
| T44 | Tag strategy knob docs: content-hash vs `self.rev`-derived default                                                              | TODO    | 30min  | report f/16                                                             |
| T45 | README section on registry auth (docker login / skopeo) for image-push                                                          | TODO    | 30min  | report f/17                                                             |
| T46 | GHCR push workflow template (consumer CI) using the image-push app                                                              | TODO    | 1h     | report f/18; registry decided 2026-11-17 (g/3: ghcr default kept, Forgejo-remote carve-out); GHA workflow implies a GitHub remote by construction |
| T47 | PapDashboard pilot: merge `oci-go-standard-pilot` branch + relock go-nix-helpers (branch verified via path override 2026-11-17) | BLOCKED | 30min  | report f/19, g/2 templ disposition; relock OK (origin carries the container option since the 18:55 push); PapDashboard CHANGELOG Unreleased has the branch note |
| T48 | KeyHolderAI migration to `container` option                                                                                     | TODO    | 2h     | report f/20; g/1 moot (origin/master carries the container option)      |
| T49 | standard-bug-tracking-schema migration to `container` option                                                                    | TODO    | 2h     | report f/21; g/1 moot (origin/master carries the container option)      |
| T50 | bank-sync: adopt go-standard (deps audit; mkPreparedSource already hand-wired)                                                  | TODO    | 4h     | report f/22; g/1 moot (origin/master carries the container option)      |
| T51 | Code-Quality-Agent + artmann-technologies-website: adopt-or-manual decision                                                     | BLOCKED | 15min  | report f/23–24; owner decision; artmann-technologies-website is Forgejo-remote → registry default does NOT apply (2026-11-17 carve-out) |
| T52 | Fleet sweep: delete every remaining hand-rolled dockerTools block                                                               | TODO    | 2h     | report f/25; after T47–T49; g/1 moot (daemon pushed master 2026-11-17)  |
| T53 | nix-private-go-repos skill: note that image push works with private deps (deps live in layers)                                  | TODO    | 15min  | report f/26                                                             |
| T54 | Local aarch64-linux containerSmoke build (emulation) before CI sees it                                                          | TODO    | 1h     | report f/27                                                             |
| T55 | Review GH Actions runtime delta from containerSmoke (Go build per OS)                                                           | TODO    | 30min  | report f/28                                                             |
| T56 | CI: assert `nix flake check --all-systems --no-build` (catches darwin eval gaps)                                                | TODO    | 30min  | report f/29; today's darwin gap was caught exactly this way             |
| T57 | Post-push consumer audit: `nix flake update` sweeps (nix2container lands transitively in locks)                                 | TODO    | 1h     | report f/30; unblocked — push happened (daemon, 2026-11-17)             |
| T58 | Document the nix2container lock pin (rev `42d1df94`, 2026-10-30) in a doc note                                                  | TODO    | 15min  | report f/32                                                             |
| T59 | Document the Nix 2.34 tryEval message-free assert helper pattern (never assert on thrown message text)                          | TODO    | 15min  | report f/12; AGENTS.md gotcha exists — promote to flake-patterns.md     |

## Decided against / rejected

| Task                                              | Reason                                                                                                                                                                                               |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Extract `postPatch` to a separate `.sh` (old L10) | Empirically rejected 2026-08-10: prototype passed all tests but needs 11 env vars, 8 `eval` calls, splits logic across 2 files — a Verschlimmbesserung. Inline `postPatch` is the idiomatic pattern. |

## Blocked

| Task                                                                                             | Status  | Impact | Effort | Evidence                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------ | ------- | ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Register `maintainers.larsartmann` in nixpkgs                                                    | BLOCKED | Low    | 30min  | Requires external PR to nixpkgs repo                                                                                                                                                                                          |
| Real private-repo integration test in CI                                                         | BLOCKED | High   | 2h     | CI job scaffolded (`if: false`); needs SSH key secret (`DEPLOY_SSH_KEY`)                                                                                                                                                      |
| Fix empty commit message in `df9a5ff`                                                            | BLOCKED | Low    | 15min  | Requires interactive rebase + force-push; user approval needed                                                                                                                                                                |
| Cut first tagged release (v0.1.0)                                                                | BLOCKED | Medium | 30min  | Owner decision — unlocks the `mkGoFlake` removal contract and consumer version pinning                                                                                                                                        |
| Decide the Won't-implement policy (age threshold / cap / owner sign-off for "dormant — dropped") | BLOCKED | Low    | 15min  | Owner decision — ~120 unilateral verdicts were stamped during the 2026-09-24 annotation pass                                                                                                                                  |
| T15: `templ generate` in `modBuildPhase` when `enableTempl`                                      | BLOCKED | Low    | 30min  | Owner decision pending (2026-09-25 §g.3: propose won't-implement — consumers commit `*_templ.go`; build-time generation is dead weight + templ-version reproducibility risk; C8/T34b removes the motivating override instead) |
