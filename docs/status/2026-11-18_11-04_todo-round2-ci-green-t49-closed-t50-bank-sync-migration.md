# Status Report — TODO-Execution Round 2: CI Green, T49 Closed, T50 bank-sync Migration ~90%

**Session**: 2026-11-18 ~06:00 → 11:04 CET (continuation of the 2026-11-17/18
full-TODO-list execution; prior state: 26/31 actionable tasks done, master
repaired at `df0aaff`, CI verdict pending)
**Scope of this report**: this session's run only, as ordered.

---

## a) FULLY DONE (this session, verified)

| # | Item                                                           | Evidence                                                                                                                                                                                                                                                                                                                                                                               |
| - | -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **CI verdict on repair push `df0aaff`** (run 44246957215)      | All jobs green EXCEPT `flake-lock-freshness` (nixpkgs pin 2 days stale: `d5cc683` → `1a08097`)                                                                                                                                                                                                                                                                                         |
| 2 | **Flake.lock freshness fixed**                                 | Full `nix flake update` (only nixpkgs moved), `nix flake check --all-systems --no-build` green locally, daemon committed as `a393e23`, pushed, **CI run 44248401045 ALL GREEN** (smoke, shellcheck, old-nixpkgs, integration x2, check x2, flake-lock-freshness)                                                                                                                       |
| 3 | **T49 tail — standard-bug-tracking-schema container verified** | Real image attr confirmed: **`issue-shield-image`** (NOT `standard-bug-tracking-schema-image`). Stale vendorHash fixed (`sha256-gh8Ng…`), `nix build .#issue-shield-image` GREEN, `checks.container-structure` GREEN, eval green. Dockerfile removal was already daemon-committed (`227300fa`); vendorHash fix committed as `91289661`. Repo ahead 3, unpushed (push approval pending) |
| 4 | **T50 deps audit — ZERO drift**                                | Every LarsArtmann require in bank-sync go.mod resolves via the 16-entry `deps` map (nested modules via mkPreparedSource auto-discovery) or `publicDeps`. The three suspicious extras (go-flightrecorder, go-idempotency, go-sse root) are all real requires. Nothing to fix                                                                                                            |
| 5 | **T50 module swap — implemented and eval-green** (see b)       | `nix flake check --no-build` green on x86_64-linux; all-systems fails ONLY on pre-existing `erraudit` linux-only meta (identical before migration — proven)                                                                                                                                                                                                                            |
| 6 | **T50 main package builds GREEN through the module**           | `nix build .#default` exit 0; `checks.test` (hermetic Go tests), `checks.vendor-witness` (content markers — proves the module's prepared source vendors the exact pinned trees), `checks.vendor-hash` all build green                                                                                                                                                                  |

## b) PARTIALLY DONE

### T50 bank-sync go-standard adoption (~90%)

**Swap complete on disk (daemon-committed mid-edit; not yet committed as a unit):**

- Input `go-nix-helpers`: `flake = false` → real flake + `nixpkgs.follows`; lock at `a393e23`
- Imports: composite `flakeModules.go-standard` + git-hooks (treefmt-nix input dropped — bundled by composite)
- `systems`: inline list removed — owned by `go-standard.systems`
- perSystem: `_module.args.pkgs = pkgs` promotes the allowUnfree nixpkgs import to THE perSystem pkgs for all modules (flake-parts' default is `mkOptionDefault` — overridable; module-generated package needs unfree for `meta.license = unfree` checkMeta)
- `go-standard` config at **top level** (transposed option — see d): pname/description/src fileset/deps×16/publicDeps×7/vendorHash/goPkgAttr "go_1_27"/goExperiment "jsonv2"/ldflags with commit stamp/extraBuildAttrs (excludedPackages, scrubbed modInstallPhase)/extraMeta (unfree, linux)/container (imageName "bank-sync", cmd, env, 8097/tcp, /data volume, 65532:65532)
- Disables (all have better hand-rolled equivalents kept): enableDevShells, enableOverlay, enableCheck, enableGolangciLint, enableGofumpt/Goimports/Nixfmt/Templ (bank-sync's custom treefmt formatter names stay); enableTestCheck = true (module's checks.test replaces the identical hand-rolled one)
- Deleted: hand-rolled `preparedSrc` block, `packages.default` buildGoModule (~85 lines), hand-rolled n2c `packages.image` (~55 lines), `checks.format/build/image/test`; `image-oci` repointed to `packages."bank-sync-image".copyTo`
- vendorHash danced via the repo's canonical `nix run .#update-vendor-hash -- --fod default` (proved the first-line ordering contract survives the move); `apps.update-vendor-hash` 3-line count intact
- Header image comments updated to `.#bank-sync-image` / `.copyToRegistry`

**Remaining to finish T50 (blocked on cqrs-lint FOD, see d):**

1. Resolve `inconsistent vendoring` in the cqrs-lint package build (mid-diagnosis — go.mod wants the NEW graph: go-finding v1.15.1 / toolsdk v1.16.0 / templ v0.3.1100 / cmdguard/v5 v5.0.0 / go-output v0.38.7; vendor/modules.txt carries OLD markers v1.15.0 / v0.38.4). Next step already queued: compare the package drv's goModules input (`8dhxdk…`, realized with OLD modules.txt) against the CURRENT FOD drv (`lb9d3agg…`) — stale-FOD pairing vs FOD-really-vendors-old-graph (go.sum theory)
2. devShell `go mod tidy` for repo go.mod/go.sum parity (devShell blocked: `nix-shell-env` → cqrs-lint build)
3. Full battery re-run (lint, golangci-config, pinned-tree, catalog-drift, dep-alignment, cqrs-lint-vendor-witness, image, image-oci, container-structure, format)
4. `nix flake check --no-build` + all-systems, cleanup `/tmp/banksync-old` worktree + `/tmp/templ-components-v*` clones
5. Update stale flake comments (go-cqrs-lite input comment says "frozen at 9673552fb280", lock says `6f8dd604`) — DONE 2026-11-18 rounds 5-7: coherent commits landed; residual daemon races documented (round-7 §d.3)
6. Coherent commit (daemon has 4+ mid-edit commits; collapse or follow-up commit per AGENTS/14)
7. AGENTS/05 + migration-guide note

## c) NOT STARTED (from the remaining TODO list)

- T5 Standup-Killer / crush-daily off mkGoFlake
- T4 fleet migrations (KeyCountdown, StopTube, branching-flow, overview, BuildFlow; bank-sync "phase 2" monorepo split if multi-binary)
- T34 / T52 / T57 / T60 fleet sweeps
- T71 heading-mode canon; T41 multi-arch manifest; T42 container.fromImage
- Docs pass: AGENTS.md corrections (false systems-mapping narrative) + counts (55/18/222/75), TODO_LIST statuses, CHANGELOG Unreleased, FEATURES
- Final gates (`scripts/ci-parity.sh`) + push + CI green
- **Still-owed inline TABLE VIEW report** (Pareto tiers + M1–M27 + F-table summary) — not delivered this session either

## d) TOTALLY FUCKED UP (found, and what happened)

**No new self-inflicted damage that shipped.** All breakage found was
PRE-EXISTING and latent on bank-sync master — proven by building the OLD
flake from a clean worktree at `81022644` (pre-migration commit, old lock):
it fails with the IDENTICAL hash mismatch. The migration merely forced the
first FOD rebuilds since the 2026-11-13 "A12 wave 1" pin convergence
(bank-sync CI is billing-disabled → nobody had rebuilt).

| Breakage (all pre-existing, all since ~2026-11-13 A2)                                                               | Root cause                                                                                                                                                                                                                                                     | Status                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checks.lint` broken: `templ.ResolveAttributeValue` undefined in vendored `templ-components/utils/svg/svg_templ.go` | cqrs-htmx v4.15.0 requires templ-components **v1.27.0**; A12 pinned the input at the **v1.26.0 tag** → replace maps v1.27.0 requirement onto the v1.26.0 tree, whose generated code calls an API **removed** in a-h/templ v0.3.1100 (which the graph resolves) | **FIXED**: input + go.mod (root/htmx/icons/utils) bumped to v1.27.0; lock updated; vendorHash re-danced (`sha256-wmjPuA…`); main build green again |
| cqrs-lint FOD: `sed: can't read go.mod`                                                                             | go-cqrs-lite restructured `cmd/cqrs-lint` → `cmd/cqrs-lint/v4` (module root moved one level down); bank-sync copies `cmd/cqrs-lint/*` and got only a `v4/` dir                                                                                                 | **FIXED**: copy from `cmd/cqrs-lint/v4/*`; added `cmdguard/v5` to commonPublicDeps (v4 requires /v5 now)                                           |
| cqrs-lint FOD: tidy vs committed vendor/                                                                            | the v4 module ships a COMMITTED `vendor/` whose modules.txt pins proxy versions; after local replaces rewrite go.mod, tidy refuses                                                                                                                             | **FIXED**: `postPatchExtra = "rm -rf vendor"` on preparedCqrsLintSrc                                                                               |
| cqrs-lint package: `go: inconsistent vendoring`                                                                     | see b — OLD modules.txt markers vs NEW go.mod graph                                                                                                                                                                                                            | **OPEN** — mid-diagnosis                                                                                                                           |
| devShell unbuildable                                                                                                | `nix-shell-env` → packages.cqrs-lint → the FOD above                                                                                                                                                                                                           | Blocked on the same fix                                                                                                                            |
| erraudit FOD                                                                                                        | same class (stale since A12)                                                                                                                                                                                                                                   | **FIXED** — builds green                                                                                                                           |

**My own process mistakes this session (honest list):**

1. Wrote the go-standard config INTO perSystem first — the option is
   TRANSPOSED (top-level). One look at a working consumer (PapDashboard)
   BEFORE writing would have saved a full failed eval + 200-line move.
2. Function-wrapped the mkFlake module to get `lib` at top level, broke the
   2400-line file's brace structure, burned 3 rounds on closing-brace
   archaeology (plus a hand-rolled brace scanner whose first version had an
   index bug and whose second version cannot see `${…}` interpolations).
   Correct fix was known all along: literal module + `inputs.nixpkgs.lib`.
3. `goPkgOverride = "go_1_27"` — that option takes `pkgs: package`; the
   string pin is `goPkgAttr`. One option read too fast.
4. Piped exit codes lied to me AGAIN (`BATCH2=0` through `| tail` — the
   exact known gotcha from the prior session, re-hit once more).
5. Bumped the go-nix-helpers lock rev and the module swap in one step
   (forced: container option needs a ≥2026-11-17 rev) — confounded the
   diagnosis; the worktree-isolation proof should have been the FIRST move
   when the vendor hash shifted, not the fifth.
6. Daemon raced my edits twice (mtime changed mid-edit) — handled, but each
   round-trip costs a re-read; batch big edits tighter.

## e) WHAT WE SHOULD IMPROVE (systemic, observed this session)

1. **bank-sync CI is billing-disabled** — master carried broken `checks.lint`
   AND an unbuildable devShell for ~5 days undetected. A cron'd
   `nix build .#checks.x86_64-linux.lint` (or re-enabling CI) would have
   caught A12's fallout the same day.
2. **A12-style "canon pin" convergences must run the affected FODs** — the
   wave changed go-cqrs-lite + templ-components pins but never rebuilt
   bank-sync's tool FODs or lint check; pin convergence without a build is
   a half-landing.
3. **mkPreparedSource consumers need a structural-drift guard**: input repos
   restructure (cmd/cqrs-lint → /v4) and the copy-path goes stale silently.
   A cheap `test -f $src/go.mod` after copy would fail with the real cause.
4. **Version-skew guard**: replaces that map a NEWER required version onto an
   OLDER pinned tree compile-by-luck (only golangci's full typecheck caught
   it). The dep-alignment script's SUBMODULE_TAG_PINS/FROZEN_EXCEPTIONS
   machinery documents the skew but nothing enforces the
   "required-version ≤ pinned-tree-version" invariant.
5. My own: consult a WORKING consumer before writing consumer config for a
   module I only know from the inside.

## f) NEXT UP TO 50 (priority order)

**T50 finish (immediate):**

1. Diagnose+fix cqrs-lint `inconsistent vendoring` (stale-FOD pairing vs go.sum-pinned old graph — one experiment distinguishes)
2. devShell tidy (go.mod/go.sum parity for v1.27.0 bump)
3. Full bank-sync battery green (lint, golangci-config, pinned-tree, catalog-drift, dep-alignment, cqrs-lint-vendor-witness — its marker may need updating to the v1.15.1-era const, image, image-oci, container-structure, format)
4. `nix flake check --all-systems --no-build`; cleanup /tmp worktrees+clones
   ~~5. Coherent commit(s) per AGENTS/14 daemon protocol~~ — DONE 2026-11-18 rounds 5-7: coherent commits landed; residual daemon races documented (round-7 §d.3)
5. Stale go-cqrs-lite input comment fix ("frozen at 9673552" vs lock 6f8dd604)
6. AGENTS/05 + go-nix-helpers migration-guide bank-sync case study (partial adoption IS a supported shape: enable-devshells=false + keep custom battery)

**Fleet migrations:**
8. T5 Standup-Killer / crush-daily off mkGoFlake
9. T4 KeyCountdown (games/KeyCountdown)
10. T4 StopTube
11. T4 branching-flow
12. T4 overview
13. T4 BuildFlow (T47–T49 recipe: consumer branch → --override-input verify → --no-verify commit → relock at merge)
14. bank-sync phase 2: monorepo `packages` split if multi-binary (probably not — single cmd)
15. T51 Code-Quality-Agent + artmann-technologies-website adopt-or-manual verdict (Forgejo carve-out applies)

**Sweeps:**
16. T52 delete every remaining hand-rolled dockerTools block
17. T57 post-push `nix flake update` sweeps (nix2container lands transitively)
18. ~~T34 / T60 (as specced in TODO_LIST) — DONE 2026-11-18: T34 and T60 both DONE with evidence in TODO_LIST~~ done — T34 + T60 DONE 2026-11-18 (rows graduated into CHANGELOG [Unreleased])
19. Fleet-wide templ-components v1.27.0 alignment check (other consumers of the A12 pin may carry the same latent skew — same diagnosis: `nix build .#checks.lint`)

**Module features:**
20. T71 heading-mode canon
21. T41 multi-arch manifest
22. T42 container.fromImage

**This repo (go-nix-helpers) closure:**
23. AGENTS.md: remove false "systems never consumed" narrative (T33 finding), update counts (55 options / 18 container keys / 222 moduleTest assertions / 75 pure-function checks), record bank-sync partial-adoption pattern
24. TODO_LIST.md statuses (T47–T50, T53–T56, T58, T64, T65, T68 done; refresh remaining)
25. CHANGELOG Unreleased section
26. FEATURES.md update (container option, self-hosting, initializeNixDatabase)
27. Deliver the STILL-OWED inline TABLE VIEW report (Pareto 1%/4%/20% + M1–M27 + F-table)
28. Final gates: `scripts/ci-parity.sh` + push + CI green
29. Status-report battery (docs-gates) after doc edits
30. Reconcile TODO_LIST "31 actionable" bookkeeping with the 26+3 done state

**Bank-sync debt (newly discovered, worth queueing there):**
31. Re-enable or replace billing-disabled CI (5-day silent red) — ROUTED 2026-11-18 to TODO_LIST T72/T80: the billing class recurred today (13 never-started CI runs); canary row added
32. cqrs-lint-vendor-witness marker refresh for the v4-module era
33. `rm -rf vendor` postPatchExtra upstream question: should go-cqrs-lite stop committing vendor/ in cmd/cqrs-lint/v4?

## g) QUESTIONS (cannot figure out myself)

1. **Push approval for other repos** (carried, still unanswered): KeyHolderAI (`4972ec42`), standard-bug-tracking-schema (ahead 3), SKILLS, docs-gates, crush-config, and now **bank-sync** (migration + A12 repairs). "GET SHIT DONE" covers commits; pushing other repos needs your explicit yes per the never-push rule.
2. **A12 canon vs reality**: the adr/0003 "canon revs" pinned templ-components at v1.26.0, but the dependency graph (cqrs-htmx v4.15.0) requires v1.27.0 — I bumped bank-sync past the canon to fix the break. Should the canon itself be updated to v1.27.0 (fleet-wide re-convergence), or is per-repo escape from a broken canon pin acceptable? This determines whether T19-style waves need a "graph-check" step.
3. **v0.1.0 tag timing for go-nix-helpers** (carried, still unanswered): master is green and now self-hosts the module — tag now, or after T71/T41/T42 land?

---

**Battery state at report time**: go-nix-helpers master green (CI `44248401045`);
bank-sync: eval green, packages.default/test/vendor-witness/vendor-hash/erraudit green,
lint-class checks pending the cqrs-lint FOD fix; nothing in ANY repo left half-edited
by me (all working-tree states are the daemon's commits of my verified intermediate
states).
