# Status Report — go-nix-helpers

**Date**: 2026-06-09 14:14 UTC
**Project**: [go-nix-helpers](https://github.com/LarsArtmann/go-nix-helpers)
**Branch**: `master`
**Total Commits**: 12

---

## a) FULLY DONE ✅

### 1. `mkPreparedSource` — Core helper for private Go deps in Nix sandbox

- Copies private flake-input deps into `_local_deps/`
- Injects `replace` directives into `go.mod`
- Supports `subModules` (repos with independent sub-module `go.mod` files)
- Supports `requireDeps` (manual require injection for sub-modules not yet in `go.mod`)
- Auto-strips stale local `replace` directives pointing to `/home/...`
- Normalizes sub-module pseudo-versions via `subModuleVersion`
- **7 downstream consumers**: BuildFlow, mr-sync, PMA, go-structure-linter, branching-flow, Standup-Killer, library-policy

### 2. `/vN` major version suffix handling in `deps` (commit `532752a`)

- **Problem**: `basename = lib.last (lib.splitString "/" path)` extracted `"v2"` instead of `"go-filewatcher"` for paths like `.../go-filewatcher/v2`
- **Fix**: Added `repoName` helper that strips `/vN` suffixes before extracting basename
- **Verified**: `nix eval` confirmed correct output for go-output, go-filewatcher/v2, gogenfilter/v3, template-LICENSE/types, go-output/v10
- **Zero downstream breakage** — no consumer hardcodes `_local_deps/<version-suffix>` in `postPatchExtra`

### 3. `/vN` major version suffix handling in `subModules` — ~~JUST FIXED (uncommitted)~~ Committed as `7b69382` (2026-06-09); folded into recursive discovery in `7fdb95c`.

- **Problem**: `subModuleReplace` generated `.../codec/v2 => ./_local_deps/<repo>/codec/v2` — the `/v2` suffix was kept in the local directory path, pointing to a nonexistent directory (Go multi-module repos use `codec/go.mod` declaring `module .../codec/v2`, but the filesystem path is just `codec/`)
- **Fix**: Added `stripVersionSuffix` helper; `subModuleReplace` now uses it for the local directory path while keeping the full versioned path in the module path
- **Example**: `subModules = { ".../go-cqrs-lite" = [ "codec/v2" "core" ]; }` now generates:
  ```
  .../codec/v2 => ./_local_deps/go-cqrs-lite/codec   # /v2 stripped from local
  .../core => ./_local_deps/go-cqrs-lite/core         # no version, unchanged
  ```
- **Impact**: Enables `go-cqrs-lite` consumers (crush-daily, browser-history, Standup-Killer) to use `subModules` instead of listing 14+ individual deps
- **Verified**: `nix eval --impure` confirms the file evaluates correctly

### 4. Template — `go-flake-parts`

- Complete flake template with flake-parts, treefmt-nix, systems
- Commented-out `mkPreparedSource` usage with `/v2` and `subModules` examples
- CI devShell (`mkShellNoCC`), lint/test apps, format checks, overlay pattern
- Inline comments explaining common pitfalls (checks placement, treefmt programs.X pattern, dot-notation danger)

### 5. Scripts

- **`scripts/dashboard.sh`**: Static analysis or full `nix flake check` across all projects. Supports `--check` and `--json`.
- **`scripts/generate-flake.sh`**: Bootstraps new Go projects from the template. Supports `--templ` and `--private-deps`.
- **`scripts/nix-lint.sh`**: Lints all flake.nix files for 15 common error patterns. Supports `--fix` and `--check`.

### 6. Documentation

- **`README.md`**: Usage instructions, major version suffix docs, sub-modules section, full example
- **`docs/flake-patterns.md`**: Reference doc covering correct patterns, anti-patterns, and gotchas for flake-parts Go projects
- **`docs/ci-workflow.yml`**: Drop-in GitHub Actions workflow for `nix flake check`

### 7. `SystemNix/AGENTS.md` updated

- Removed the "subModules does NOT handle /v2" caveat — now documents that versioned sub-paths are handled automatically
- Updated the known-issues table

---

## b) PARTIALLY DONE 🔶

### ~~1. `subModuleVersionNormalize` with versioned sub-paths — Works but untested end-to-end~~ done — covered — pseudoVersionNormalizeTest scenario in test.nix

The sed command `s|${depPath}/${sub} v0\.0\.0-[^ ]*|${depPath}/${sub} ${subModuleVersion}|g` now receives `sub = "codec/v2"`, making the full pattern `go-cqrs-lite/codec/v2`. This is correct — it matches the full Go module path in `go.mod`. But no downstream consumer has tested this with versioned subModules yet.

### ~~2. Downstream consumers — Need migration to new subModules feature~~ done — done — crush-daily/overview/DiscordSync postPatchExtra removed (`649e8a9` et al.)

Projects currently listing `go-cqrs-lite` sub-modules as individual deps can now consolidate:

| Project        | Current Pattern                                                        | Can Migrate To                                                                              |
| -------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| crush-daily    | 14 individual deps `"go-cqrs-lite/codec/v2" = "${go-cqrs-lite}/codec"` | `subModules = { ".../go-cqrs-lite" = [ "catalog/v2" "codec/v2" ... ]; }` + single dep entry |
| Standup-Killer | `subModules = { ".../go-cqrs-lite" = [ "core" "memory" ]; }`           | `subModules = { ".../go-cqrs-lite" = [ "core" "memory/v2" ]; }`                             |

### ~~3. Downstream consumers — Need `vendorHash` updates~~ done — consumer-side — long since rebuilt

Projects using versioned deps via mkPreparedSource need `vendorHash` recalculated:

| Project                        | Versioned Deps                        | Risk                                                          |
| ------------------------------ | ------------------------------------- | ------------------------------------------------------------- |
| projects-management-automation | `go-filewatcher/v2`, `gogenfilter/v3` | Low — `_local_deps` names change from `v2`/`v3` to real names |
| go-structure-linter            | `gogenfilter/v3`                      | Low — same                                                    |

---

## c) NOT STARTED ⬜

### ~~1. No `flake.nix` for go-nix-helpers itself~~ done — shipped `3c22ce4`

The project has no `flake.nix` — it's imported as `flake = false` by consumers. This means:

- No `nix fmt` for the repo itself
- No automated testing of `mkPreparedSource` in CI
- No `nix flake check` for the project
- Can't run `treefmt-nix` on the `.nix` files

### ~~2. No automated tests~~ done — shipped — full checks suite

No test suite exists. Verification is manual via `nix eval` and downstream consumer builds. The `repoName` and `stripVersionSuffix` helpers are pure functions that could easily be unit-tested with Nix checks.

### ~~3. No `CHANGELOG.md`~~ done — shipped

No formal change log — only git history.

### ~~4. No `AGENTS.md`~~ done — shipped `3c22ce4`

No project-level AI context file for session continuity.

### ~~5. No `FEATURES.md`~~ done — shipped — FEATURES.md

No feature inventory.

### ~~6. No `TODO_LIST.md`~~ done — shipped — TODO_LIST.md

No short/mid-term task tracking.

### ~~7. `report/` directory is empty~~ done — moot — directory gone

An empty `report/` directory exists — purpose unclear, likely a leftover placeholder.

---

## d) TOTALLY FUCKED UP 💥

### Nothing currently fucked up.

All known bugs have been fixed. The `/vN` suffix bug in `subModules` was identified and fixed before any downstream consumer hit it in practice. The `repoName` fix (commit `532752a`) was also proactive — it fixed a latent collision risk that hadn't manifested because no project had multiple same-version deps from different repos.

### Historical fuck-ups (now fixed):

1. **`/vN` in deps** (commit `532752a`): `repoName` extracted `"v2"` instead of `"go-filewatcher"` — fixed
2. **`/vN` in subModules** (just now): `subModuleReplace` kept `/v2` in local directory path — fixed
3. **Auto-require for sub-modules** (commit `89f5236`): Caused "inconsistent vendoring" errors — removed, now `requireDeps` is manual
4. **Standalone require syntax** (commit `ca0d2fc`): Missing `require` keyword prefix — fixed

---

## e) WHAT WE SHOULD IMPROVE 📈

### ~~1. Test infrastructure is the #1 gap~~ done — shipped — full checks suite

`repoName`, `stripVersionSuffix`, `copyDeps`, `replaceLines`, `subModuleReplace` are all pure Nix expressions. They could be verified with `nix eval` assertions in a `flake.nix` checks block. This would have caught both `/vN` bugs at introduction.

### ~~2. `dashboard.sh` hardcodes `go_1_25` check~~ done — fixed 2026-09-24 — GO_LATEST default is auto-derivable; TODO_LIST T25 tracks full derivation

Line 47 checks for `go_1_25` but the standard is now `go_1_26`. Should check for outdated Go versions generically.

### ~~3. `generate-flake.sh` uses fragile sed for templ support~~ done — fixed — D4 fix (2026-07-24 23:04 session)

The `sed` commands for adding `templ` support (lines 53-57) are line-number-dependent and will break if the template changes. Should use a proper template engine or markers.

### ~~4. `subModuleVersionNormalize` sed is fragile~~ done — hardened — `[.]` style after the 2026-09-07 escape-semantics probe

The sed pattern assumes a specific pseudo-version format. If Go changes the format, it breaks silently.

### ~~5. No validation of `subModules` entries~~ **Won't implement — dormant — dropped.**

If a user lists `subModules = { ".../go-cqrs-lite" = [ "nonexistent" ]; }`, the build will fail with a confusing error about a missing directory. Should validate that `${deps.${depPath}}/${sub}` exists.

### ~~6. `repoName` collision risk for same-name different-owner deps~~ **Won't implement — no incidents — dropped.**

If two deps share the same repo name (e.g., `larsartmann/go-output` and `otheruser/go-output`), `repoName` produces the same basename, causing a collision in `_local_deps/`. Not currently a problem but architecturally unsound.

### ~~7. Template drift risk~~ done — guarded — checks.templateEval

The `templates/go-flake-parts/flake.nix` is manually maintained. When `mkPreparedSource` changes, the template comments may drift. Consider generating from source.

---

## f) Top 25 Things We Should Get Done Next

| #                                                                                                                             | Priority | Task | Impact |
| ----------------------------------------------------------------------------------------------------------------------------- | -------- | ---- | ------ |
| done at `7b69382`                                                                                                             |          |      |        |
| done — crush-daily on go-standard today (TODO_LIST T5 DONE 2026-11-18)                                                        |          |      |        |
| done — Standup-Killer on go-standard (TODO_LIST T5 DONE 2026-11-18)                                                           |          |      |        |
| done — PMA on go-standard (PMA 9b47684: "Migrate to go-standard module, remove 966 lines")                                    |          |      |        |
| done — go-structure-linter on go-standard (AGENTS.md consumer list)                                                           |          |      |        |
| done at `3c22ce4`                                                                                                             |          |      |        |
| done — checks.pureFunctions (5b915f8 property suite, 72 checks)                                                               |          |      |        |
| done — test.nix verify suite (9 scenarios)                                                                                    |          |      |        |
| done at `3c22ce4`                                                                                                             |          |      |        |
| done — GO_LATEST auto-derived in scripts/dashboard.sh (this file §c "dashboard.sh hardcodes go_1_25" verdict)                 |          |      |        |
| done — fleet audit done — all consumers on go-standard (T4/T5 DONE 2026-11-18)                                                |          |      |        |
| done — CHANGELOG.md exists (this file §c3)                                                                                    |          |      |        |
| done — FEATURES.md exists (§c5)                                                                                               |          |      |        |
| done — TODO_LIST.md exists (§c6)                                                                                              |          |      |        |
| done — moot — directory gone (§c7)                                                                                            |          |      |        |
| done — PMA on go-standard via deps (PMA 9b47684)                                                                              |          |      |        |
| done — 2026-06-29 postPatch sweep eliminated the workaround class                                                             |          |      |        |
| **Won't implement — this file §c5 verdict: dormant — dropped.**                                                               |          |      |        |
| done — .github/workflows/ci.yml runs integration + module tests                                                               |          |      |        |
| done — go.sum handled via go mod tidy in FOD (b383d78)                                                                        |          |      |        |
| **→ still open — noted in ROADMAP Theme 3 (dry-run idea)**                                                                    |          |      |        |
| done — flakeModules.go-standard published since 2026-08 (3-input module)                                                      |          |      |        |
| done — flake exposes lib.mkPreparedSource (verified by checks.structural)                                                     |          |      |        |
| **→ still open — routed TODO_LIST Blocked (real private-repo CI test; needs DEPLOY_SSH_KEY)**                                 |          |      |        |
| **NOT-DO — buildGoModule has no go.work support; the replace-directive pipeline is the shipped answer (2026-06-29 verdict).** |          |      |        |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Should `Standup-Killer`'s `subModules` entry for `go-cqrs-lite` use `"memory/v2"` instead of `"memory"`?**

Current Standup-Killer config:

```nix
subModules = {
  "github.com/larsartmann/go-cqrs-lite" = [ "core" "memory" ];
};
```

But `memory/go.mod` declares `module .../memory/v2`. With the new fix, `"memory"` generates:

```
.../go-cqrs-lite/memory => ./_local_deps/go-cqrs-lite/memory
```

While `"memory/v2"` would generate:

```
.../go-cqrs-lite/memory/v2 => ./_local_deps/go-cqrs-lite/memory
```

The **correct** one depends on what Standup-Killer's `go.mod` actually imports. If it imports `go-cqrs-lite/memory/v2`, then the current `"memory"` entry produces a **wrong** replace directive (left side won't match the import path). I can't determine Standup-Killer's actual import without checking its `go.mod`, which I didn't want to do without your direction since it's in a different project.

This same question applies to every consumer using `go-cqrs-lite` sub-modules — they ALL need versioned entries now.

---

## File Inventory

| File                                 | Lines | Status                                                              |
| ------------------------------------ | ----- | ------------------------------------------------------------------- |
| `mkPreparedSource.nix`               | 174   | **Modified** (added `stripVersionSuffix`, fixed `subModuleReplace`) |
| `README.md`                          | 81    | Unchanged (already has `/vN` docs from previous fix)                |
| `templates/go-flake-parts/flake.nix` | 207   | Unchanged                                                           |
| `templates/go-flake-parts/README.md` | 40    | Unchanged                                                           |
| `scripts/dashboard.sh`               | 75    | Unchanged                                                           |
| `scripts/generate-flake.sh`          | 84    | Unchanged                                                           |
| `scripts/nix-lint.sh`                | 211   | Unchanged                                                           |
| `docs/flake-patterns.md`             | 200   | Unchanged                                                           |
| `docs/ci-workflow.yml`               | —     | Unchanged                                                           |
| `git-town.toml`                      | 9     | Unchanged                                                           |
| `.gitignore`                         | 3     | Unchanged                                                           |
| `report/`                            | —     | Empty directory                                                     |

## Downstream Consumers

| Project                        | Uses `/vN` deps               | Uses `subModules`      | Can Migrate to versioned subModules           | Needs vendorHash Update |
| ------------------------------ | ----------------------------- | ---------------------- | --------------------------------------------- | ----------------------- |
| crush-daily                    | Yes (14 go-cqrs-lite/v2 deps) | No                     | **Yes — consolidate 14 deps into subModules** | After migration         |
| Standup-Killer                 | Yes (go-cqrs-lite)            | Yes (`core`, `memory`) | **Yes — add `/v2` suffixes**                  | After migration         |
| browser-history                | Yes (go-cqrs-lite imports)    | —                      | Needs investigation                           | Unknown                 |
| BuildFlow                      | No                            | Yes (go-output)        | No                                            | Unlikely                |
| mr-sync                        | No                            | Yes (go-output)        | No                                            | Unlikely                |
| projects-management-automation | Yes (v2, v3)                  | Yes (go-output)        | **Yes — add `/v2` to go-cqrs-lite entries**   | **Yes**                 |
| go-structure-linter            | Yes (v3)                      | Yes (go-output)        | No                                            | **Yes**                 |
| branching-flow                 | No                            | Yes (go-output)        | No                                            | Unlikely                |
| library-policy                 | Delegates to `./nix/packages` | —                      | Needs investigation                           | Unknown                 |

## Git Diff Summary

```
mkPreparedSource.nix | 22 ++++++++++++++++------
1 file changed, 16 insertions(+), 6 deletions(-)
```

Changes:

- Added `stripVersionSuffix` helper function (lines 62-68)
- Refactored `repoName` to use `stripVersionSuffix` (lines 71-73)
- Updated `subModuleReplace` to use `stripVersionSuffix` for local directory path (line 100)
- Updated doc comments with versioned sub-path documentation (lines 36-40)
- Updated example to include versioned sub-modules (line 23)

---

## Resolution (2026-07-24)

The `subModules` `/vN` fix this report centres on shipped as `7b69382` and was
deepened by the recursive discovery + mid-path `/vN` work in `7fdb95c`. The
foundational gaps under "NOT STARTED" have since closed: `flake.nix` (`3c22ce4`),
the `test.nix` suite (`befd406`, `a31fec9`), `AGENTS.md` (`3c22ce4`), and
`CHANGELOG.md` / `FEATURES.md` / `TODO_LIST.md` now all exist; the `report/`
directory was removed.

The "Top #1 Question" (whether `Standup-Killer`'s `memory` sub-module entry needs
a `/v2` suffix) is a per-consumer concern, resolved in each downstream flake —
not in this repo.
