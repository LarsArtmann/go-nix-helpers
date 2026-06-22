# Status Report — mkGoFlake Extraction

**Date:** 2026-06-23 01:12
**Scope:** `go-nix-helpers`, `crush-daily`, `Standup-Killer`

---

## What Was Done

Extracted the ~80% identical flake.nix boilerplate shared across Standup-Killer and crush-daily into a reusable `mkGoFlake.nix` module in `go-nix-helpers`.

### New File: `go-nix-helpers/mkGoFlake.nix` (192 lines)

A flake-parts module that generates standard flake outputs from a single config attrset:

- **packages** — `default` + `<pname>` via `buildGoModule` with `mkPreparedSource` integration
- **apps** — `default`, `test` (go test -race), `lint` (golangci-lint)
- **devShells** — `default` (Go + golangci-lint + extras), `ci` (Go + golangci-lint, mkShellNoCC)
- **checks** — `format` (treefmt), `build` (package derivation)
- **treefmt** — gofumpt + goimports + nixfmt
- **flake.overlays.default** — expose package for other flakes

**Extension points** for project-specific needs:
- `deps`, `subModules`, `postPatchExtra` — private dep configuration
- `buildGoModuleOverrides` — extra/override buildGoModule attrs
- `devShellExtraPackages`, `devShellShellHook`, `shellExtraEnv` — devShell customization
- `extraApps`, `extraChecks` — functions receiving `{config, pkgs, lib, goPkg, package, mkApp}`
- `extraFlake` — extra flake-level outputs (e.g. NixOS modules)

### Migrations

| Project | Before | After | Reduction |
|---|---|---|---|
| Standup-Killer `flake.nix` | 229 lines | 118 lines | **-111 lines (48%)** |
| crush-daily `flake.nix` | 387 lines | 296 lines | **-91 lines (24%)** |

crush-daily retains more lines because of its 180-line NixOS module (preserved via `extraFlake`).

### Verification

All three flakes pass `nix flake check --no-build`:
- `go-nix-helpers` — `flake.lib.mkGoFlake` exported, 20 parameters with correct required/optional flags
- `crush-daily` — all outputs match: packages (2), apps (4), checks (4), devShells (2), overlays (1), nixosModules (1)
- `Standup-Killer` — all outputs match: packages (2), apps (3), checks (4), devShells (2), overlays (1)

---

## a) FULLY DONE ✅

1. **`mkGoFlake.nix` module designed and implemented** (192 lines)
2. **Exported via `flake.lib.mkGoFlake`** in go-nix-helpers flake.nix
3. **go-nix-helpers AGENTS.md updated** — mkGoFlake documented in key files table, architecture, what-this-project-does
4. **go-nix-helpers README.md updated** — full API docs with usage example and parameter table
5. **crush-daily flake.nix migrated** — NixOS module, build overrides, build app, all devShell extras preserved
6. **Standup-Killer flake.nix migrated** — test check, sqlite devShell package, doCheck=false preserved
7. **All three flakes pass `nix flake check --no-build`** — verified with `--override-input` pointing to local go-nix-helpers

## b) PARTIALLY DONE 🔧

1. **go-nix-helpers flake.lock not updated** — the `go-nix-helpers` input in crush-daily and Standup-Killer still points to the remote `master` (rev `3c22ce4`) which does NOT contain `mkGoFlake.nix`. Until `go-nix-helpers` is pushed, consumers must use `--override-input go-nix-helpers path:...` or the build will fail. This is a **blocking deployment step**.
2. **Template not updated** — `templates/go-flake-parts/flake.nix` in go-nix-helpers still uses the old inline pattern. Should be updated to use `mkGoFlake` as the gold standard.

## c) NOT STARTED 📋

1. **Other consumers not migrated** — AGENTS.md mentions 7+ downstream consumers (BuildFlow, mr-sync, PMA, go-structure-linter, branching-flow, library-policy). None migrated yet.
2. **Template migration** — `templates/go-flake-parts/flake.nix` not updated to use mkGoFlake
3. **go.sum in Standup-Killer** — has unrelated changes (test deps removed by prior `go mod tidy`). Not committed.

## d) TOTALLY FUCKED UP ❌

Nothing. All verifications pass. No data loss, no broken builds.

## e) WHAT WE SHOULD IMPROVE

1. **Push go-nix-helpers to remote** — without this, consumers can't build without `--override-input`
2. **Update the template** — `templates/go-flake-parts/flake.nix` should demonstrate mkGoFlake usage
3. **Migrate other consumers** — 7+ projects still use the old boilerplate pattern
4. **Add `meta.description` to generated apps** — `nix flake check` warns about missing descriptions on apps
5. **Consider `doCheck = false` as default** — many projects have pre-existing test failures and run tests via a separate `checks.test` instead

## f) Top 25 Things to Get Done Next

### Critical (blocks consumers)
1. **Commit and push go-nix-helpers** — mkGoFlake.nix, flake.nix, AGENTS.md, README.md
2. **Commit crush-daily flake.nix migration**
3. **Commit Standup-Killer flake.nix migration**
4. **Update flake.lock in crush-daily** — after go-nix-helpers is pushed
5. **Update flake.lock in Standup-Killer** — after go-nix-helpers is pushed

### Template & Docs
6. **Update `templates/go-flake-parts/flake.nix`** to use mkGoFlake
7. **Add a "migration guide" section to README.md** — how to convert an existing flake
8. **Update `docs/flake-patterns.md`** — reference mkGoFlake as the canonical pattern

### Extract More (from the comparison report)
9. **Extract HHMM type** — into a shared package (standup-killer `domain.HHMM` vs crush-daily `config.HHMM`)
10. **Extract event replay helper** — `event.ReplayInto(ctx, store, handler)` into go-cqrs-lite

### Other Consumer Migrations
11. **Migrate BuildFlow flake.nix** to mkGoFlake
12. **Migrate mr-sync flake.nix** to mkGoFlake
13. **Migrate PMA flake.nix** to mkGoFlake
14. **Migrate go-structure-linter flake.nix** to mkGoFlake
15. **Migrate branching-flow flake.nix** to mkGoFlake
16. **Migrate library-policy flake.nix** to mkGoFlake

### Refinements
17. **Add `meta.description` to all generated apps** — silence nix flake check warnings
18. **Add a test derivation for mkGoFlake** — verify it produces valid outputs for a minimal config
19. **Consider a `subPackages` parameter** — for projects with `cmd/<name>/` entrypoints
20. **Consider `programs.gofumpt` vs `programs.gofumpt.enable`** — template pattern consistency
21. **Add `git-hooks.nix` support** to mkGoFlake (optional pre-commit hooks)
22. **Consider `version ? self.shortRev or "dev"`** — dynamic versioning from git
23. **Add `homepage` to meta** — currently missing
24. **Document `buildGoModuleOverrides` shallow-merge caveat** — `//` replaces nested attrs like `meta`
25. **Clean up Standup-Killer go.sum** — unrelated changes should be committed separately or reverted

## g) Top #1 Question

**The go-nix-helpers input in both consumer flakes still points to remote `master` (rev 3c22ce4). Should I push go-nix-helpers to GitHub now, or wait?** Without pushing, both crush-daily and Standup-Killer cannot build via `nix build` without `--override-input`. The changes are verified working locally but are effectively undeployable until the upstream go-nix-helpers commit lands on remote `master`.
