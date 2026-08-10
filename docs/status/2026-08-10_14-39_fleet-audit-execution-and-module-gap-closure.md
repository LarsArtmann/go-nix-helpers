# Status Report: Fleet Audit Execution & Module Gap Closure

**Date:** 2026-08-10 14:39
**Session scope:** Execute the consumer fleet audit (all Go repos), fix go-standard module gaps surfaced by the audit, fix self-identified bugs, cross-link docs.
**Commit:** `26b7620` (auto-committed by daemon — 10 files, +404/-32 lines)

---

## A) FULLY DONE ✅

### 1. Fleet-wide audit executed (34 consumer repos)
- Read **every** `flake.nix` of all 34 repos referencing `go-nix-helpers` under `/home/lars/projects/`
- Ran the triage script (`docs/consumer-audit-checklist.md`) across all 34
- Ran a deep 8-section audit script capturing: module adoption, input minimalism, follows chains, placeholder vendorHash, private requires vs. flake inputs coverage, manual GOPRIVATE, publicDeps, stale replaces, redundant overrides, CI presence, flake.lock hygiene, migration status, and special signals (allowUnfree, GOEXPERIMENT, custom Go, nixosModules)
- Spot-checked `nix flake check --no-build` on representative repos (bank-sync, Standup-Killer, storbi, lean-business-plan) — all pass
- Categorized all 34 repos into migration tiers (A/B/C) with per-repo findings
- Wrote `docs/status/2026-08-10_11-02_consumer-fleet-audit.md` (177 lines) with:
  - Executive summary (5/34 on module, 27/34 legacy manual, 2/34 deprecated mkGoFlake)
  - 3 migration tiers with per-repo notes
  - 5 module adopter quality reviews (index, lean-business-plan, storbi, template-arch-lint, terraform-diagrams-aggregator)
  - Systemic findings (3 high, 4 medium, 3 low)
  - 5 module gaps (G1-G5) with affected repos
  - 7 prioritized recommendations
  - Self-critique section documenting methodology limits

### 2. Module gaps G1 + G3 closed
- **G1 (`goPkgOverride`)**: new option — function applied to the Go package from `goPkgAttr`. Unblocks Code-Quality-Agent (custom Go 1.26.4 from source). Default is identity. Wired through packages, devShells, and lint check. Test assertions verify propagation to both package derivation and devShell nativeBuildInputs.
- **G3 (`lintAsCheck`)**: new option (default: false) — exposes golangci-lint as a hermetic `checks.lint` derivation for `nix flake check`-driven CI. Gated on `enableGolangciLint` (won't generate if linter disabled). Test assertions verify: absent by default, present when enabled, apps.lint still coexists.
- Module test suite deepened from 99 → **106 assertions** (all pass)
- Options count updated throughout docs: 35 → 37

### 3. Template bug discovered and fixed
- **`templates/go-standard/flake.nix` had a broken output function**: `inputs@{ self, ... }` referenced unbound variable `flake-parts` (called `flake-parts.lib.mkFlake`). Every project generated from this template via `generate-flake.sh` would fail to evaluate with `undefined variable 'flake-parts'`.
- Fixed: destructures `flake-parts` explicitly (`inputs@{ self, flake-parts, ... }`)
- **Verified end-to-end**: generated a test project with `generate-flake.sh --go-mod`, confirmed `nix flake check --no-build` passes on the output

### 4. Template enriched with examples
- Added commented examples for: monorepo (`packages` option), `goPkgOverride`, `lintAsCheck`
- Complements the private deps + `publicDeps` examples added in prior commit (`0fd6d7c`)

### 5. Triage script bugs fixed
- **POSIX grep bug**: `\s` (Perl regex) → `[[:space:]]` in redundant-override detection — on POSIX-only grep this silently failed to match
- **Fragile two-pass awk**: consolidated into a single awk pass with explicit WARN marker for flake-false detection
- **Tested against go-nix-helpers' own flake.nix**: script runs clean, produces correct output

### 6. CHANGELOG repaired
- **Duplicate `### Added` sections** under `[Unreleased]` (lines 13 and 167 in prior version) — merged into a single Added section with correct ordering (Added → Changed → Deprecated → Fixed → Removed)
- Added entries for: audit report, `goPkgOverride`, `lintAsCheck`, template bugfix, triage script fix, cross-linking, man page updates
- Content preserved: 125 → 132 bullets (+7 new, 0 lost)

### 7. Documentation cross-linked
- `docs/migration-guide.md`: added post-migration verification section pointing to the checklist
- `AGENTS.md`: added `docs/consumer-audit-checklist.md` to key files table, updated option count (37), assertion count (106)
- `README.md`: added `goPkgOverride` and `lintAsCheck` to options table
- `docs/man/go-standard.5`: documented both new options + `checks.lint` output

### 8. Full verification
- `nix flake check` — all 8 checks pass (autoDiscovery, explicitOnly, verify, moduleTest, moduleTestNoOverlay, pureFunctions, structural, treefmt)
- `nix fmt` — 0 files changed (clean)
- Template eval — passes in isolation
- `generate-flake.sh --go-mod` — output project evaluates

---

## B) PARTIALLY DONE ◑

### 1. `lintAsCheck` gating test missing
The module gates `checks.lint` on `enableGolangciLint` (line 666: `lib.optionalAttrs (cfg.lintAsCheck && cfg.enableGolangciLint)`), but there is **no test assertion** verifying the gating behavior (i.e. "lintAsCheck=true + enableGolangciLint=false → no checks.lint"). The assertion was drafted in the session (`test-module.nix` edit) but the auto-commit daemon fired before it was saved. The module is correct; the test coverage is incomplete by exactly 1 assertion.

### 2. Consumer audit is a report, not a fix
The audit identified 34 repos and their specific issues, but **zero consumer repos were actually migrated or fixed**. The report is comprehensive and actionable, but no migration was executed. This is by design (the user asked for a review, not a fix sprint), but it means the "superb usage" bar is documented-but-unmet for 29/34 repos.

### 3. Module gap G2 (per-package extraBuildAttrs) not started
The audit identified that monorepo `packages` entries can't carry custom `preBuild`/`postInstall`/`env` per binary — affecting StopTube, browser-history, BuildFlow, go-structure-linter. This was documented as "❌ Open" in the report but no implementation was started.

### 4. TODO_LIST.md not updated
The "BLOCKED" audit item in `TODO_LIST.md` still says "Requires access to 7+ downstream repos" — but the audit is now done (34 repos found and audited). The item should be marked complete or updated with the migration workload.

---

## C) NOT STARTED ⬜

1. **Actual consumer repo migrations** (0 of 34 repos migrated)
2. **Module adopter cleanups** (5 repos need unused inputs removed, redundant overrides cleaned, deps expanded)
3. **G2 implementation** (per-package extraBuildAttrs in monorepo `packages`)
4. **G5 implementation** (multi-binary subPackages with different flags — blocked by G2)
5. **CI standardization** across consumer repos (30/34 have some CI, but formats vary wildly)
6. **flake.lock freshness** audit across consumer repos (not checked)
7. **`maintainers.larsartmann` nixpkgs registration** (external PR, mentioned in prior reports)

---

## D) TOTALLY FUCKED UP 💥

### 1. The template bug was pre-existing since `9471741` (the initial go-standard commit)
`templates/go-standard/flake.nix` had `inputs@{ self, ... }` calling `flake-parts.lib.mkFlake` since the template was first created. **Every project generated from the go-standard template would have failed to evaluate.** This went undetected because:
- The module's own CI doesn't test template output
- `generate-flake.sh` doesn't eval-check its output
- The 5 repos that adopted the module (index, lean-business-plan, storbi, template-arch-lint, terraform-diagrams-aggregator) were hand-written or adapted, not generated from the template
- No one ran `nix flake check` on a freshly generated project

**Impact**: unknown how many projects were generated and silently broken. The template is the recommended starting point for new LarsArtmann Go projects. This is a "silently wrong" bug — the kind that corrupts trust in the tooling.

### 2. The auto-commit daemon committed mid-edit
I was adding a test assertion for the `lintAsCheck` gating behavior when the daemon fired (`26b7620`). The module gating fix was captured (it was saved first), but the test assertion was not. This left a coverage gap: the code has a conditional gate with no test. Not a bug per se, but a process failure — I should have batched the edits or been aware of the daemon timing.

### 3. The deep audit script's `flake-inputs-covering` metric was misleading
The metric counted `github.com/larsartmann/*` strings in flake.nix vs go.mod, flagging "uncovered" requires. But many LarsArtmann repos are **public** (go-atomic-write, go-ndjson, go-sse, go-output, go-branded-id, go-error-family, gogenfilter) and legitimately resolve via the Go proxy without flake inputs. The metric over-counted "missing" inputs and required manual eyeballing. This was documented in the self-critique, but the audit report's per-repo data still shows raw numbers that could mislead a casual reader.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Process
1. **Template CI**: add a check that evaluates a freshly-generated project from each template. The template bug would have been caught on day 1.
2. **Batch edits before daemon fires**: when adding code + tests for a feature, save both files before the daemon's next poll cycle, or disable the daemon during multi-file logical units.
3. **Audit metric accuracy**: the triage script should cross-reference `publicDeps` and known-public repo lists before flagging "uncovered" requires as issues.

### Module
4. **G2 (per-package attrs)** is the remaining blocker for 4+ monorepo repos. Extending the `packages` submodule with the same `extraBuildAttrs` surface would unblock StopTube, browser-history, BuildFlow migration.
5. **`checks.test` not provided by module**: most consumers hand-write a `checks.test = config.packages.default.overrideAttrs { doCheck = true; }`. The module could provide this as an option (`enableTestCheck` or fold into `enableCheck`).
6. **`overrideModAttrs` user escape hatch**: while G4 was found to be a non-issue (module's autoDepFodAttrs is equivalent), there's no way for a consumer to override the FOD phases if they truly need different behavior. The `extraBuildAttrs` `//`-merge happens before `autoDepFodAttrs`, so user values get overwritten.

### Audit follow-through
7. **The audit identified 22 repos with manual GOPRIVATE** — after migration these become dead config. A migration sprint should batch-remove them.
8. **4 repos re-instantiate nixpkgs** for `allowUnfree` — the module could provide an `allowUnfree` option to avoid this.
9. **29 repos declare `go-nix-helpers` with `flake = false`** — all need `flake = false` removed + `inputs.nixpkgs.follows = "nixpkgs"` added for migration.

---

## F) Up to 50 things to do next

### Immediate (this session's loose ends)
1. Add the missing `lintAsCheck` gating test assertion to `test-module.nix` (1 line)
2. Update `TODO_LIST.md`: mark audit item as DONE, add migration sprint items
3. Run `nix flake check` to verify after test addition

### Module improvements
4. Implement G2: per-package `extraBuildAttrs` in monorepo `packages` submodule
5. Add `allowUnfree` option to go-standard (avoids nixpkgs re-instantiation in 4 repos)
6. Add `enableTestCheck` option or auto-generate `checks.test` when `enableCheck = true`
7. Add user escape hatch for `autoDepFodAttrs` override (edge case)
8. Add `pre-commit` (git-hooks) optional bundling (4 repos use git-hooks.nix)

### Consumer migrations — Tier A (straightforward, ~30 min each)
9. Migrate `go-localsync` (237 lines → ~20 lines)
10. Migrate `go-humanize-linter` (286 lines)
11. Migrate `golangci-lint-auto-configure` (233 lines)
12. Migrate `oxlint-auto-configure` (196 lines)
13. Migrate `go-auto-upgrade` (541 lines)
14. Migrate `project-dependency-graph` (230 lines)
15. Migrate `erraudit` (257 lines)
16. Migrate `project-meta` (268 lines)
17. Migrate `projects-management-automation` (267 lines)
18. Migrate `standard-bug-tracking-schema` (386 lines)

### Consumer migrations — Tier B (modest complexity)
19. Migrate `KeyCountdown` (250 lines)
20. Migrate `StopTube` (262 lines)
21. Migrate `branching-flow` (328 lines)
22. Migrate `browser-history` (600 lines, needs G2)
23. Migrate `overview` (468 lines, needs G2)
24. Migrate `bank-sync` (515 lines, allowUnfree)
25. Migrate `BuildFlow` (1215 lines, needs G2)

### Consumer migrations — Tier C (needs module work first)
26. Migrate `Standup-Killer` off deprecated `mkGoFlake` (needs G2 for subModules)
27. Migrate `crush-daily` off deprecated `mkGoFlake` (needs G2)
28. Migrate `Code-Quality-Agent` (G1 shipped — can migrate now)
29. Migrate `go-structure-linter` (needs G2 for multi-module postPatchExtra)
30. Migrate `file-and-image-renamer` (needs deps audit first)
31. Migrate `library-policy` (139 lines, but uses nix/* submodules)
32. Migrate `mr-sync` (252 lines, own package.nix)
33. Migrate `go-cqrs-lite` (1224 lines! monorepo library)
34. Migrate `DiscordSync` (725 lines, many pinned revs)
35. Migrate `github-local-sync` (279 lines, allowUnfree)

### Module adopter cleanups
36. `lean-business-plan`: remove unused `systems` + `treefmt-nix` inputs
37. `storbi`: remove unused inputs + expand deps for 4th private require
38. `template-arch-lint`: remove unused inputs + verify private requires
39. `terraform-diagrams-aggregator`: remove unused inputs + expand publicDeps
40. `index`: remove `enableCheck=true` + expand deps/publicDeps

### CI and infrastructure
41. Add template-output CI check (evaluate freshly generated project)
42. Standardize CI workflow across migrated repos
43. Add `flake.lock` freshness check to consumer repos
44. Add `index` and `lean-business-plan` CI (currently zero CI)

### Documentation
45. Document the public/private LarsArtmann repo split (which are proxy-served vs SSH-only)
46. Add migration "recipe" per tier (copy-paste before/after for common patterns)
47. Update `docs/flake-patterns.md` with `goPkgOverride` and `lintAsCheck` patterns

### External
48. Register `maintainers.larsartmann` in nixpkgs
49. Tag go-nix-helpers repo for versioned consumer pinning
50. Create mock Go project for E2E consumer CI test

---

## G) Questions I cannot figure out myself ❓

### 1. Should I migrate consumer repos in-place, or produce per-repo migration PRs?

The audit found 34 consumer repos, 29 of which need migration. Migrating them
in-place (editing each repo's `flake.nix` directly) is fastest but:
- Changes vendorHash (module changes how deps are prepared)
- Requires running `nix build` per repo to get the new hash (needs SSH access
  to private repos)
- May break CI until the lock file updates

Alternatively, I can produce per-repo migration branches/PRs. **Which approach
do you want?** And do you want me to start with Tier A (straightforward) or
prioritize the deprecated `mkGoFlake` repos (Standup-Killer, crush-daily)?

### 2. Is the auto-commit daemon's commit message quality acceptable?

The daemon committed my work as `26b7620` with a detailed multi-paragraph
message. The message is accurate and well-structured, but I didn't write it —
the daemon did. Should I treat daemon commits as authoritative, or should I
amend/re-commit with my own message after logical units of work?

### 3. Which LarsArtmann repos are genuinely private (SSH-only) vs public (proxy-served)?

The audit's "uncovered requires" metric is unreliable because I don't have a
definitive list. From reading consumer flakes, I inferred these are **public**
(resolve via proxy.golang.org): `go-atomic-write`, `go-ndjson`, `go-sse`,
`go-output`, `go-branded-id`, `go-error-family`, `gogenfilter`, `go-etag`,
`go-idempotency`, `go-retry`, `go-composable-business-types`, `go-health`.
And these are **private** (need flake input + replace): `go-cqrs-lite`,
`go-finding`, `httputil`, `project-discovery-sdk`, `cmdguard`, `cqrs-htmx`,
`templ-components`, `samber-do-auditlog`, `go-workflow-auditlog`,
`go-filewatcher`, `go-linter-sdk`, `licenseforge`, `go-must`, `go-dag-app`,
`go-policy-dsl`, `go-localsync`, `go-commit`, `go-datastar`,
`go-health-dashboard`, `go-website-template`, `go-wizard-sdk`,
`go-business-rules`, `go-checker-helpers`, `go-composable-business-types`.
**Is this split correct?** A definitive list would make the audit metric
reliable and speed up migrations enormously.

---

_Arte in Aeternum_
