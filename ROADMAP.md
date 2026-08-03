# Roadmap

> Long-term direction and raw ideas for go-nix-helpers. Items here are NOT
> actionable tasks; when an idea is refined into bounded work, it moves to
> `TODO_LIST.md`.

## Themes

### 1. Zero-config consumer experience

Reduce the amount of Nix code a LarsArtmann Go project needs to maintain. The goal is that a typical repo needs only `pname`, `vendorHash`, and a description, with everything else inferred or defaulted.

Raw ideas:

- Auto-detect `enableTempl` by scanning for `.templ` files in `src`
- Auto-calculate `vendorHash` on first build via a helper app or check
- Auto-detect `subPackages` from `cmd/` or `main` package layout
- Provide a `nix flake init -t go-nix-helpers#go-standard` template via `flake.templates`
- Generate a complete consumer `flake.nix` from a project name and a few flags

### 2. Ecosystem consolidation

Move the whole LarsArtmann Go portfolio onto the `go-standard` module and retire legacy patterns.

Raw ideas:

- Migrate all 7+ downstream consumers from raw `mkPreparedSource` import or `mkGoFlake.nix` to `flakeModules.go-standard`
- Add a migration script that rewrites a 5-input manual flake.nix to the 3-input module
- Fully remove `mkGoFlake.nix` once all consumers have migrated (currently emits deprecation trace warning)
- Remove `templates/go-flake-parts/` once consumers no longer need it (currently marked deprecated with banner)
- Provide a shared overlay surface so projects can compose each other's packages cleanly

### 3. Testing and reliability

Make the module trustworthy enough that a consumer can adopt it without manual end-to-end verification.

Raw ideas:

- Property-based tests for `repoName`, `stripVersionSuffix`, and `discoverSubModules`
- Behavioral module tests that verify option values actually reach `buildGoModule` (not just evaluation)
- CI matrix that evaluates `go-standard` with common consumer configurations (with deps, without deps, with templ, with overlays, monorepo)
- Real private-dependency integration test using an actual GitHub private repo or a local mock with SSH semantics
- Nix-level checks that assert the composite module produces expected output structure
- Dry-run mode for `mkPreparedSource` so consumers can inspect generated replaces without building
- Smoke test for `generate-flake.sh` in CI to catch script regressions

### 4. Distribution and discoverability

Make go-nix-helpers easy to find, understand, and depend on outside the immediate project circle.

Raw ideas:

- Publish to nixpkgs or the Nix flake registry
- Semver-tagged releases with release notes
- Public documentation site (GitHub Pages / Astro / Starlight) generated from the repo
- Short demo video or animated GIF for the README
- Register `maintainers.larsartmann` in nixpkgs

### 5. Smart private-dep detection

`mkPreparedSource` currently treats every `github.com/larsartmann/*` repo as
private. Some are public and served by `proxy.golang.org`. The validation
then demands unnecessary SSH flake inputs for repos that don't need them.

Raw ideas:

- Auto-detect whether a repo is public by querying `proxy.golang.org` before
  requiring a local `replace` directive
- Add a `publicDeps` exclusion list so consumers can mark specific repos as
  public while keeping validation active for genuinely private repos
- Forward `validatePrivateDeps` and `privateDepPattern` through `mkGoFlake.nix`
  so consumers using the deprecated module can toggle validation
- Improve the error message to offer multiple resolution paths (add as dep,
  set `validatePrivateDeps = false`, or add to `publicDeps`)

## Non-goals

These are deliberately out of scope for go-nix-helpers:

- **Re-implementing `buildGoModule`** from nixpkgs — we compose it, we do not replace it.
- **Supporting non-Go projects** — the scope is strictly Go + Nix flakes.
- **Becoming a generic Nix framework** — the helper is opinionated around the LarsArtmann flake-parts + treefmt-nix stack.
- **Replacing flake-parts** — the module system is a dependency, not competition.
