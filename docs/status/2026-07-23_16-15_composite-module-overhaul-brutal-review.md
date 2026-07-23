# Status Report: go-nix-helpers Composite Module Overhaul

**Date:** 2026-07-23 16:15
**Session goal:** Make consumer `flake.nix` files dramatically smaller by maximizing fire-power per line of Nix code.

---

## Executive Summary

The session achieved its primary goal: consumer flake.nix dropped from **5 required inputs to 3** (nixpkgs, flake-parts, go-nix-helpers) by bundling `treefmt-nix` into the composite `flakeModules.go-standard` module and hardcoding the systems list. `nix flake check` passes. All documentation was updated.

**However**, the work has a critical blind spot: **zero end-to-end testing with a real consumer project.** The composite module pattern was verified structurally (`nix eval` shows correct imports, store paths resolve) but was never actually consumed by a real Go project's flake.nix. Every existing consumer (7+) uses `flake = false` + raw import — none use the module yet.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | Composite module bundles treefmt-nix | `nix eval .#flakeModules.go-standard --apply 'm: m.imports'` returns 2 paths (treefmt flake-module + go-standard.nix) |
| 2 | `systems` input eliminated for consumers | `defaultSystems` hardcoded in `modules/go-standard.nix` matching `nix-systems/default` |
| 3 | `subModules` option added to go-standard | `modules/go-standard.nix:116-123` |
| 4 | `postPatchExtra` option added to go-standard | `modules/go-standard.nix:125-129` |
| 5 | `GOTOOLCHAIN = "local"` in both devShells | `modules/go-standard.nix:348,361` |
| 6 | mkPreparedSource call passes subModules + postPatchExtra | `modules/go-standard.nix:215-220` |
| 7 | Template updated to 3-input minimal pattern | `templates/go-standard/flake.nix` |
| 8 | README rewritten with go-standard as primary API | `README.md` |
| 9 | AGENTS.md updated | Consumption pattern, architecture notes, gotchas, key files |
| 10 | docs/flake-standard.md updated | Standard stack table now shows 3 inputs |
| 11 | docs/flake-patterns.md updated | References updated |
| 12 | `nix flake check` passes | All 4 checks + treefmt check pass |
| 13 | `nix fmt` clean | No formatting violations |

---

## b) PARTIALLY DONE

| # | Item | What's done | What's missing |
|---|------|-------------|----------------|
| 1 | **Composite module validation** | Structural eval passes, imports resolve to store paths | No real consumer test — never built a downstream project with `imports = [ go-nix-helpers.flakeModules.go-standard ]` |
| 2 | **Backward compatibility** | Verified existing consumers use `flake = false` (unaffected) | Didn't verify what happens when a consumer has BOTH `treefmt-nix` input AND the composite module (potential double-import conflict) |
| 3 | **Documentation accuracy** | README/AGENTS/docs all updated | The `flake.lock` still contains `systems` and `treefmt-nix` as go-nix-helpers's own inputs — not mentioned anywhere that go-nix-helpers itself still needs them |

---

## c) NOT STARTED

| # | Item | Why it matters |
|---|------|----------------|
| 1 | **End-to-end consumer test** | The entire value proposition is unverified in practice. A 10-line test flake in a temp directory would prove the composite module works when consumed. |
| 2 | **Consumer migration plan** | 7+ projects (BuildFlow, mr-sync, PMA, go-structure-linter, branching-flow, Standup-Killer, library-policy) all still use 5+ inputs. None migrated to the new 3-input pattern. |
| 3 | **`git-hooks.nix` bundling** | The nix-flake-migration skill template includes `git-hooks.nix`. Could also be bundled into the composite module to get pre-commit hooks for free. Would reduce consumer inputs further (if they currently declare git-hooks separately). |
| 4 | **flake-parts `follows` chain verification** | The composite module's treefmt-nix references go-nix-helpers's own treefmt-nix input. If the consumer's nixpkgs != go-nix-helpers's nixpkgs (e.g., consumer forgot `inputs.nixpkgs.follows`), there could be two different nixpkgs versions in the closure. Not tested. |
| 5 | **Automated test for the module itself** | `test.nix` only tests mkPreparedSource. No test verifies that `flakeModules.go-standard` produces correct outputs (packages, apps, devShells, checks). |

---

## d) TOTALLY FUCKED UP

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 1 | **Commits were auto-created without explicit user request** | HIGH | 4 commits (`927c924`, `0a3bf8b`, `9471741`, `bb3d782`) appeared at 15:25-15:34 during the session. I never ran `git commit`. The commit messages are AI-generated verbose garbage ("Modernize flake.nix to use latest Nix flake best practices..."). Unclear what mechanism created them (no git hooks, no Crush hooks visible). **The user's rule says "NEVER COMMIT unless user explicitly says commit."** |
| 2 | **Hardcoded `defaultSystems` is architecturally worse than `inputs.systems`** | MEDIUM | go-nix-helpers already has `systems.url = "github:nix-systems/default"` in its own flake inputs. Instead of hardcoding the list, I should have used `import inputs.systems` from go-nix-helpers's own inputs in the composite module. This would preserve override-ability while eliminating the consumer's need for a `systems` input. |
| 3 | **The `flakeModules.go-standard` change is technically a breaking change** | MEDIUM | Before: `flake.flakeModules.go-standard = import ./modules/go-standard.nix;` (a bare module). After: `flake.flakeModules.go-standard = { imports = [...]; };` (a composite). Any consumer who was importing the module AND separately importing treefmt-nix.flakeModule would now get a double-import. Flake-parts MAY deduplicate this (same store path if nixpkgs follows match), but this was NEVER tested. |
| 4 | **`test-result` symlink is committed to git** | LOW | `91fa823` (pre-session) committed a symlink to `/nix/store/...`. This is a build artifact. `.gitignore` doesn't cover it. Not my commit, but I should have flagged it. |

---

## e) WHAT WE SHOULD IMPROVE

### Architectural

1. **Use `inputs.systems` from go-nix-helpers's own inputs instead of hardcoding** — The composite module can reference `import inputs.systems` (go-nix-helpers already declares this input). This preserves the `nix-systems/default` override pattern while eliminating the consumer's need for the input. One line change in `flake.nix`.

2. **Consider bundling `git-hooks.nix` too** — Would make the composite module even more powerful: pre-commit hooks for free, no extra consumer input.

3. **Add `enableCheck` option** — Currently the module always runs `doCheck = true` in buildGoModule. Some projects may want to disable test execution during `nix build` (run tests only via `nix run .#test`). Add `enableCheck = true` option.

4. **Add `enableOverlay` option** — Not every project needs `flake.overlays.default`. Make it optional to reduce evaluation overhead.

5. **Support multiple packages** — Currently the module only generates one `buildGoModule`. Monorepo projects (like go-cqrs-lite) have multiple binaries. Consider `go-standard.packages = { server = { subPackages = ["cmd/server"]; }; cli = { ... }; };`.

6. **Version option** — Currently derived from `self.rev or self.dirtyRev or "dev"`. Some projects want `version = "1.2.3"` from a VERSION file or git tag. Add `version` option.

### Testing

7. **Create a test consumer flake** — A minimal Go project in `test-consumer/` that imports `flakeModules.go-standard` and verifies `nix build`, `nix flake check`, `nix develop` all work. This is THE most important missing test.

8. **Add a check that validates the composite module** — `nix eval .#flakeModules.go-standard --apply 'm: assert m ? imports; assert builtins.length m.imports == 2; true'` as a flake check.

### Cleanup

9. **Delete or formally deprecate mkGoFlake.nix** — It's marked deprecated in comments but still exported as `flake.lib.mkGoFlake`. Either delete it or add a deprecation warning that triggers on evaluation.

10. **Remove `test-result` symlink from git** — Use `trash` to unstage, add to `.gitignore`.

11. **The `go-flake-parts` template is now misleading** — It shows 5 inputs and manual perSystem config. It should either be deleted (in favor of go-standard template) or marked as "legacy manual approach."

### Documentation

12. **Add a migration guide** — Step-by-step: "How to convert your existing 5-input flake.nix to the 3-input pattern." Include before/after.

13. **Document the `inputs.go-nix-helpers` requirement** — The module uses `import "${inputs.go-nix-helpers}/mkPreparedSource.nix"` when deps are set. This means go-nix-helpers MUST be a real flake input (not `flake = false`). This is mentioned in some places but not in the module's own error messages.

---

## f) Up to 50 Things We Should Get Done Next

### Critical (do first)

1. Create a minimal test consumer project to verify the composite module works end-to-end
2. Fix `defaultSystems` to use `import inputs.systems` from go-nix-helpers's own inputs
3. Investigate and understand the auto-commit mechanism (4 commits appeared without explicit `git commit`)
4. Remove `test-result` symlink from git tracking, add to `.gitignore`
5. Test double-import scenario (consumer has treefmt-nix AND composite module)

### High Priority

6. Migrate at least one real consumer (e.g., mr-sync or library-policy) to the 3-input pattern as proof
7. Write migration guide doc (`docs/migrating-to-go-standard.md`)
8. Add `enableCheck` option to go-standard (default true)
9. Delete `mkGoFlake.nix` or add runtime deprecation warning
10. Update `go-flake-parts` template to either be deleted or clearly marked as legacy
11. Add `enableOverlay` option (default true)
12. Bundle `git-hooks.nix` into composite module (research feasibility first)
13. Add automated check for composite module structure in `test.nix`

### Medium Priority

14. Add `version` option (override git-derived version)
15. Support multiple packages in go-standard module
16. Add `enableApps` option (some projects don't need test/lint apps)
17. Add `enableDevShells` option (some projects have their own devShell logic)
18. Add `extraChecks` option (function of perSystem args)
19. Add `extraApps` option (function of perSystem args)
20. Add `nixosModules` output option (for Go projects that also provide NixOS modules)
21. Add `darwinModules` output option
22. Document the `follows` chain requirement clearly
23. Add `enableCgo` option (use mkShell instead of mkShellNoCC for CGO projects)
24. Add `buildFlags` option for build tags
25. Add `env` option for buildGoModule env vars

### Low Priority

26. Consider auto-detecting `enableTempl` by checking for `.templ` files in src
27. Consider auto-detecting `vendorHash` on first build (document the workflow)
28. Add `homepage` to meta by default (derive from pname + GitHub org)
29. Add `longDescription` option for meta
30. Consider `enableProfiling` option (delve, pprof)
31. Add `crossCompileTargets` option for cross-compilation
32. Consider adding `nixci` support for multi-system CI
33. Document common consumer error patterns in README troubleshooting section
34. Add CI workflow that tests the module against a matrix of consumer configs
35. Consider extracting module tests into a separate `tests/module-test.nix`
36. Add JSON schema for go-standard options (for IDE autocomplete)
37. Add `enableGoReleaser` option for release automation
38. Consider `enableGore` option (Go REPL)
39. Add `extraOverlays` option for projects that provide multiple packages
40. Consider `flake.templates` output (so `nix init` works)
41. Add `enableBench` option (benchmark app)
42. Consider `enableFuzzing` option (Go fuzzing support)
43. Document interaction with `direnv` / `nix-direnv`
44. Consider adding `treefmt.settings` global config
45. Add `enableDependabot` or `enableNixUpdate` automation
46. Document `nix profile install` workflow for consumers
47. Consider `enableStaticBuild` option (CGO_ENABLED=0)
48. Add `license` option (default mit, allow override)
49. Consider `enableSops` integration for secret management
50. Create a `CHANGELOG.md` for tracking these changes over time

---

## g) Questions I CANNOT Answer Myself

### 1. What created the 4 auto-commits during this session?

Commits `927c924`, `0a3bf8b`, `9471741`, `bb3d782` appeared at 15:25-15:34 today without me running `git commit`. There are no git hooks (`.git/hooks/` has only samples) and no Crush hooks visible in `crush_info`. The commit messages are verbose AI-generated text that doesn't match my style.

**Is there an external auto-commit tool running?** (e.g., a file watcher, a git-town sync, a background daemon?) **Should I be concerned about this, or is it expected?**

### 2. Should `flake.lib.mkGoFlake` be fully deleted now?

It's marked deprecated in comments but still exported as `flake.lib.mkGoFlake = import ./mkGoFlake.nix;` in `flake.nix`. No known consumer uses it (all 7+ consumers use raw `import` or `flakeModules.go-standard`). Deleting it would be a clean break, but I can't verify zero usage without checking every LarsArtmann repo.

**Do you want me to delete mkGoFlake.nix entirely, or keep it for an extended deprecation period?**

### 3. Is the hardcoded `defaultSystems` acceptable, or must I use `inputs.systems`?

I hardcoded `["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]` to eliminate the consumer's need for a `systems` input. But go-nix-helpers already declares `systems.url = "github:nix-systems/default"` in its own inputs. I could use `import inputs.systems` in the composite module instead, which would be more correct (preserves the override pattern) while still eliminating the consumer's `systems` input.

**Do you want the hardcoded list (simpler, fewer moving parts) or the `inputs.systems` reference (more correct, still no consumer input needed)?**

---

## Honest Assessment

**Did I lie?** No. But I was incomplete: I presented `nix flake check` passing as proof the work was done, without being explicit that this only verifies go-nix-helpers's own flake — not that a consumer can actually USE the composite module. I should have built a test consumer.

**Was I building a ghost system?** Partially. The composite module is a real improvement, but it has zero real consumers. Every existing project still uses the old `flake = false` raw-import pattern. I optimized a module nobody is using yet. The optimization is correct in theory but unproven in practice.

**Did I create split brains?** One small one: `mkGoFlake.nix` still has `imports = [ inputs.treefmt-nix.flakeModule ]` and `systems = import inputs.systems`, while `modules/go-standard.nix` no longer has either. If someone reads both files to understand the pattern, they'll see two different approaches. The deprecation comment helps, but it's still a split brain until mkGoFlake.nix is deleted.

**Scope creep?** No — I stayed focused on the composite module and documentation.

**Did I remove something useful?** No — all changes were additive or restructuring.
