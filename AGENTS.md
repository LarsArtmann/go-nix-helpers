# go-nix-helpers — AGENTS.md

Shared Nix helpers for LarsArtmann Go repositories. This is a **Nix library**, not a Go application — it contains no Go code.

## What this project does

This repo provides two Nix helpers for LarsArtmann Go projects:

1. **`mkPreparedSource.nix`** — Solves private Go dependency injection for Nix sandbox builds. Go repos with private dependencies can't fetch them inside the Nix sandbox (no SSH, no network). This helper copies flake-input deps into `_local_deps/` and injects `replace` directives into `go.mod`.

2. **`mkGoFlake.nix`** — A shared flake-parts module that generates standard flake outputs (packages, apps, devShells, checks, treefmt, overlay) from a single config attrset. Eliminates ~150 lines of duplicated flake.nix boilerplate per project.

## Consumption pattern

Consumers import this repo as a `flake = false` input and raw-import the helper:

```nix
inputs.go-nix-helpers = {
  url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
  flake = false;
};
# ...
mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
  inherit pkgs lib;
  goPkg = pkgs.go_1_26;
};
```

Since 2026-06-19, the repo also has a `flake.nix` exposing `lib.mkPreparedSource` — both import patterns work. 7+ downstream consumers exist (BuildFlow, mr-sync, PMA, go-structure-linter, branching-flow, Standup-Killer, library-policy).

## Build / test commands

```bash
nix flake check                    # runs all checks (autoDiscovery, explicitOnly, verify, treefmt)
nix fmt                            # format all .nix files with nixfmt
nix-build test.nix -A verify       # success-path integration test
nix run .#verifyValidation         # negative-case validation test (run outside sandbox)
```

## Architecture

- **`mkPreparedSource.nix`** — the core helper. Takes `{pkgs, lib, goPkg}` then `{name, src, deps, ...}`. Returns a derivation that produces a patched source tree.
- **`mkGoFlake.nix`** — shared flake-parts module. Takes a config attrset with `{inputs, self, pname, version, vendorHash, description, src, deps, ...}`. Returns a flake-parts module attrset with packages, apps, devShells, checks, treefmt, and overlay. Consumers call it as `import (go-nix-helpers + "/mkGoFlake.nix") { ... }` inside `flake-parts.lib.mkFlake`.
- **Auto-discovery** — scans each dep source for subdirectories containing `go.mod`, reads the module path, and generates replace directives automatically. No manual `subModules` list needed.
- **Unified sub-module pipeline** — explicit `subModules` entries are mapped into the same `{modulePath, localDir}` shape as auto-discovered ones, then a single replace generator and single version normalizer process both. (Unified 2026-06-19; previously was a split brain with 4 duplicate code paths.)
- **`/vN` handling** — `stripVersionSuffix` strips `/v2`, `/v3` etc. from local directory paths while keeping the full versioned module path in replace directives.
- **Build-time validation** — verifies every private module require has a matching replace directive, failing with a clear message instead of the cryptic SSH error.

## Gotchas

- **`maintainers.larsartmann` is NOT registered in nixpkgs** — the template's `meta.maintainers` must not reference it (throws at eval time). Register in nixpkgs first, or omit.
- **`goPkg` parameter is dead weight** — the derivation has `dontBuild = true` and never invokes `go`. Kept for API compatibility.
- **`privateDepPattern` default is LarsArtmann-specific** — `validatePrivateDeps` only validates modules matching `github\.com/[Ll]ars[Aa]rtmann/` by default. Override for other orgs.
- **`validationTest` is a deliberately-failing derivation** — it cannot be a Nix dependency of a passing derivation. The `verify` check only tests success paths; `verifyValidation` is a separate shell script run outside the sandbox.
- **`postPatchExtra` runs BEFORE replace directives are injected** — consumers needing to read the generated replaces must account for this ordering.

## Key files

| File | Purpose |
|---|---|
| `mkPreparedSource.nix` | Core helper — solves private Go dep injection for Nix sandbox builds |
| `mkGoFlake.nix` | Shared flake-parts module — generates standard packages/apps/devShells/checks/treefmt/overlay from one config attrset |
| `flake.nix` | Self-hosting: checks, formatter, devShell, lib export |
| `test.nix` | Integration tests (auto-discovery, explicit, validation) |
| `templates/go-flake-parts/flake.nix` | Gold-standard template for new Go projects |
| `scripts/nix-lint.sh` | Lints flake.nix files across all projects for common errors |
| `scripts/dashboard.sh` | Overview of flake check status across all projects |
| `docs/flake-patterns.md` | Reference: correct patterns and anti-patterns |
