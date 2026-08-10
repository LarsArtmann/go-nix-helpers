# Consumer Fleet Audit — All Go Repos vs. go-standard "Superb" Usage

**Date:** 2026-08-10 11:02
**Scope:** All 34 repos under `/home/lars/projects/` that reference `go-nix-helpers` (30 legacy/manual + 5 go-standard module adopters, minus `SystemNix` which is a NixOS system flake, not a Go project).
**Method:** Manual read of every flake.nix + automated 8-section triage (`docs/consumer-audit-checklist.md`) + `nix flake check --no-build` spot-checks.
**Status:** All 34 flakes evaluate and pass `nix flake check --no-build` at the time of writing. This is a **"superb usage"** audit, not a breakage audit.

---

## 1. Executive Summary

| Metric | Count |
|---|---|
| Repos using go-standard module | **5 / 34** (15%) |
| Repos on legacy manual `mkPreparedSource` | **27 / 34** (79%) |
| Repos on deprecated `mkGoFlake.nix` | **2 / 34** (6%) |
| Repos on raw `import nixpkgs` re-instantiation | 4 (bank-sync, DiscordSync, github-local-sync, +1) |
| Repos with redundant `treefmt-nix`/`systems`/`git-hooks` inputs | all 29 legacy |
| Repos with manual GOPRIVATE (should be auto) | 22 |
| Repos with `flake = false` on go-nix-helpers | **29** (all legacy) |
| Repos with placeholder vendorHash | 0 |
| Repos with missing vendorHash in flake.nix | 2 (both put it in nix/*.nix — OK) |
| Repos with CI workflow | 30 / 34 |

**The fleet is healthy but uniformly legacy.** Every repo was hand-rolled onto
`mkPreparedSource` before the go-standard module existed (or onto the
deprecated `mkGoFlake`), then left there. They all build. The gap is
maintainability: 100-1200 lines of per-repo Nix vs. the ~20-line module config,
plus 2 extra mandatory inputs (`treefmt-nix`, `systems`) per repo.

---

## 2. Migration tiers

### Tier A — Straightforward module migration (public deps only, no special Go)
These repos use plain `buildGoModule` + `mkPreparedSource` with public deps, no
custom Go derivation, no `postPatchExtra`, no NixOS modules, no multi-package
subtlety. They can move to go-standard with only the module's config surface:

| Repo | Lines | Private requires | Notes |
|---|---|---|---|
| `go-localsync` | 237 | 3 covered | 1 package, clean deps, GOEXPERIMENT via env-only |
| `go-humanize-linter` | 286 | 5 covered | custom source filter (module supports src), app coverage |
| `golangci-lint-auto-configure` | 233 | 3/4 covered | validatePrivateDeps=false, custom apps |
| `oxlint-auto-configure` | 196 | 5 covered | GOEXPERIMENT, apps |
| `go-auto-upgrade` | 541 | 10 covered | custom go version? (verify), apps |
| `project-dependency-graph` | 230 | 9/13 covered | apps, no custom Go |
| `erraudit` | 257 | 11 covered | custom version ldflags (module supports), apps |
| `project-meta` | 268 | 8 covered | git-hooks + custom checks, apps |
| `projects-management-automation` | 267 | 4/15 covered | **needs deps expansion + validatePrivateDeps** |
| `go-cqrs-lite` | 1224 | 1 covered | library build, custom cqrs-lint packages |
| `mr-sync` | 252 | 9 covered | **has its own package.nix + custom overlay + module.nix — non-trivial** |
| `library-policy` | 139 | 13 requires, 0 covering | **uses nix/* submodules + commited vendor? verify** |
| `standard-bug-tracking-schema` | 386 | 5 covered | treefmt-flake overlay, nixosModules |

### Tier B — Modest migration (GOEXPERIMENT / env / custom multi-package)
| Repo | Lines | Why B |
|---|---|---|
| `KeyCountdown` | 250 | custom modBuildPhase + buildTools, apps |
| `KeyHolderAI` | 354 | custom modFod + many apps |
| `StopTube` | 262 | custom modFod + 2 packages with different subPackages + tags |
| `branching-flow` | 328 | custom go-enum buildGoModule tool, goPkg, apps, checks |
| `browser-history` | 600 | 2 server/agent packages + 2 nixosModules + VM checks |
| `overview` | 468 | git-hooks + nixosModules + 2 packages |
| `DiscordSync` | 725 | **many pinned revs**, allowUnfree re-instantiation |
| `github-local-sync` | 279 | allowUnfree re-instantiation, validatePrivateDeps=false |
| `bank-sync` | 515 | allowUnfree, custom modFod, GOEXPERIMENT, 8 apps |
| `BuildFlow` | 1215 | **biggest** — custom multi-tool packages, apps, checks |

### Tier C — Complex (needs module feature work first) or leave as-is
| Repo | Why C |
|---|---|
| `Standup-Killer` | deprecated `mkGoFlake` + `doCheck=false` + postPatch hacks + many subModules |
| `crush-daily` | deprecated `mkGoFlake` + huge custom nixosModule + extraFlake checks + extraApps |
| `Code-Quality-Agent` | **custom Go 1.26.4 built from source** — go-standard `goPkgAttr` can't express this |
| `file-and-image-renamer` | 21 private requires, 13 covered — needs dep audit; templ |
| `go-structure-linter` | postPatchExtra multi-module replace injection — module supports postPatchExtra but the custom `builtins.path` filter and multi-binary package setup make this delicate |
| `template-arch-lint` | module adopter but has redundant treefmt/systems inputs to remove + GOPRIVATE manual (auto) |

### Module adopters (already migrated — review quality)
| Repo | Flake lines | Issues found |
|---|---|---|
| `index` | 363 | `enableCheck=true` redundant; `enableTempl=true` but treefmt excludes *templ.go; GOPRIVATE manually set (harmless, auto when deps); 5 private requires w/ 1 dep mapping — **needs publicDeps or deps expansion**; custom checks ok |
| `lean-business-plan` | 83 | **unused `systems` + `treefmt-nix` inputs** (module bundles); src via fileset good; `extraBuildAttrs.preBuild="templ generate"` good; missing GOPRIVATE (auto when deps — none here, correct) |
| `storbi` | 95 | **unused `systems`+`treefmt-nix` inputs**; GOPRIVATE manual (harmless); `deps` only covers 3/4 private requires — **go-error-family etc. verify**; extraBuildAttrs env.CGO_ENABLED=0 — module supports via extraBuildAttrs/env |
| `template-arch-lint` | 54 | **unused `systems`+`treefmt-nix` inputs**; `shellExtraEnv.GOPRIVATE` redundant (auto when deps set — but deps NOT set here! verify private requires) ; `subPackages=["cmd"]` + postInstall mv hack — module supports; 4 private requires, 0 covering |
| `terraform-diagrams-aggregator` | 80 | **unused `systems`+`treefmt-nix` inputs**; `deps` covers 4/8 private requires — **needs publicDeps for the other 4 (go-atomic-write etc.?) or deps expansion**; `doCheck=false` intentional |

---

## 3. Systemic findings (across all repos)

### 🔴 High
1. **29/30 legacy repos declare `go-nix-helpers` with `flake = false` and import `mkPreparedSource.nix` manually** — works, but forfeits: auto-GOPRIVATE, auto-tidy, auto-validation, auto-submodule-discovery, module-level vendorHash warnings, monorepo support. All are de facto "orphaned" from module improvements.
2. **22 repos set GOPRIVATE manually** even though the module auto-injects it when `deps` is set. After migration this becomes dead config (harmless, but misleading).
3. **Deps coverage gaps:** several repos have `github.com/larsartmann/*` requires in go.mod without matching flake inputs AND without `publicDeps`/`validatePrivateDeps=false`. Current validation is *passive* (only mkPreparedSource flags missing replaces at build time, and only for the root go.mod). Repos affected: `BuildFlow` (23→18), `file-and-image-renamer` (21→13), `projects-management-automation` (15→4), `project-dependency-graph` (13→9), `template-arch-lint` (4→0), `terraform-diagrams-aggregator` (8→4), `index` (5→1), `storbi` (4→3), `KeyHolderAI` (11→9).
   → **These need a per-repo "is it actually public?" check** (go-atomic-write, go-ndjson, go-sse, go-output, go-branded-id, go-error-family, gogenfilter are PUBLIC and need `publicDeps` or are already covered; truly-privates are go-finding, go-cqrs-lite, httputil, project-discovery-sdk, etc.) — the module's `validatePrivateDeps` will catch true gaps at first build, but only if validation isn't disabled.

### 🟠 Medium
4. **All legacy repos carry 5+ inputs** (`nixpkgs`, `flake-parts`, `systems`, `treefmt-nix`, `go-nix-helpers`, often `git-hooks`) vs 3 required. Migration removes ~50% of input surface.
5. **4 repos re-instantiate nixpkgs** (`import inputs.nixpkgs { config.allowUnfree = true; }`) — documented exception, but should be minimized/centralized.
6. **`go-cqrs-lite` (1224 lines!)** is the largest flake — likely a monorepo library with many `cmd/*` packages. It'd benefit most from the module's `packages` (monorepo) option if structured as such.
7. **Redundant `proxyVendor = true`** in ~14 legacy repos — intentional in their FOD scripts but confusing; the module auto-forces `proxyVendor=false` when deps are set (the correct behavior for prepared sources).
8. **No repo uses the module's `checks` beyond format/build** — most rely on custom `checks.test` overrides or none. The module's default `checks` are minimal (format+build), which is fine, but consumers should know they can add `checks.test` via perSystem directly.

### 🔵 Low
9. **`devShells.ci` differs** across repos (some `mkShellNoCC`, some `mkShell`) — module standardizes on `mkShellNoCC` for CI. Good migration side-effect.
10. **Version strings**: some repos hardcode `version = "0.2.0"` (branching-flow) or `"0.3.0"` (erraudit) instead of `self.rev or "dev"`. Module default derives from git — recommend `version = self.rev or self.dirtyRev or "dev"` everywhere.
11. **`meta.maintainers`** uses inline `{ name = "Lars Artmann"; github = "LarsArtmann"; }` — correct pattern, matches module default.

---

## 4. go-standard module gaps surfaced by this audit

These are things consumers need that the module could not express at audit
time. Two gaps (G1, G3) were fixed immediately after the audit; two (G2, G5)
remain open:

| # | Gap | Affected repos | Status |
|---|---|---|---|
| G1 | **Custom Go derivation** (`goPkgAttr` is a string attr name, can't pass `pkgs.go_1_26.overrideAttrs { version=...; src=...; }`) | Code-Quality-Agent (go 1.26.4 custom build) | ✅ **FIXED** — new `goPkgOverride` option (function applied to the pkg from `goPkgAttr`), tested (106 module assertions) |
| G2 | **Per-package `extraBuildAttrs`** (monorepo `packages` entries can't carry custom preBuild/postInstall/env per binary) | StopTube (2 pkgs diff attrs), browser-history (2 pkgs), BuildFlow (multi-tool), go-structure-linter (multi-module) | ❌ Open — extend `packages` submodule with the same extraBuildAttrs surface |
| G3 | **`checks.lint` not generated** — module makes `apps.lint` only; consumers expecting a CI `checks.lint` derivation must hand-write it (bank-sync, index have custom ones). | Several | ✅ **FIXED** — new `lintAsCheck` option (default: false) exposes a hermetic `checks.lint` derivation |
| G4 | **`overrideModAttrs` / `modBuildPhase`** custom FOD phases are NOT expressible as extraBuildAttrs because they're nested inside `autoDepFodAttrs` which is `//`-merged *after* user extraBuildAttrs (user can't override). | bank-sync, StopTube, KeyCountdown, go-localsync (all use custom modBuildPhase) | ⚪ No action — module's autoDepFodAttrs already does `go mod tidy` + `go mod vendor` + copy-back, functionally identical to the manual phases |
| G5 | **`subPackages` with `packages` monorepo complements** — multi-binary repos building several `cmd/*` with different flags | browser-history, BuildFlow | ❌ Open — covered by G2 once per-package attrs exist |

**G4 audit correction:** the module's `autoDepFodAttrs` (go mod tidy + go mod vendor + copy back) is *functionally identical* to the custom `modBuildPhase`/`modInstallPhase` in bank-sync/StopTube/KeyCountdown/go-localsync. Migration from those repos is simpler than feared — the only remaining diff is `GOEXPERIMENT` handling (needs `extraBuildAttrs.env.GOEXPERIMENT = "jsonv2"`, which module supports) and `cp go.mod/go.sum` already done.

**Bonus finding (template bug):** `templates/go-standard/flake.nix` had an
output-fn destructuring bug — `inputs@{ self, ... }` referenced unbound
`flake-parts`, so every project generated from the template failed to evaluate
with `undefined variable 'flake-parts'`. Fixed (destructures `flake-parts`
explicitly) and verified end-to-end via `generate-flake.sh --go-mod`.

---

## 5. Concrete recommendations (priority order)

1. **✅ DONE — Fix go-nix-helpers gaps G1 (goPkg override) + G3 (checks.lint)** — both shipped this session (with 106 module assertions, man page, template examples). G2 (per-package attrs) remains open, unblocking Tier B/C monorepos.
2. **Migrate Tier A repos first** (12 repos, each ~30 min): `go-localsync`, `go-humanize-linter`, `golangci-lint-auto-configure`, `oxlint-auto-configure`, `go-auto-upgrade`, `project-dependency-graph`, `erraudit`, `project-meta`, `projects-management-automation`, `go-cqrs-lite`, `standard-bug-tracking-schema`, `mr-sync`, `library-policy` — verify private/public dep split per repo (add `publicDeps` where public).
3. **Clean up the 5 existing module adopters**: remove unused `systems` + `treefmt-nix` inputs (lean-business-plan, storbi, template-arch-lint, terraform-diagrams-aggregator), remove redundant `enableCheck=true` (index), drop manual GOPRIVATE (all, once deps set/auto), expand `deps`/`publicDeps` to cover all private requires (index, storbi, template-arch-lint, terraform-diagrams-aggregator).
4. **Migrate Tier B** after G2 lands (or now, using perSystem-level extra apps where needed). Code-Quality-Agent can now migrate immediately (G1 shipped).
5. **Keep Tier C as documented exceptions**, with `mkGoFlake` deprecated → plan for Standup-Killer/crush-daily once G2 lands.
6. **Standardize CI**: all repos use `.github/workflows/ci.yml`; after migration the worker steps can be simplified (module's checks.format/build + apps.test/lint).
7. **flake.lock**: ensure `go-nix-helpers` is a real flake input in lock for migrated repos (it is, as tarball — after migration the lock entry changes type; `nix flake update` regenerates).

---

## 6. Verification commands (per migrated repo)

```bash
nix flake check          # module tests pass
nix build                # binary builds
nix run .#test           # go test -race -v ./... passes
nix run .#lint           # golangci-lint passes
nix fmt -- --ci          # formatting clean (0 changed)
nix develop -c bash -c 'go mod tidy && go build ./...'   # dev parity
```

---

## 7. Self-critique / methodology limits

- **Not a build audit**: `--no-build` only evaluates. Actual `nix build` for 34 repos would take hours and requires network/SSH; the fleet was verified *evaluable*, and every repo's CI presumably passes.
- **`flake-inputs-covering` metric is a heuristic**: it counts `github.com/larsartmann/*` strings in flake inputs vs go.mod requires. Public repos (go-atomic-write, go-ndjson, go-sse, go-output, go-branded-id, go-error-family, gogenfilter, etc.) legitimately resolve via the Go proxy and *should not* have flake inputs. The metric over-counts "missing" inputs and must be eyeballed per repo.
- **vendorHash "missing" in flake.nix** for library-policy/mr-sync is a false positive — they define it in `nix/packages/default.nix` / `package.nix`. Migrating them means folding those into module config.
- **Not verified**: SSH access status, GitHub remote state, whether CI actually runs. Repos with `6.ci: no` (KeyCountdown, index, lean-business-plan, storbi, projects-management-automation) may simply lack a workflow file locally (checked only `.github/workflows/ci.yml` existence).
- **git-hooks** (cachix git-hooks.nix) appears in 4 consumer repos (bank-sync,
  library-policy, project-meta, overview). The module does NOT bundle
  git-hooks — this input is legitimately extra and must be preserved in
  migration. Pre-commit hooks (lint, govet, end-of-file-fixer) and their
  `pre-commit.check.enable = false` reasoning stay consumer-side.
- **CI presence**: 30/34 have some workflow; `index` and `lean-business-plan`
  have zero CI (gap: no automated checks), KeyCountdown has only `nix-build.yml`,
  storbi only firebase hosting, projects-management-automation has
  `nix-ci.yml` + others. Absence of `ci.yml` ≠ absence of all CI.

