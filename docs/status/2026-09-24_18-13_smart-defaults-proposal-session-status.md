# Status Report — Smart-Defaults Design Session (go-nix-helpers)

- **Date:** 2026-09-24 18:13
- **Session scope:** Design exploration only — "How can we make go-nix-helpers SMARTER so downstream users need to do LESS?" No code was written or modified this session.
- **Previous report:** `docs/status/2026-09-24_16-51_gopkgattr-auto-default-and-master-repair.md` (goPkgAttr auto-default work — the direct predecessor of this proposal).

---

## a) FULLY DONE

All items below are research/verification work completed and verifiable in this session:

1. **Consumer-contract inventory** — Read `templates/go-standard/flake.nix` end-to-end; established exactly what a downstream user must write today: 3 inputs + `pname` + `vendorHash` + `description` (+ optional `deps`, `enableTempl`, `packages`).
2. **Full option/default inventory** — Enumerated all module options and defaults in `modules/go-standard.nix` (39 options). Confirmed what is ALREADY smart:
   - `version` defaults to `self.rev or self.dirtyRev or "dev"` (git-derived, not hardcoded)
   - `src` defaults to `self.outPath`
   - `goPkgAttr` defaults to auto-newest nixpkgs Go (shipped earlier today, prior session)
   - `systems` has a sane default; `GOPRIVATE` auto-injected when `deps` set; `GOTOOLCHAIN = "local"` in all devShells
   - `description` has a (generic) default: `"A LarsArtmann Go project"`
3. **Precedent verification for eval-time inference** — Confirmed `walkTempl` (modules/go-standard.nix:848) already walks the flake source at eval time for the `templ-committed` check. This is the established, `--no-build`-safe pattern new inference can build on.
4. **Pure-function inventory** — Confirmed `pure-functions.nix` exposes `stripVersionSuffix`, `repoName`, `newestGoAttrName` with a 41-assertion test harness — the designated home for new inference logic.
5. **Delivered the 5-tier "smart defaults" proposal** (the session's main deliverable):

   | # | Removes from consumer flake | Mechanism |
   |---|---|---|
   | 1 | `vendorHash` chore | eval-time `null` default when go.mod/go.sum has no external requires + `nix run .#update-vendor-hash` app (build → parse `got: sha256-…` → rewrite flake.nix) |
   | 2 | `deps = { … }` mirror attrset | auto-wire: parse private requires from go.mod, match repo name → flake input name; missing input → error naming the exact input line to add |
   | 3 | `pname` + `description` | `pname = repoName self`; description = first non-heading line of README.md |
   | 4 | `enableTempl = true` | detect `github.com/a-h/templ` in go.mod |
   | 5 | monorepo `packages = { … }` | auto-discover `cmd/*/main.go` → one package per binary |

   Plus guardrails (self-only reads → no IFD; explicit values always win; new logic → pure-functions + property tests) and the endgame sketch: a consumer flake reduced to inputs + `imports` + one `vendorHash` line.
6. **Recommendation given:** ship #1 + #2 together (Pareto: ~80% of recurring friction), #3/#4 quick follow-up, #5 last.

**Evidence:** all reads done via `view`/`rg` this session (files and line numbers cited above). No commits — zero code changes.

## b) PARTIALLY DONE

1. **Tier-1 proposal feasibility (vendorHash + deps auto-wire)** — designed and sketched, but **two load-bearing assumptions remain unverified**:
   - Open: does flake-parts pass `inputs` as a module argument to imported modules? (Asserted in the proposal, NOT verified in flake-parts source. If false, proposal #2 needs a different wiring channel, e.g. an explicit `inputs` passthrough option.) Effort to verify: S.
   - Open: does an update-vendor-hash-style app already exist in the module's `apps` output? I never enumerated the current `apps` section — the proposal may duplicate an existing helper. Effort: S.
   - Blocker for starting implementation: user decision (see questions) + the two verifications above.
2. **Tier-2/3 proposals (pname/description/templ/monorepo)** — designed at sketch level only; no data-shape decisions made (e.g. how monorepo auto-discovery merges with explicit `packages`, whether `preBuild templ generate` ordering vs `mkPreparedSource` postPatch needs care — flagged in session, unresolved).

## c) NOT STARTED

All implementation, intentionally deferred pending user go-ahead:

1. `privateRequiresFromGoMod` pure function + property tests (proposal #2 core)
2. go.sum/go.mod eval-time read → `vendorHash = null` auto-default (proposal #1a)
3. `apps.update-vendor-hash` hermetic script (proposal #1b)
4. `pname = repoName self` default (proposal #3)
5. README-first-paragraph description default (proposal #3)
6. templ auto-detect from go.mod (proposal #4)
7. `cmd/*` monorepo auto-discovery walker (proposal #5)
8. Helpful-error machinery ("add input `go-cqrs-lite`" on missing match)
9. Module tests for all of the above (`test-module.nix`, currently 121 assertions)
10. Template + README + migration-guide + man-page updates for new defaults
11. Any consumer-repo rollout (7+ consumers)

## d) TOTALLY FUCKED UP

No code, builds, or tests were touched this session, so nothing is broken **in the repo**. Radical honesty about what *I* got wrong in the analysis itself:

1. **Unverified claim shipped as fact:** I told you "flake-parts modules receive `inputs`" — I never opened flake-parts source or a consumer module to confirm. That is the single load-bearing assumption of proposal #2. Severity: proposal-invalidating if wrong (though a passthrough option is a workable plan B). Root cause: pattern-matching on familiarity instead of verifying. Mitigation: one `rg "inputs"` against a consumer flake-parts module / flake-parts lib before any implementation.
2. **Didn't check for an existing vendor-hash helper** in the module's apps before proposing to add one — possible duplication. Root cause: stopped the options inventory at `mkOption` lines and never read the output-assembly section.
3. **BuildFlow overlap unscoped:** the BuildFlow skill (Lars's ecosystem) already orchestrates vendorHash fixes for covered projects. I proposed a competing/duplicating app without checking where its jurisdiction ends. A second auto-fixer risks two tools rewriting the same hash with different mental models.
4. **Impact estimated, not measured:** "~80% of friction" was asserted without reading even one of the 7+ consumer repos to count lines removed. Could be right, could be half.

## e) WHAT WE SHOULD IMPROVE

1. **Verify feasibility claims before presenting proposals** — this session presented a ranked plan with an unverified core assumption flagged nowhere until this report. Fix: any proposal naming a mechanism must cite the file/line that proves the mechanism exists. (Recurring theme: this is the exact failure mode `verify-external-claims` exists for — apply it to internal claims too.)
2. **Quantify DX claims against real consumers** — the repo has 7+ known consumers (BuildFlow, mr-sync, PMA, go-structure-linter, branching-flow, Standup-Killer, library-policy). A 20-minute audit of their `go-standard` blocks would turn "less to do" into "N lines deleted across M repos." Also produces the rollout checklist for free.
3. **Jurisdiction map for vendorHash** — one paragraph in go-nix-helpers README (or BuildFlow docs) declaring who owns vendorHash refresh when both tools see the same repo. Prevents split-brain fixing.
4. **Inference observability** — once defaults become smart, consumers need to see what was inferred and why. Plan a `nix run .#doctor` (or trace option) printing: resolved pname/version/description/goPkg, deps wiring decisions, tool detection results, vendorHash source. Cheap to build alongside #2/#3, expensive to retrofit.
5. **Inference policy should be decided once, not per-feature** — default-on vs opt-in gate applies to all 5 proposals; deciding it per PR invites inconsistency.
6. **Harvest discipline** — section (f) below is HARVEST fuel for TODO_LIST/ROADMAP; this report intentionally does not touch those files (user said WAIT).

## f) Next tasks (ranked, up to 50)

### P1 — unblock tier 1 (verifications + decisions)

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 1 | Verify flake-parts passes `inputs` to imported modules (read flake-parts lib or a consumer module) | Critical | S | Research |
| 2 | Enumerate current `apps` output of go-standard; confirm no existing vendor-hash updater | Critical | S | Research |
| 3 | User decision: BuildFlow overlap policy for vendorHash app (question g1) | Critical | S | Decision |
| 4 | User decision: inference default-on vs opt-in gate (question g3) | Critical | S | Decision |
| 5 | Audit 7+ consumer repos' go-standard blocks; quantify lines removable per proposal | High | M | Research |
| 6 | Design: how auto-wired deps report themselves (trace/doctor) so failures are debuggable | High | S | Design |

### P2 — implement tier 1 (vendorHash + deps auto-wire)

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 7 | `privateRequiresFromGoMod` pure function (parse go.mod requires matching privateDepPattern, minus publicDeps) | High | M | Feature |
| 8 | Property tests for #7 in `test-pure-functions.nix` (idempotence, /vN paths, publicDeps exclusion, malformed go.mod) | High | M | Quality |
| 9 | Input-name→repo-name matching pure function + "add input X" error message generator | High | S | Feature |
| 10 | Wire auto-deps into module: `deps` defaults derive from inputs × go.mod; explicit `deps` wins entirely | High | M | Feature |
| 11 | Eval-time go.mod/go.sum read → `vendorHash` default `null` when no external requires | High | S | Feature |
| 12 | `apps.update-vendor-hash`: hermetic build→parse→rewrite script (writeShellScriptBin, no @latest/network tricks) | High | M | Feature |
| 13 | Test: moduleTest assertions for auto-deps (wired, missing-input error, explicit-override wins) | High | M | Quality |
| 14 | Test: integration scenario in `test.nix` for auto-wired deps + null vendorHash path | High | M | Quality |
| 15 | Docs: README + man page + migration guide for both features | High | S | Documentation |
| 16 | Roll out to 1 pilot consumer; measure flake.nix line delta; then remaining consumers | High | M | Feature |

### P3 — implement tier 2 (identity + tool defaults)

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 17 | `pname` default = `repoName self` (store-path base name); test dirty-tree case | Medium | S | Feature |
| 18 | `description` default = first non-heading README line, with pathExists guard + fallback | Medium | S | Feature |
| 19 | templ auto-detect: go.mod requires `github.com/a-h/templ` → enableTempl default true | Medium | S | Feature |
| 20 | Verify/spec `preBuild templ generate` ordering vs mkPreparedSource `postPatch` before any templ magic beyond detection | Medium | S | Design |
| 21 | Tests + docs for #17–#19 | Medium | M | Quality |
| 22 | Extend template `templates/go-standard/flake.nix` to the endgame 3-line form once tiers land | Medium | S | Documentation |

### P4 — implement tier 3 (monorepo + observability)

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 23 | Generalize `walkTempl` into a reusable source walker (files by predicate, excludes testdata/vendor/example) | Medium | M | Refactor |
| 24 | `cmd/*/main.go` discovery → default `packages` entries; define merge semantics with explicit `packages` | Medium | M | Feature |
| 25 | `subPackages` smart default (root main.go vs single cmd/ vs multi) | Medium | M | Feature |
| 26 | `nix run .#doctor` app or `go-standard.traceInferences` option summarizing every inference | Medium | M | Feature |
| 27 | Tests for monorepo discovery (mock fixtures exist under test-assets/) | Medium | M | Quality |

### P5 — hygiene noticed this session (from git snapshot + AGENTS.md, no new research)

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 28 | `.github/dependabot.yml` was untracked at session start — confirm it's committed and CI sees it | Medium | S | Cleanup |
| 29 | Working tree had 6 modified files at session start (AGENTS.md, README.md, 2 status docs, flake.lock, mock-project asset) — confirm auto-commit daemon captured them sanely | Medium | S | Cleanup |
| 30 | Register `maintainers.larsartmann` in nixpkgs (long-standing AGENTS.md gotcha) | Low | M | Quality |
| 31 | Remove deprecated `mkGoFlake.nix` + its trace warning after last consumer migrates | Low | M | Cleanup |
| 32 | Remove deprecated `templates/go-flake-parts/` (same condition) | Low | S | Cleanup |
| 33 | Run HARVEST of section (f) into TODO_LIST.md / ROADMAP.md once user approves | Medium | S | Documentation |

## g) Questions I cannot answer myself

1. **vendorHash jurisdiction:** BuildFlow already orchestrates vendorHash fixes for covered repos. Should go-standard still ship `apps.update-vendor-hash` for non-BuildFlow consumers (overlap accepted), or should hash-refresh stay BuildFlow-exclusive to avoid two competing fixers? (I checked the BuildFlow skill description only — its exact coverage boundary is not something I can grep from this repo.)
2. **Naming-convention strictness for auto-wired deps:** auto-wiring requires input name == repo name (e.g. input `go-cqrs-lite` ↔ `github.com/LarsArtmann/go-cqrs-lite`). Make that a REQUIRED convention (simple, may break consumers with custom input names) or support an alias map (`depsAliases = { … }`) as escape hatch?
3. **Inference policy:** default-on smart defaults (explicit values override) or an opt-in gate like `go-standard.autoInfer = true` for a transition release? This is a risk-appetite call affecting all 5 proposals at once.

---

**NOW WAITING FOR INSTRUCTIONS.**
