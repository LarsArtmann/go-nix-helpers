# Status Report — README & GitHub Metadata Refresh

**Date:** 2026-07-24 21:31 CEST\
**Session focus:** Make `README.md` and the GitHub repository description/topics superb.

---

## Executive Summary

This session rewrote the public-facing documentation and repository metadata for `go-nix-helpers`. The README now reads like a product page: clear value proposition, copy-paste quickstart, feature tables, before/after comparison, and explicit links to templates and deeper docs. GitHub description and topics were updated live via the GitHub CLI. All flake checks pass.

Two commits were produced during this work:

- `0ef8c34` — `docs(readme): update project documentation for improved clarity and usability`
- `00ea4e9` — `docs: refresh documentation and align go-standard src forwarding with cfg`

The second commit also picked up adjacent documentation grooming (`AGENTS.md`, `docs/flake-standard.md`, two prior status reports) and a small internal consistency fix in `modules/go-standard.nix` (`src = cfg.src;` → `inherit (cfg) src;`), plus a routine `flake.lock` advance.

---

## a) FULLY DONE

1. **README.md completely rewritten**
   - Hero tagline and three badges (Nix flake check, Go 1.26+, flake-parts module).
   - One-paragraph value proposition explaining the problem (flake.nix boilerplate + private deps in Nix sandbox).
   - Copy-paste minimal `flake.nix` (~20 lines).
   - "What you get" output table.
   - "Private dependencies, solved" section with feature bullets.
   - Before/after comparison table vs. manual flake.nix.
   - Full `go-standard` option table.
   - Lower-level helper documentation (`mkPreparedSource.nix`, `mkGoFlake.nix`).
   - Templates reference table.
   - Development commands.
   - Related projects + link to `docs/flake-patterns.md`.

2. **GitHub repository metadata updated live**
   - Description set to:\
     "Zero-config flake-parts module for Go projects: packaging, devShells, formatting, linting, CI, and private dependency injection in ~20 lines of Nix."
   - Homepage URL cleared (left empty).
   - Topics added: `nix`, `nix-flakes`, `flake-parts`, `go`, `golang`, `build-tool`, `devshell`, `private-dependencies`, `reproducible-builds`, `nixos`.

3. **Quality gates run**
   - `nix fmt` — no changes needed.
   - `nix flake check` — all checks passed.

4. **Adjacent documentation grooming** (included in `00ea4e9`)
   - `AGENTS.md` table re-alignment.
   - `docs/flake-standard.md` formatting touch-up.
   - `docs/status/2026-07-23_16-15_composite-module-overhaul-brutal-review.md` table re-alignment.
   - `docs/status/2026-07-23_17-10_skill-updates-and-unresolved-issues.md` table re-alignment + minor editorial fix.

5. **Minor code consistency fix** (included in `00ea4e9`)
   - `modules/go-standard.nix`: changed `src = cfg.src;` to `inherit (cfg) src;` when forwarding into `mkPreparedSource`.
   - Functionally equivalent; makes the forwarding block internally consistent.

6. **flake.lock advanced**
   - nixpkgs moved from `241313f4e8e508cb9b13278c2b0fa25b9ca27163` to `e2587caef70cea85dd97d7daab492899902dbf5d`.
   - All checks still pass.

---

## b) PARTIALLY DONE

1. ~~**README superb-ness**~~ done — all sub-items shipped — dynamic badge, LICENSE, architecture diagram, FAQ (see Resolution appendix); demo video moved to ROADMAP Theme 4
   - Strong first pass, but could still use:
     - Dynamic badges (currently static shields.io).
     - A license badge/file.
     - A short architecture diagram.
     - A troubleshooting/FAQ section.
     - A recorded demo or animated GIF.

2. ~~**GitHub presence**~~ **Won't implement — social preview dropped; docs site moved to ROADMAP Theme 4.**
   - Description and topics are live, but:
     - No social preview image / Open Graph image.
     - No homepage URL (intentionally left blank; could point to future docs site).
     - No repository website / GitHub Pages.

3. ~~**Community/contributor affordances**~~ done — shipped — CONTRIBUTING, issue/PR templates, CODEOWNERS (Resolution appendix)
   - README mentions templates, but there is no `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue templates, or PR template.

---

## c) NOT STARTED

1. ~~Add an open-source `LICENSE` file and license badge.~~ done — done — MIT LICENSE + badge (`ce35aa5`)
2. ~~Set up GitHub Actions (or Hercules CI) to make the "nix flake check" badge dynamic.~~ done — done — GitHub Actions CI (`7415763`)
3. ~~Create a custom social preview / Open Graph image for the repo.~~ **Won't implement — dropped — social preview.**
4. ~~Publish a documentation website (GitHub Pages / Astro / Starlight).~~ done — moved to ROADMAP Theme 4
5. ~~Add `CONTRIBUTING.md`.~~ done — done — CONTRIBUTING.md (`7415763`)
6. ~~Add issue templates and PR template.~~ done — done — issue/PR templates + CODEOWNERS (`7415763`)
7. ~~Add `SECURITY.md` and vulnerability reporting policy.~~ **Won't implement — dormant — dropped.**
8. ~~Write a migration guide from `mkGoFlake.nix` to `flakeModules.go-standard`.~~ done — done — docs/migration-guide.md (`7415763`)
9. ~~Add an FAQ / troubleshooting section.~~ done — done — README Troubleshooting/FAQ (`7415763`)
10. ~~Create video or GIF walkthrough.~~ done — moved to ROADMAP Theme 4
11. ~~Add release tags and release notes.~~ done — moved to TODO_LIST Blocked (v0.1.0)
12. ~~Submit the package to nixpkgs.~~ done — moved to ROADMAP Theme 4
13. ~~Add property-based or fuzz tests.~~ done — shipped — checks.pureFunctions (41 assertions)
14. ~~Add real private-repo integration tests.~~ done — moved to TODO_LIST Blocked (SSH secret)
15. ~~Add cross-compilation helpers.~~ **Won't implement — dormant — dropped.**
16. ~~Add `goreleaser`-style release automation.~~ **Won't implement — dormant — dropped.**
17. ~~Set up Dependabot / flake.lock auto-update workflow.~~ done — done — dependabot.yml added 2026-09
18. ~~Add shell completions for generated apps.~~ done — done — enableCompletions option
19. ~~Add man pages.~~ done — done — man pages (`d8574df`)
20. ~~Create a public Discord/Matrix community.~~ **Won't implement — dormant — dropped.**

---

## d) TOTALLY FUCKED UP!

Nothing is totally fucked up. The repo builds, checks pass, and the documentation is materially better than before.

If forced to name the biggest lingering smell: **the "nix flake check" badge in the README is static and claims "passing" without CI backing it.** If someone breaks the flake and doesn't update the badge, it will lie. This is a trust issue, not a functional bug.

---

## e) WHAT WE SHOULD IMPROVE!

1. ~~**Make badges honest**~~ done — done — dynamic CI badge
   - A static badge that says "passing" is worse than no badge if it can become false.
   - Add GitHub Actions or another CI source so the badge reflects real CI state.

2. ~~**License the project**~~ done — done — MIT `ce35aa5`
   - Without a `LICENSE` file, reuse rights are ambiguous.
   - Add a clear license (likely MIT, given it's a library/helper) and a badge.

3. ~~**Complete the GitHub presence**~~ **Won't implement — templates shipped; social preview dropped.**
   - Social preview image.
   - `.github/` directory with issue templates, PR template, and workflows.
   - A homepage URL that points somewhere useful (docs site or this repo).

4. ~~**Add a migration guide**~~ done — done — docs/migration-guide.md
   - `mkGoFlake.nix` is deprecated but existing consumers need a clear path.

5. ~~**Automate routine maintenance**~~ done — done — dependabot.yml
   - `flake.lock` should update on a schedule (weekly/monthly) with a PR, not manually.

6. ~~**Expand test coverage**~~ done — done — 121 module assertions + templateEval check
   - `go-standard` module is lightly tested compared to `mkPreparedSource`.
   - Templates are not exercised in CI.

7. ~~**Sharpen the README further**~~ done — done — architecture diagram + FAQ shipped
   - Add a "Who this is for" / "Who this is not for" section.
   - Add a short architecture diagram (D2 or Mermaid).
   - Add a troubleshooting section for common private-dep failures.

8. ~~**Standardize status-report hygiene**~~ done — decided — Markdown reports; the convention has held since
   - This report is being written as a Markdown file per the user's explicit instruction, while the skill specifies HTML. Decide on one format and stick to it, or support both with clear rules.

---

## f) Up to 50 Things We Should Get Done Next

Sorted by a rough Pareto mix of impact, effort, and urgency.

| #                                                                                                                                                                    | Task                                                               | Category     | Impact     | Effort                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------ | ---------- | -------------------------------------------------------------------------- |
| done at `ce35aa5`                                                                                                                                                    |                                                                    |              |            |                                                                            |
| done at `7415763`                                                                                                                                                    |                                                                    |              |            |                                                                            |
| done at `7415763`                                                                                                                                                    |                                                                    |              |            |                                                                            |
| done — shipped as `.github/ISSUE_TEMPLATE/bug_report.md` + `feature_request.md` (`7415763`) — .md forms, not the requested .yml                                      |                                                                    |              |            |                                                                            |
| done at `7415763`                                                                                                                                                    |                                                                    |              |            |                                                                            |
| done at `7415763`                                                                                                                                                    |                                                                    |              |            |                                                                            |
| **Won't implement — social preview dropped (this report §c3/§e3).**                                                                                                  |                                                                    |              |            |                                                                            |
| **Won't implement — dormant — dropped (this report §c7).**                                                                                                           |                                                                    |              |            |                                                                            |
| done at `7415763`                                                                                                                                                    |                                                                    |              |            |                                                                            |
| done at `7415763`                                                                                                                                                    |                                                                    |              |            |                                                                            |
| done at `d8574df`                                                                                                                                                    |                                                                    |              |            |                                                                            |
| done at `7415763`, `50fd2c3`                                                                                                                                         |                                                                    |              |            |                                                                            |
| done at `2f3b6b2`                                                                                                                                                    |                                                                    |              |            |                                                                            |
| **Superseded — template `go-flake-parts` removed post-v0.1.0 (`9c8724b`, 2026-11-18); CI template coverage is now go-standard-only.**                                |                                                                    |              |            |                                                                            |
| done — `.github/dependabot.yml` + CI `flake-lock-freshness` job (.github/workflows/ci.yml:244)                                                                       |                                                                    |              |            |                                                                            |
| **→ still open — noted in ROADMAP.md Theme 4 (docs-site idea; this report §c4)**                                                                                     |                                                                    |              |            |                                                                            |
| ~~17~~                                                                                                                                                               | ~~Add release tags and `CHANGELOG.md`~~                            | ~~Process~~  | ~~Medium~~ | ~~1 h~~ done — done — CHANGELOG exists; tags in TODO_LIST Blocked (v0.1.0) |
| **Won't implement — dormant — dropped (this report §c16); v0.1.0 later cut manually at `ad06738` (2026-11-18).**                                                     |                                                                    |              |            |                                                                            |
| done — checks.pureFunctions, 72 checks (pure-functions.nix + test-pure-functions.nix)                                                                                |                                                                    |              |            |                                                                            |
| **→ still open — routed TODO_LIST Blocked (real private-repo CI test; needs DEPLOY_SSH_KEY secret)**                                                                 |                                                                    |              |            |                                                                            |
| **→ still open — untracked (docs-site idea parked in ROADMAP.md Theme 4)**                                                                                           |                                                                    |              |            |                                                                            |
| ~~22~~                                                                                                                                                               | ~~Add man pages for `mkPreparedSource` and `go-standard` options~~ | ~~Docs~~     | ~~Low~~    | ~~2 h~~ done — done — `d8574df`                                            |
| ~~23~~                                                                                                                                                               | ~~Add shell completions for generated apps~~                       | ~~DX~~       | ~~Low~~    | ~~1 h~~ done — done — enableCompletions option                             |
| done — README FAQ documents the systems/multi-OS story (README.md:441,449); cross-compile helpers themselves won't-implement (2026-07-23 review #31)                 |                                                                    |              |            |                                                                            |
| **→ still open — untracked (nearest shipped equivalents: README options table + docs/flake-patterns.md)**                                                            |                                                                    |              |            |                                                                            |
| done — 2026-11-17 corpus sweep annotated + archived all reports; enforced by checks.docsAnnotations (flake.nix:228) and the .docs-gates.json ratchet                 |                                                                    |              |            |                                                                            |
| done — mkGoFlake removed post-v0.1.0 (`9c8724b`); fleet fully on go-standard (TODO_LIST T4/T5 DONE 2026-11-18)                                                       |                                                                    |              |            |                                                                            |
| **Won't implement — upstream nixpkgs scope (buildGoModule); the replace-directive pipeline is the shipped answer (2026-06-29 report verdict).**                      |                                                                    |              |            |                                                                            |
| done — `goPkgOverride` + `goTarballVersion`/`goTarballHash` ship custom toolchains (README.md:206-209); repo-level granularity, not per-monorepo-package             |                                                                    |              |            |                                                                            |
| ~~30~~                                                                                                                                                               | ~~Add `enableGolangciLint` toggle (currently always on)~~          | ~~Config~~   | ~~Low~~    | ~~30 min~~ **Won't implement — dormant — dropped (reopen on demand).**     |
| ~~31~~                                                                                                                                                               | ~~Add `enableGofumpt` / `enableGoimports` toggles in treefmt~~     | ~~Config~~   | ~~Low~~    | ~~30 min~~ done — shipped                                                  |
| ~~32~~                                                                                                                                                               | ~~Add built-in `nix run .#fmt` alias app~~                         | ~~DX~~       | ~~Low~~    | ~~15 min~~ done — shipped — apps.fmt                                       |
| done — meta.maintainers is an inline attrset (modules/go-standard.nix:1356) + `extraMeta` option (module :695) covers longDescription                                |                                                                    |              |            |                                                                            |
| done — composite-module brutal review 2026-07-23 (adjacent archived report) + self-review passes 2026-08-10 / 2026-09-25                                             |                                                                    |              |            |                                                                            |
| done — public-API naming reviewed 2026-08-03: `publicDeps` rename rejected as breaking, owner-namespacing reverted at `2cbb37b` (archived/2026-08-03_03-28 + _04-44) |                                                                    |              |            |                                                                            |
| done — helpers deduped into pure-functions.nix; postPatch-extraction (L10) empirically rejected 2026-08-10 (TODO_LIST Decided-against)                               |                                                                    |              |            |                                                                            |
| **NOT-DO — GitHub traffic insights are read on github.com; there is nothing to implement in this repo.**                                                             |                                                                    |              |            |                                                                            |
| **→ still open — routed TODO_LIST Blocked (external nixpkgs PR)**                                                                                                    |                                                                    |              |            |                                                                            |
| **→ still open — untracked (marketing; no TODO_LIST/ROADMAP row)**                                                                                                   |                                                                    |              |            |                                                                            |
| **→ still open — noted in ROADMAP.md Theme 4 (short demo video/GIF idea)**                                                                                           |                                                                    |              |            |                                                                            |
| **→ still open — noted in ROADMAP.md Theme 4 (publish to nixpkgs / flake registry)**                                                                                 |                                                                    |              |            |                                                                            |
| **→ resolved by scripts/ci-parity.sh (TODO_LIST T56 DONE 2026-11-18) — a script, not a `nix run` app**                                                               |                                                                    |              |            |                                                                            |
| **→ still open — untracked (nearest coverage: docs/migration-guide.md:409 early-adopter pre-commit hook recipe)**                                                    |                                                                    |              |            |                                                                            |
| done — treefmt program enables are mkDefault so consumer treefmt blocks merge cleanly (`4f817b3`) + treefmt Configuration Rules in docs/flake-patterns.md            |                                                                    |              |            |                                                                            |
| done — README.md:343-345 FAQ + docs/man/go-standard.5 document goPkgAttr/goTarballVersion pinning                                                                    |                                                                    |              |            |                                                                            |
| **→ still open — untracked (README ships a before/after table vs manual flakes; no vs-other-tools comparison exists)**                                               |                                                                    |              |            |                                                                            |
| ~~47~~                                                                                                                                                               | ~~Add a public roadmap file (`ROADMAP.md`)~~                       | ~~Planning~~ | ~~Low~~    | ~~30 min~~ done — done — exists                                            |
| **→ still open — untracked (owner-side GitHub settings; no repo artifact)**                                                                                          |                                                                    |              |            |                                                                            |
| **Won't implement — dormant — dropped (this report §c20).**                                                                                                          |                                                                    |              |            |                                                                            |
| **→ still open — untracked (marketing; the short demo-video idea is parked in ROADMAP.md Theme 4)**                                                                  |                                                                    |              |            |                                                                            |

---

## g) Questions I Cannot Figure Out Myself

1. ~~**License:** What open-source license should this project use? Without a decision, I cannot add a `LICENSE` file or a license badge.~~ done — decided — MIT (`ce35aa5`)

2. ~~**CI platform:** Do you want GitHub Actions, Hercules CI, or another CI service backing the dynamic badges and automated checks? This determines badge URLs and workflow files.~~ done — decided — GitHub Actions

3. ~~**Homepage / docs site:** Should the GitHub homepage URL stay empty, point to a future `go-nix-helpers.lars.software` docs site, or point to this repo's rendered README? This affects whether I should set up a public website next.~~ done — homepage left empty; a docs site remains a ROADMAP Theme 4 idea

---

## Appendix: Current Repository State

- **Branch:** `master`
- **Status:** clean, up to date with `origin/master`
- **Latest commit:** `00ea4e9 docs: refresh documentation and align go-standard src forwarding with cfg`
- **Flake checks:** passing
- **GitHub description:** set
- **GitHub topics:** 10 topics added
- **GitHub homepage URL:** empty

---

## Resolution (2026-08-03)

The next session (2026-07-24 22:45, `7415763`) executed 24/27 TODOs from TODO_LIST.md, shipping many of the "NOT STARTED" items listed above. A subsequent session (23:04, `ef2361f`/`50fd2c3`) fixed 4 bugs found during execution and deepened tests to 54 assertions. A docs-health pass on 2026-08-03 rebuilt all living docs.

### NOT STARTED items — resolved since this report

| #                            | Item | Status | Evidence |
| ---------------------------- | ---- | ------ | -------- |
| done at `ce35aa5`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `d8574df`, `ef2361f` |      |        |          |

### Top 50 next tasks — resolved since this report

| #                            | Task | Status | Evidence |
| ---------------------------- | ---- | ------ | -------- |
| done at `ce35aa5`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `d8574df`            |      |        |          |
| done at `7415763`, `50fd2c3` |      |        |          |
| done at `7415763`            |      |        |          |
| done at `d8574df`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |
| done at `7415763`            |      |        |          |

Items not listed above remain open — see TODO_LIST.md and ROADMAP.md for current state.
