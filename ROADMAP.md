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
- `goPkg` as `lib.types.package` instead of `goPkgAttr` string (breaking, target v2)
- `lib.mkForce` support for consumers who need to override list attrs (`nativeBuildInputs`, etc.)

### 2. Ecosystem consolidation

Move the whole LarsArtmann Go portfolio onto the `go-standard` module and retire legacy patterns.

Raw ideas:

- Migrate the remaining consumer fleet to `flakeModules.go-standard` (10 Tier A
  repos done 2026-08-10; Tier B + Tier C remain — see TODO_LIST T4/T5)
- Add a migration script that rewrites a 5-input manual flake.nix to the 3-input module
- ~~Fully remove `mkGoFlake.nix`~~ DONE 2026-11-18 (post-v0.1.0; last consumer ucr-archive migrated to go-standard at the tag)
- ~~Remove `templates/go-flake-parts/`~~ DONE 2026-11-18 (same batch; CI template smoke now go-standard only)
- Provide a shared overlay surface so projects can compose each other's packages cleanly
- Make "eval one real consumer" part of the definition of done for changes to shared
  defaults (the `goPkgAttr` auto-default flip shipped without any consumer smoke-eval)

### 3. Testing and reliability

Make the module trustworthy enough that a consumer can adopt it without manual end-to-end verification.

Shipped here: property tests for `repoName`/`stripVersionSuffix`/`newestGoAttrName`
(`checks.pureFunctions`, 72 checks), behavioral module tests proving option
values reach `buildGoModule` (`checks.moduleTest`, 218 assertions), structural
output checks, template eval check, `generate-flake.sh` smoke tests in CI, the
old-nixpkgs pinned matrix job, and `checks.containerSmoke` exercising the real
nix2container backend end-to-end.

Raw ideas still open:

- Real private-dependency integration test using an actual GitHub private repo or a local mock with SSH semantics
- Template build-smoke in CI: copy `templates/go-standard` into a scratch project and `nix build` it (eval-only today)
- Dry-run mode for `mkPreparedSource` so consumers can inspect generated replaces without building
- Re-run the consumer `go_1_XX` attr-probe after every nixpkgs bump (the 2026-09-25 fleet-wide pin removal was proven safe only because no consumer nixpkgs carried a newer branch)

### 4. Distribution and discoverability

Make go-nix-helpers easy to find, understand, and depend on outside the immediate project circle.

Raw ideas:

- Publish to nixpkgs or the Nix flake registry
- Semver-tagged releases with release notes
- Public documentation site (GitHub Pages / Astro / Starlight) generated from the repo
- Short demo video or animated GIF for the README
- Register `maintainers.larsartmann` in nixpkgs

### 5. Smart private-dep detection

`mkPreparedSource` previously treated every `github.com/larsartmann/*` repo as
private. The `publicDeps` exclusion list (now versioned-path aware: listing the
base path also excludes `/v2`, `/v3`, …) and forwarded escape hatches
(`validatePrivateDeps`, `privateDepPattern`) are shipped. The remaining
vision is full automation.

Raw ideas:

- Auto-detect whether a repo is public by querying `proxy.golang.org` before
  requiring a local `replace` directive (eliminates the need for manual
  `publicDeps` configuration)
- Curate a default `publicDeps` list of known-public LarsArtmann repos so
  consumers don't need to discover them individually

### 6. Docs that cannot rot

Every default change touches 6+ doc files by hand, and the 2026-09-24 session
proved each can rot independently behind a green test suite (4-systems claim vs
3-system reality survived for weeks). The end state is derivation, not
transcription.

Raw ideas:

- Generate the man page option sections and the README option table from the
  module's `mkOption` descriptions/defaults (single source of truth)
- Derive assertion/option counts from test output instead of hand-typing them
  in AGENTS.md/README
- A drift gate that keeps the man page + README in sync with option
  descriptions (the registry decision fanned out to 5 places by hand)
- Eval-time go.mod floor check: parse the consumer's `go.mod` (readable at
  eval, not IFD) and warn/throw when the resolved toolchain is below the
  floor — converts a silent build breaker into an actionable eval error

## Open questions

Unresolved owner decisions that gate process (not code). Each blocks a family
of small work; none belongs in TODO_LIST until answered.

- **Won't-implement policy** — age threshold / cap / owner sign-off for the
  `dormant — dropped` annotation brush (~120 unilateral verdicts from the
  2026-09-24 pass; see TODO_LIST Blocked).
- **Skill `allowed-tools` enforcement** — is the frontmatter field advisory or
  mandatory in Crush? Decides whether skill audits must keep flagging it
  (2026-08-12 reports).
- **Periodic skill re-verification** — should skills that cite live APIs
  (nix-private-go-repos) carry a recurring re-verify cadence, and who runs it?
- **Daemon WIP guard** — convention for sessions mid-refactor under the
  auto-commit daemon (a `DON'T-COMMIT` marker file?), or is
  broken-intermediate-state-in-master accepted?
- **Second actor in this repo** — who pushed master at 18:55 on 2026-11-17 and
  created `origin/systemnix-vn-version-fix`, and who re-tab-indented the
  scripts twice? (T66 tracks the branch; coordination question remains.)

## Non-goals

These are deliberately out of scope for go-nix-helpers:

- **Re-implementing `buildGoModule`** from nixpkgs — we compose it, we do not replace it.
- **Supporting non-Go projects** — the scope is strictly Go + Nix flakes.
- **Becoming a generic Nix framework** — the helper is opinionated around the LarsArtmann flake-parts + treefmt-nix stack.
- **Replacing flake-parts** — the module system is a dependency, not competition.
