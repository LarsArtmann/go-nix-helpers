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

| Project                    | Before    | After     | Reduction            |
| -------------------------- | --------- | --------- | -------------------- |
| Standup-Killer `flake.nix` | 229 lines | 118 lines | **-111 lines (48%)** |
| crush-daily `flake.nix`    | 387 lines | 296 lines | **-91 lines (24%)**  |

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

1. ~~**go-nix-helpers flake.lock not updated** — the `go-nix-helpers` input in crush-daily and Standup-Killer still points to the remote `master` (rev `3c22ce4`) which does NOT contain `mkGoFlake.nix`. Until `go-nix-helpers` is pushed, consumers must use `--override-input go-nix-helpers path:...` or the build will fail. This is a **blocking deployment step**.~~ done — pushed — downstream consumers advanced past it (Resolution 2026-07-24)
2. ~~**Template not updated** — `templates/go-flake-parts/flake.nix` in go-nix-helpers still uses the old inline pattern. Should be updated to use `mkGoFlake` as the gold standard.~~ done — superseded — the go-standard template is the gold standard now (`927c924`)

## c) NOT STARTED 📋

1. ~~**Other consumers not migrated** — AGENTS.md mentions 7+ downstream consumers (BuildFlow, mr-sync, PMA, go-structure-linter, branching-flow, library-policy). None migrated yet.~~ done — superseded — Tier A fleet migrated to go-standard (2026-08-10); rest in TODO_LIST T4/T5
2. ~~**Template migration** — `templates/go-flake-parts/flake.nix` not updated to use mkGoFlake~~ **Won't implement — superseded — template deprecated with banner (`ee8c5b3`) instead.**
3. ~~**go.sum in Standup-Killer** — has unrelated changes (test deps removed by prior `go mod tidy`). Not committed.~~ done — moot — three months of subsequent commits

## d) TOTALLY FUCKED UP ❌

Nothing. All verifications pass. No data loss, no broken builds.

## e) WHAT WE SHOULD IMPROVE

1. ~~**Push go-nix-helpers to remote** — without this, consumers can't build without `--override-input`~~ done — pushed (Resolution 2026-07-24)
2. ~~**Update the template** — `templates/go-flake-parts/flake.nix` should demonstrate mkGoFlake usage~~ **Won't implement — superseded — go-flake-parts template deprecated; go-standard template is canonical.**
3. ~~**Migrate other consumers** — 7+ projects still use the old boilerplate pattern~~ done — Tier A done 2026-08-10; rest tracked in TODO_LIST T4/T5
4. ~~**Add `meta.description` to generated apps** — `nix flake check` warns about missing descriptions on apps~~ done — go-standard-generated apps carry meta.description
5. ~~**Consider `doCheck = false` as default** — many projects have pre-existing test failures and run tests via a separate `checks.test` instead~~ **Won't implement — kept `enableCheck = true` default — the option ships the choice.**

## f) Top 25 Things to Get Done Next

### Critical (blocks consumers)

1. ~~**Commit and push go-nix-helpers** — mkGoFlake.nix, flake.nix, AGENTS.md, README.md~~ done — pushed
2. ~~**Commit crush-daily flake.nix migration**~~ done — committed
3. ~~**Commit Standup-Killer flake.nix migration**~~ done — committed
4. ~~**Update flake.lock in crush-daily** — after go-nix-helpers is pushed~~ done — lock advanced past `3c22ce4`
5. ~~**Update flake.lock in Standup-Killer** — after go-nix-helpers is pushed~~ done — lock advanced past `3c22ce4`

### Template & Docs

6. ~~**Update `templates/go-flake-parts/flake.nix`** to use mkGoFlake~~ **Won't implement — template deprecated with banner instead.**
7. ~~**Add a "migration guide" section to README.md** — how to convert an existing flake~~ done — shipped — docs/migration-guide.md
8. ~~**Update `docs/flake-patterns.md`** — reference mkGoFlake as the canonical pattern~~ done — shipped — flake-patterns references go-standard

### Extract More (from the comparison report)

9. ~~**Extract HHMM type** — into a shared package (standup-killer `domain.HHMM` vs crush-daily `config.HHMM`)~~ **Won't implement — external repos — out of go-nix-helpers scope.**
10. ~~**Extract event replay helper** — `event.ReplayInto(ctx, store, handler)` into go-cqrs-lite~~ **Won't implement — external repos — out of go-nix-helpers scope.**

### Other Consumer Migrations

11. ~~**Migrate BuildFlow flake.nix** to mkGoFlake~~ done — superseded — migrated to go-standard (TODO_LIST T4)
12. ~~**Migrate mr-sync flake.nix** to mkGoFlake~~ done — superseded — tracked in TODO_LIST T4
13. ~~**Migrate PMA flake.nix** to mkGoFlake~~ done — done — PMA migrated to go-standard (`9b47684`)
14. ~~**Migrate go-structure-linter flake.nix** to mkGoFlake~~ done — superseded — tracked in TODO_LIST T4
15. ~~**Migrate branching-flow flake.nix** to mkGoFlake~~ done — superseded — tracked in TODO_LIST T4
16. ~~**Migrate library-policy flake.nix** to mkGoFlake~~ done — superseded — tracked in TODO_LIST T5

### Refinements

17. ~~**Add `meta.description` to all generated apps** — silence nix flake check warnings~~ done — go-standard apps carry meta.description
18. ~~**Add a test derivation for mkGoFlake** — verify it produces valid outputs for a minimal config~~ done — moved to TODO_LIST T10 (mkGoFlake smoke)
19. ~~**Consider a `subPackages` parameter** — for projects with `cmd/<name>/` entrypoints~~ done — shipped — subPackages option in go-standard
20. ~~**Consider `programs.gofumpt` vs `programs.gofumpt.enable`** — template pattern consistency~~ **Won't implement — cosmetic.**
21. ~~**Add `git-hooks.nix` support** to mkGoFlake (optional pre-commit hooks)~~ **Won't implement — dormant since 2026-06 — dropped (reopen on demand).**
22. ~~**Consider `version ? self.shortRev or "dev"`** — dynamic versioning from git~~ done — shipped — version option defaults to self.rev or self.dirtyRev or "dev"
23. ~~**Add `homepage` to meta** — currently missing~~ **Won't implement — dormant since 2026-06 — dropped.**
24. ~~**Document `buildGoModuleOverrides` shallow-merge caveat** — `//` replaces nested attrs like `meta`~~ done — superseded — extraBuildAttrs merge semantics documented (6 concatenated attrs)
25. ~~**Clean up Standup-Killer go.sum** — unrelated changes should be committed separately or reverted~~ done — moot — three months of subsequent commits

## g) Top #1 Question

**The go-nix-helpers input in both consumer flakes still points to remote `master` (rev 3c22ce4). Should I push go-nix-helpers to GitHub now, or wait?** Without pushing, both crush-daily and Standup-Killer cannot build via `nix build` without `--override-input`. The changes are verified working locally but are effectively undeployable until the upstream go-nix-helpers commit lands on remote `master`.

---

## Resolution (2026-07-24)

The `mkGoFlake.nix` extraction described here shipped, then was **superseded**
by the composite `flakeModules.go-standard` module (`927c924`, `9471741`), which
bundles `treefmt-nix` internally and needs only 3 consumer inputs.
`mkGoFlake.nix` is now deprecated (`ee8c5b3`) but still exported as
`flake.lib.mkGoFlake` pending deletion — see `TODO_LIST.md` ("Delete or formally
deprecate `mkGoFlake.nix`"). The deployment blocker this report worried about
(the flake.lock pinning the old remote rev `3c22ce4`) resolved once go-nix-helpers
was pushed; downstream consumers have since advanced past it.
