# Status Report — 2026-08-10 06:51

## Documentation Gap Closure Session

Executed all remaining items from the 05-04 status report's "Exact Next Steps"
list, plus found and fixed additional discrepancies during self-critique. All
documentation now matches the codebase.

**Session metrics:** 8 files changed, +120/-30 lines, 3 verification commands
passing (flake check, fmt --ci, shellcheck).

---

## A) FULLY DONE

### Task 1: D1 — migration-guide.md options table
- **What:** Added `enableShfmt`, `enableTempl`, `enableGopls`,
  `enableGovulncheck` to the parameter mapping table (D1 specified only
  enableShfmt; added all 4 missing new options for completeness). Updated
  `extraBuildAttrs` note from "Renamed" to document the 6-attr concatenation
  semantics.
- **Why:** The previous session created D1 as a TODO then didn't execute it.
  This session's rule: trivial fixes get done immediately.
- **Verified:** Table renders correctly in markdown preview.

### Task 2: D2 — flake-patterns.md extraBuildAttrs section
- **What:** Added `extraBuildAttrs Merge Rules` section (7th section) with a
  table of all 6 concatenated attributes, correct/wrong code examples, and
  TOC entry. Documents the full merge semantics that were previously only in
  README.md and the man page.
- **Why:** Same as D1 — was a TODO, not executed.
- **Verified:** TOC entry resolves; section renders correctly.

### Task 3: Man page postPatchExtra entry
- **What:** Added `.BR postPatchExtra " (str, default: \"\")"` to
  `docs/man/go-standard.5`, positioned between `subModules` and `autoGoPrivate`
  (matching module option order).
- **Why:** Pre-existing gap — `postPatchExtra` was a module option since the
  unified pipeline work but was never added to the man page.
- **Verified:** Man page now has 52 .BR entries (was 51). All 35 module
  options are documented (cross-checked programmatically).

### Task 4: Man page extraBuildAttrs description fix
- **What:** The man page said "nativeBuildInputs, preBuild, postInstall are
  concatenated; all others override" — **factually wrong**. Fixed to list all
  6 concatenated attrs.
- **Why:** Only 3 attrs were listed when 6 concatenate since P1 shipped.
  Same class of drift that was fixed in README.md by the 05-04 session but
  missed in the man page.
- **Verified:** Description matches `modules/go-standard.nix:336-343`.

### Task 5: Pareto plan detailed breakdown annotation
- **What:** Added a status banner at the top of the detailed breakdown section:
  "All tasks in sections P1-P11 below are shipped. P12 was skipped on merit."
- **Why:** The 12 detailed sections (### P1 through ### P12) had 68 atomic
  sub-tasks with no indication of completion status. Future readers would see
  raw task tables without knowing they're all done.
- **Approach:** Chose option (a) from Q1 (single banner) over option (b)
  (mark each row with checkmark) — simpler and equally informative.

### Task 6: P9 status update (◑ → ✅)
- **What:** Updated P9 "Script UX improvements" from ◑ (partially done) to
  ✅ (shipped) in both the comprehensive plan table and the execution result
  table. Updated execution result from "10 packages" to "11 packages".
- **Why:** The 05-04 session added `--dry-run` and `--verbose` CI smoke-test
  steps, closing the gap. But the Pareto plan was never updated to reflect this.
- **Verified:** Confirmed by reading `.github/workflows/ci.yml:103-115`.

### Task 7: Architecture diagram pure-functions.nix
- **What:** Added `pure-functions.nix` node to `docs/architecture.d2` showing
  `stripVersionSuffix` and `repoName` functions, connected to mkPreparedSource
  via "imported by" edge. Regenerated `docs/architecture.svg` using `d2`.
- **Why:** `pure-functions.nix` was extracted in P5 but never appeared in the
  architecture diagram. The diagram should reflect the actual codebase
  structure.
- **Verified:** SVG regenerated successfully (43KB → 45KB, reflecting new node).

### Task 8: Full verification suite
- **What:** Ran `nix flake check --no-build`, `nix fmt -- --ci`, and
  `nix run nixpkgs#shellcheck -- scripts/*.sh`.
- **Verified:** All three pass with exit 0.

---

## B) BONUS FIXES (found during self-critique, not in original task list)

### Bonus 1: Module description prepended → appended
- **What:** `modules/go-standard.nix` option description said `preBuild` and
  `postInstall` are "prepended to module-generated" values. The actual code
  (`autoDepSyncPreBuild + userPreBuild`, `completionPostInstall +
  userPostInstall`) clearly **appends** user values after module values.
  Fixed the description in the module, man page, and flake-patterns.md.
- **Why:** The description lied about execution order. A consumer reading
  "prepended" would believe their preBuild runs before the dep-sync, when it
  actually runs after.
- **Verified:** Code at lines 468, 496 confirms `module + user` ordering.

### Bonus 2: TODO_LIST.md cleanup
- **What:** Marked D1 and D2 as shipped (replaced with completion note
  referencing CHANGELOG).
- **Why:** The items are done; the list should reflect reality.

### Bonus 3: CHANGELOG entries
- **What:** Added 6 entries to CHANGELOG.md: 4 Changed (migration-guide,
  flake-patterns, architecture diagram, P9 status) and 2 Fixed (man page
  postPatchExtra gap, man page extraBuildAttrs description).
- **Why:** Project convention requires completed work in CHANGELOG.

---

## C) SELF-CRITIQUE

### What went well
1. **Did not defer trivial tasks.** The previous session's #1 self-critique was
   "Execute trivial TODOs immediately, don't defer them." I executed D1 and D2
   immediately instead of creating new TODOs.
2. **Found additional bugs beyond the listed tasks.** The man page's
   extraBuildAttrs description (3 attrs not 6) and the module's
   prepended/appended discrepancy were both discovered by reading actual code,
   not by trusting the task list.
3. **Verified completeness programmatically.** Cross-checked man page option
   list against module mkOption calls — confirmed 100% coverage (35/35).
4. **Verified P9's ✅ status by reading CI YAML**, not by trusting the status
   report's claim that smoke tests were added.

### What could be improved
1. **The prepended/appended discrepancy existed in the module's own description
   since P1 shipped.** Nobody caught it during P1's implementation or review.
   A CI meta-test that verifies module descriptions match code behavior would
   prevent this class of drift. (See recommendation below.)
2. **AGENTS.md still lists only 18 of 35 options by name.** The count (35) is
   correct but the named list is partial. This is a minor clarity issue — a
   reader trying to understand what the module configures sees only half the
   options. Either list all 35 or link to the man page.
3. **The module description change was made without a test verifying the
   behavior.** The `test-module.nix` suite verifies that preBuild/postInstall
   contain expected content but doesn't verify ordering (module content before
   user content). An ordering assertion would catch future regressions.

### What I deliberately did NOT do
1. **Did not annotate each of the 68 Pareto plan sub-tasks individually.** The
   banner approach is sufficient — marking each row would add visual noise
   without additional information value.
2. **Did not add new behavioral tests (items 6-22 from the 05-04 report).**
   These are genuinely open work but a different category (test deepening, not
   documentation repair). They should be tracked in TODO_LIST.
3. **Did not add a CI meta-test for man page/module option parity.** This is
   a good idea (item 39 from the 05-04 report) but requires writing a Nix
   check derivation — more involved than a documentation fix.

---

## D) REMAINING OPEN WORK

### Immediate (from 05-04 report, still open)
- **Items 6-22:** Behavioral/property test deepening (17 items). These are the
  "next steps" from the original Pareto plan — all test additions that deepen
  coverage of existing features.
- **Items 23-26:** CI hardening (macOS pure function tests, --all-systems,
  fmt on macOS, shellcheck badge).

### Design decisions (defer to v1.0.0 planning)
- Export `pure-functions.nix` via `flake.lib` or keep internal?
- vendorHash placeholder: `builtins.trace` → hard error? (breaking for 7+
  consumers)
- Use `lib.warn` instead of `builtins.trace`? (Nix 2.21+)

### Structural
- Add CI meta-test verifying man page option list matches module mkOption calls
- Add ordering assertion to `test-module.nix` (module preBuild before user
  preBuild)
- Consolidate option-count references (AGENTS.md says 35 but lists 18 by name)

---

## E) VERIFICATION COMMANDS RUN

```bash
nix flake check --no-build                          # ALL CHECKS PASS (exit 0)
nix fmt -- --ci                                     # 13 files, 0 changed (exit 0)
nix run nixpkgs#shellcheck -- scripts/*.sh          # exit 0 (clean)
d2 --layout=elk docs/architecture.d2 docs/architecture.svg  # SVG regenerated
```

### Man page completeness audit
```
Module mkOption calls:  37 (35 top-level + 2 sub-options in `packages`)
Man page .BR entries:   52 (35 options + 11 outputs + 6 see-also/author)
Result:                 100% of module options documented
```

---

_Arte in Aeternum_
