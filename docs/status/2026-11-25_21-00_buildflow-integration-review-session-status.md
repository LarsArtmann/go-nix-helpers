# BuildFlow integration review: session status (2026-11-25 21:00)

> Point-in-time snapshot of the session that answered "How can we improve this
> project and integrate it well with BuildFlow?", and of the state that
> session left behind. Companion artifact: the review itself,
> `docs/reviews/2026-11-25_19-50_brutal-self-review.html` (amended 21:10).
> Nothing in this report was implemented beyond documentation: the session was
> a read-only review, and the report ends with three questions for the owner.

## Scope: what this report verified and what it did not

### Verified at report time (21:00 to 21:16 CET), each from a fresh command

| What                  | Command                                                       | Result                                                                                                                          |
| --------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Date                  | `date`                                                        | 2026-11-25 21:00:04 CET (Wednesday)                                                                                             |
| Pinned commit         | `git rev-parse --short HEAD`                                  | `999a3e4`                                                                                                                       |
| Worktree              | `git status --short`                                          | clean at 21:15                                                                                                                  |
| Unpushed commits      | `git rev-list --count origin/master..HEAD`                    | 3: `28f2207` (19:49), `a2d211c` (19:52), `999a3e4` (21:14); origin is `2e8d1c7`                                                 |
| CI on master          | `gh run list --branch master --limit 6`                       | latest run: failure at `2e8d1c7` (17:53:48Z); no runs exist for the 3 unpushed commits                                          |
| Format state          | `shfmt -l -i 2 -s scripts/*.sh`, output line count            | 7 (every shell script is off the pinned 2-space canon)                                                                          |
| Docs row gate at HEAD | `bash scripts/check-docs-annotations.sh .`                    | exit 1: gate 2 FAIL, 11 tables in 7 archived reports INCOMPLETE                                                                 |
| Docs row gate before  | same script in a detached worktree at `e0c4b70`               | gate 1 PASS, gate 2 PASS (worktree removed afterwards)                                                                          |
| Docs-gates battery    | `docs-gates run .` (local binary), before and after this file | before: PASS, 10 of 10 gates. After: FAIL on `cadence`, 16 unarchived reports against a threshold of 15; the other 9 gates PASS |
| Sweep process         | `pgrep -a -f 'buildflow --fix'`                               | none running at 21:00 (one was observed at 19:16 in `library-policy`)                                                           |
| Review integrity      | `html.parser` plus anchor cross-check on the amended file     | 0 parse errors, 9 anchors resolved, 0 inline styles or handlers, 82,714 bytes                                                   |

### Verified earlier this session (19:10 to 19:45), not re-run at report time

| What                                | Evidence                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CI failure cause                    | `gh run view 45669527657 --json jobs` and `--log-failed`: `check (ubuntu-latest)` failed at step Format Check with "formatted 16 files (7 changed)"; `check (macos-latest)` cancelled                                                                                                                                                                                                                                                                                                                                           |
| What commit 2e8d1c7 changed         | `git show --stat HEAD` at the time: 39 files; `git diff -w --stat HEAD^ HEAD -- scripts/`: only `check-rows.py` changed beyond whitespace                                                                                                                                                                                                                                                                                                                                                                                       |
| BuildFlow verdict on this repo      | `buildflow --dry-run --verbose` (binary `ff4aaa4`): "BuildFlow failed go-nix-helpers 105/139 (44 findings, 15 info, 21 no-op, 3 skipped via config, 51 not applicable)", 9 failed steps                                                                                                                                                                                                                                                                                                                                         |
| BuildFlow cannot see treefmt here   | same dry run: `treefmt: no files matching: treefmt.toml, .treefmt.toml`                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| nix-checker findings here           | `buildflow -s nix-checker --format finding`: 32 findings (7 error, 11 warning, 14 info), summarised with a script                                                                                                                                                                                                                                                                                                                                                                                                               |
| BuildFlow nix-fmt false green       | `buildflow -s nix-fmt` (detect only): "BuildFlow passed go-nix-helpers 1/1", "formatted 18 files (0 changed)"                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `checks.vendor-hash` is a real gate | `nix derivation show .#checks.x86_64-linux.vendor-hash` in go-output: the go-modules derivation is listed under `inputs.drvs`                                                                                                                                                                                                                                                                                                                                                                                                   |
| No default package here             | `nix eval .#packages.x86_64-linux --apply builtins.attrNames` in this repo: `[ ]`                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Fleet recounts                      | 61 go-standard consumers; 39 with `.buildflow.yml`; 38 tab-indented versus 5 two-space script repos; 20 set `goExperiment`, 3 mirror it in `.buildflow.yml`; 10 own vendor-hash apps; 15 use `import ./vendorHash.nix`; 6 distinct locked revisions; 60 of 61 use the `github:` scheme; 200 of 224 `.editorconfig` files carry a `[*]` tab rule; 255 of 273 `dprint.json` files use remote plugin URLs; 107 of 178 repos with `go.mod` and `flake.nix` have no go-nix-helpers reference; 26 commits since the only tag `v0.1.0` |
| Sweep damage detail                 | `git show e0c4b70:TODO_LIST.md` line 69 versus HEAD: the T86 row is intact before and truncated after; its remaining text is absent at HEAD                                                                                                                                                                                                                                                                                                                                                                                     |

### Not verified here, and why

- **No `nix build`, `nix flake check` or `nix fmt` was run in this session.** The canon decision is the owner's, and `nix fmt` would decide it. Every "CI will be green after step X" below is a prediction, not a measurement.
- **CI for `28f2207`, `a2d211c` and `999a3e4`:** not pushed, so no runs exist.
- **Whether the other reformatted Markdown files lost text:** not analysed. A normalised comparison (whitespace, pipes and emphasis markers stripped) differs for 27 of the 30 files commit `2e8d1c7` touched, which is expected from dprint's escaping and table changes.
- **Visual render of the HTML review:** no headless browser was used. Only mechanical checks ran.
- **Audit-only numbers, not recounted by me:** the pin-form split (59 of 69 inputs track a branch), SystemNix's 20 lock nodes, the templ-generate skip list beyond crush-daily, dnsblockd's freshness-oracle quote, the 30 consumers with `enableCheck = false`, and the possible `checks.vendor-hash` collision in go-humanize-linter.
- **Module assertion counts** (228 and 237 both appear in `AGENTS.md`): not recounted.
- **nix-hash-fix on a per-system `vendorHashes` attrset:** read from source, never exercised.
- **Who ran BuildFlow here at 18:52:** inferred from tool fingerprints and from the live sweep process, never observed directly.
- **BuildFlow's tree:** its daemon kept committing during the session (`9bd42377b`, then `31a811b65`, then `766db034b`). Line numbers were read in that range and not re-checked.
- **BuildFlow binary:** `ff4aaa4`, 23 commits behind its repo at 19:19 (its own doctor warned). All BuildFlow evidence comes from that binary.
- **docs-gates:** run from `/home/lars/go/bin/docs-gates`, not from the `nix run` form `AGENTS.md` prescribes.
- **This file's own gates:** `scripts/check-rows.py` passes on it, and the full row gate still lists the same 11 offenders, none from this file. `docs-gates` turns red on `cadence` because this file exists (section (d), item 16).

## a) FULLY DONE

| # | Item                                                              | Evidence                                                                                                                                       | Scope                        |
| - | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| 1 | Root-cause review of the go-nix-helpers and BuildFlow integration | `docs/reviews/2026-11-25_19-50_brutal-self-review.html`, daemon commit `28f2207`; integrity checks pass                                        | no code touched              |
| 2 | Mechanism of the script tab drift, verified in source             | `BuildFlow/tools/providers/format_ownership.go:97-141`, `additional_tools.go:22-32`, `.editorconfig:8`, `modules/go-standard.nix:1972-1973`    | replaces the editor story    |
| 3 | Proof that `checks.vendor-hash` really builds the vendor FOD      | `nix derivation show` in go-output lists the go-modules derivation under `inputs.drvs`                                                         | settles a consumer doc claim |
| 4 | `AGENTS.md` corrections (4 edits)                                 | daemon commit `a2d211c`, read back with `git show HEAD:AGENTS.md`: consumer count 61 (was "7+"), `nix fmt` scope, tab-drift bullet, canon note | documentation                |
| 5 | `CONTRIBUTING.md` corrections (2 one-line edits)                  | included in daemon commit `999a3e4` (21:14:58)                                                                                                 | documentation                |
| 6 | Fleet recounts (12 numbers)                                       | each from a saved command; listed in the scope section                                                                                         | evidence for the review      |
| 7 | BuildFlow provider inventory and fleet audit (3 subagent reports) | key claims spot-verified at source by me; the rest is labelled audit-only in the scope section                                                 | evidence for the review      |
| 8 | Dated amendment to the shipped review (21:10)                     | section "Amendments" corrects the false "harmless" claim; included in `999a3e4`; integrity re-checked                                          | own error, fixed             |
| 9 | Scratch fragment removed after splicing                           | `body.html` moved to trash                                                                                                                     | hygiene                      |

## b) PARTIALLY DONE

| # | Item                                               | Works now                                                                     | Still open                                                                                      | Blocker                     | Effort |
| - | -------------------------------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | --------------------------- | ------ |
| 1 | Restore master CI                                  | Diagnosis complete: cause, actor mechanism and the 7 affected files are known | The fix itself. Both variants are one small change                                              | decision D1 (question 1)    | S      |
| 2 | Repair the sweep's damage to docs                  | Damage measured: 11 tables in 7 archived reports, 1 truncated TODO row        | Restore or re-annotate. These are not my changes, so I did not revert them                      | your call (question 3)      | S      |
| 3 | Mechanical checklist of the HTML review            | Parse, anchors, placeholders, inline-style checks pass                        | The kit's "one render screenshot for the record" was not done                                   | none                        | S      |
| 4 | BuildFlow evidence for this repo                   | Two dry runs, one detect-only `nix-fmt`, two `nix-checker` runs               | No real `--fix` run was observed; what it does to `.nix` files and docs is inferred from 18:52  | a real run mutates the tree | S      |
| 5 | Contract design (review plan step 4)               | Four outputs proposed, each mapped to data that already exists                | Not prototyped; the effect of `language: nix` in `.buildflow.yml` was not tested                | none                        | M      |
| 6 | Audit-only claims                                  | Six items named in the scope section                                          | Recount each at source                                                                          | none                        | S to M |
| 7 | Harvest of section (f)                             | 50 tasks listed below                                                         | Not written into `TODO_LIST.md` or `ROADMAP.md`. The status-report skill expects a HARVEST pass | you asked me to wait        | M      |
| 8 | `AGENTS.md` assertion-count mismatch (228 and 237) | Noticed                                                                       | Not recounted, not fixed                                                                        | none                        | S      |

## c) NOT STARTED

Nothing below was started. The request was a question, then "report and wait".

| #  | Planned work                                                                                                    | Why not started                                    | Priority |
| -- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- | -------- |
| 1  | Canon fix for the Format Check (review step 1)                                                                  | blocked on D1                                      | critical |
| 2  | `.buildflow.yml`, hook, `SECURITY.md`, actionlint, cue-vet and dependabot fixes, retire `ci-parity.sh` (step 2) | waiting for instructions                           | high     |
| 3  | File the 7 BuildFlow issues (step 3). Diagnoses are verified; none is filed                                     | waiting for instructions                           | high     |
| 4  | Contract exports from go-standard (step 4)                                                                      | waiting for instructions                           | high     |
| 5  | Retire the vendorHash algorithm from go-standard (step 5)                                                       | blocked on D2                                      | high     |
| 6  | Eight go-standard gap closures, each deleting a block of BuildFlow's `flake.nix` (step 6)                       | sequenced after step 4                             | medium   |
| 7  | One flake-lint rule set, BuildFlow M8 (step 7)                                                                  | needs your OK for Go code in this repo             | medium   |
| 8  | Tag `v0.2.0`, CHANGELOG entries, unified URL form, template updates (step 8)                                    | URL form blocked on D3; the tag is not             | high     |
| 9  | Cleanup list (step 9)                                                                                           | waiting for instructions                           | low      |
| 10 | Repair of the sweep's docs damage: T86 row and the 11 tables                                                    | not my changes; needs your call                    | high     |
| 11 | Push of the 3 pending commits once CI is green locally                                                          | the daemon here does not push; needs your go-ahead | high     |
| 12 | HARVEST of section (f) into `TODO_LIST.md` and `ROADMAP.md`                                                     | you asked me to wait                               | high     |
| 13 | Make CI build `checks.docsAnnotations` so sweep damage becomes visible                                          | noticed at 21:03; not started                      | high     |
| 14 | Screenshot of the HTML review; removal of this session's `/tmp` scratch (6 evidence files, 1 empty dir)         | trivial; waiting                                   | low      |

## d) TOTALLY FUCKED UP

| #  | What is broken                                                       | Severity                                                                                                          | Root cause                                                                                                                                | Mitigation                                                                          |
| -- | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 1  | Master CI is red at the pushed HEAD `2e8d1c7`                        | blocks a green master. The 3 newer commits carry the same scripts and will fail too                               | BuildFlow's `shfmt` lane writes tabs; treefmt is pinned to 2 spaces; BuildFlow cannot see treefmt config declared in a module             | not applied: `nix fmt`, or flip the pin. Waits on D1                                |
| 2  | `checks.docsAnnotations` is red at HEAD, green at `e0c4b70`          | local `nix flake check` fails. CI is blind to it (`--no-build`)                                                   | commit `2e8d1c7`: dprint turned bare verdict lines after 11 header-only tables in 7 archived reports into table rows                      | none applied. Restore from `e0c4b70`, or re-annotate                                |
| 3  | `TODO_LIST.md` line 69, row T86, is truncated                        | one open task is unreadable; its text is recoverable from `e0c4b70`                                               | commit `2e8d1c7`: dprint split the cell at a pipe inside a backtick span and dropped the rest                                             | none applied                                                                        |
| 4  | go-nix-helpers cannot pass BuildFlow                                 | a BuildFlow pre-commit hook would block every commit here                                                         | 9 steps fail on `test-assets/` fixtures; 7 error-level `nix-checker` findings are false                                                   | none. Needs `.buildflow.yml` plus BuildFlow fixes                                   |
| 5  | BuildFlow reports this repo's formatting as green                    | false green in the tool the fleet is being swept with                                                             | the `nix-fmt` round-trip copy carries only `.nix` files                                                                                   | none. BuildFlow fix                                                                 |
| 6  | My shipped review called the docs reformat "harmless"                | a reader would have skipped items 2 and 3                                                                         | I read the diff size and the CI failure but did not run the docs gates on the swept tree                                                  | dated amendment added at 21:10                                                      |
| 7  | I miscounted in my interim message ("59 of 64"; correct is 38 of 43) | wrong number reached you once                                                                                     | hand count of a printed table                                                                                                             | corrected in the final answer and in the review                                     |
| 8  | Three vendorHash repairers coexist (fleet-wide, older than today)    | damage recorded in go-aichat, CV and pbx-lens; the module's app exits 1 for 15 consumers                          | two repos give opposite advice; no owner                                                                                                  | none. Waits on D2                                                                   |
| 9  | Toolchain environment is hand-synced                                 | latent today, live on any pre-1.27 toolchain                                                                      | 17 of 20 consumers do not mirror `goExperiment`; BuildFlow's hook template hardcodes both values                                          | none                                                                                |
| 10 | `.editorconfig` line 8 says tab for every file type                  | any editorconfig-aware tool re-tabs scripts and the 4-space Python file                                           | fleet template, never aligned with the canon                                                                                              | none                                                                                |
| 11 | The daemon commits whatever is on disk                               | both breakages above were swept in within about 40 seconds of the run                                             | no format or gate check before the auto-commit (crush-config T88 exists for this)                                                         | none here                                                                           |
| 12 | The sweep used a BuildFlow binary 23 commits behind its repo         | every verdict it wrote may not reflect BuildFlow HEAD                                                             | binary freshness is a warning, not a block                                                                                                | none. BuildFlow side                                                                |
| 13 | Pre-existing, noticed, unfixed: `docs/ci-workflow.yml`               | the consumer drop-in builds `checks.x86_64-linux.test`, which needs `enableTestCheck`                             | default is false                                                                                                                          | none                                                                                |
| 14 | Pre-existing, noticed, unfixed: lock-freshness job                   | will collide with the nix2container pin policy the day that input moves                                           | `ci.yml:244-266` versus `flake.nix:19-23`                                                                                                 | none                                                                                |
| 15 | Side effects I caused outside the repo                               | low                                                                                                               | 5 BuildFlow runs here wrote rows to BuildFlow's shared state and cache; one reported a `dprint-format` timing regression (35 ms to 79 ms) | none. Disclosed                                                                     |
| 16 | `docs-gates` is red on `cadence` since this report exists            | the battery fails until the archive ritual runs. CI is not affected: the battery is not part of `nix flake check` | this report is the 16th unarchived report in `docs/status/`; the threshold is 15                                                          | none applied. The archive ritual moves other reports and waits for your instruction |

## e) WHAT WE SHOULD IMPROVE

| #  | Pattern that is suboptimal                                         | Impact                                                       | Suggested fix                                                                                                    |
| -- | ------------------------------------------------------------------ | ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| 1  | Two tools guess about each other instead of reading a contract     | every split brain in the review                              | go-standard publishes formatter ownership, toolchain env, hash locations and the templ pin; BuildFlow reads them |
| 2  | No test runs the module's output through BuildFlow                 | the formatter war recurred three times                       | a consumer-contract check: `nix fmt` must be a no-op after a BuildFlow fix run                                   |
| 3  | The reference consumer is not a BuildFlow citizen                  | integration bugs surface in consumers first                  | `.buildflow.yml` and hook in this repo; this repo must pass BuildFlow before a release                           |
| 4  | Canon decisions check one writer only                              | the 2026-11-18 pin fights three other writers                | a checklist for canon changes: BuildFlow lanes, `.editorconfig` template, fleet state                            |
| 5  | A reformat is judged by diff size                                  | I called real damage harmless                                | run `scripts/check-docs-annotations.sh` and `docs-gates run .` on the swept tree; both take under a second       |
| 6  | Numbers are hand-counted                                           | one wrong figure reached you                                 | publish only numbers that come from a saved command                                                              |
| 7  | dprint rewrites annotated tables                                   | 11 tables broke, 1 TODO row lost text                        | exclude `docs/status/**` and `docs/planning/**` from the dprint lane, or keep pipes out of table cells           |
| 8  | The row-uniformity gate is not built by CI                         | item 2 of section (d) was invisible                          | add `checks.docsAnnotations` to a CI job that builds                                                             |
| 9  | The auto-commit daemon has no gate                                 | broken states are committed within seconds                   | crush-config T88: treefmt and the gates before every daemon commit                                               |
| 10 | Fleet sweeps run on a stale binary                                 | verdicts drift from HEAD                                     | make binary freshness a hard block for `--fix` sweeps                                                            |
| 11 | `AGENTS.md` counts rot                                             | "7+" consumers for 61; two assertion counts                  | derive the counts in a check (ROADMAP theme 6)                                                                   |
| 12 | Parallel subagents hit a provider rate limit                       | one of four died; 20 minutes lost                            | at most two parallel subagents per provider                                                                      |
| 13 | Attributions are made without `git blame`                          | I reported the T86 truncation as old drift                   | blame before labelling anything "pre-existing"                                                                   |
| 14 | Each tool absorbs the other's job                                  | more options, more overlap                                   | scope rule: go-standard keeps facts and builds; BuildFlow keeps the quality loop                                 |
| 15 | The status-report skill writes first and counts reports afterwards | this report pushed `docs/status/` over the archive threshold | pre-flight the unarchived count before writing; at the threshold, run the archive ritual in the same session     |

## f) Up to 50 things to get done next

Ranked by impact. The first 12 unblock the repo; 13 to 19 are BuildFlow work; 20 to 27 need a decision; 28 to 34 are go-standard features; 35 to 50 are quality, cleanup and documentation. A larger list than 25 is a brainstorm: items 35 to 50 are ROADMAP fuel unless you pick them. This section has not been harvested into `TODO_LIST.md`.

| #  | Task                                                                                                                                                                                           | Impact   | Effort | Category      | Repo           |
| -- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------ | ------------- | -------------- |
| 1  | Decide D1: shell indentation canon, tabs or 2 spaces                                                                                                                                           | Critical | S      | Decision      | owner          |
| 2  | Restore the Format Check per D1: tabs means change the two pins at `modules/go-standard.nix:1972-1973` and the option text; 2 spaces means run `nix fmt`                                       | Critical | S      | Bug           | go-nix-helpers |
| 3  | Restore `TODO_LIST.md` row T86 from `e0c4b70`                                                                                                                                                  | High     | S      | Bug           | go-nix-helpers |
| 4  | Repair the docs row gate: restore the 7 archived reports from `e0c4b70`, or re-annotate the 11 tables                                                                                          | High     | S      | Bug           | go-nix-helpers |
| 5  | Fix `.editorconfig`: make `[*.sh]` match the chosen canon and `[*.py]` 4 spaces                                                                                                                | High     | S      | Bug           | go-nix-helpers |
| 6  | Add `.buildflow.yml`: keep BuildFlow's Go lanes out of `test-assets`, exclude fixture placeholders from `nix-checker`                                                                          | High     | S      | Quality       | go-nix-helpers |
| 7  | Make CI build `checks.docsAnnotations` (or run `scripts/check-docs-annotations.sh` as a step)                                                                                                  | High     | S      | Quality       | go-nix-helpers |
| 8  | Archive ritual for `docs/status/`: 16 unarchived reports against a threshold of 15; verify routed rows with `check-rows`, then `git mv` the oldest to `archived/` with a live-remainder banner | High     | M      | Documentation | go-nix-helpers |
| 9  | Install the BuildFlow pre-commit hook here, after items 6 and 15                                                                                                                               | Medium   | S      | Quality       | go-nix-helpers |
| 10 | Add `SECURITY.md`                                                                                                                                                                              | Medium   | S      | Documentation | go-nix-helpers |
| 11 | Fix the actionlint findings in `ci.yml` (SC2086 at lines 76 and 129; the `if: false` job at line 273)                                                                                          | Medium   | S      | Bug           | go-nix-helpers |
| 12 | Resolve the cue-vet finding: matrix `runs-on` against the fleet CI policy                                                                                                                      | Medium   | S      | Quality       | go-nix-helpers |
| 13 | File: formatter ownership is blind to treefmt config declared in an imported module (61 consumers)                                                                                             | Critical | S      | Bug           | BuildFlow      |
| 14 | File: Go detection and module walks include fixture directories; `go_mod_ignore_dirs` is ignored by `findGoModDirs` and `findAllModuleDirs`                                                    | High     | S      | Bug           | BuildFlow      |
| 15 | File: `nix-checker` reports option definitions and test placeholders as errors                                                                                                                 | High     | S      | Bug           | BuildFlow      |
| 16 | File: `nix-fmt` false green, because the round-trip copy carries only `.nix` files                                                                                                             | High     | S      | Bug           | BuildFlow      |
| 17 | File: the pre-commit template hardcodes `GOEXPERIMENT` and `CGO_ENABLED`                                                                                                                       | Medium   | S      | Bug           | BuildFlow      |
| 18 | File: `nix build .` on flakes that have no default package                                                                                                                                     | Medium   | S      | Bug           | BuildFlow      |
| 19 | Exercise, then file: `nix-hash-fix` on a per-system `vendorHashes` attrset                                                                                                                     | Medium   | M      | Bug           | BuildFlow      |
| 20 | Decide D2: which tool owns vendorHash repair                                                                                                                                                   | Critical | S      | Decision      | owner          |
| 21 | Decide D3: pin policy, latest-tracking or tag pins                                                                                                                                             | High     | S      | Decision      | owner          |
| 22 | Tag `v0.2.0` and record the post-tag fixes under Fixed in `CHANGELOG.md`                                                                                                                       | High     | S      | Release       | go-nix-helpers |
| 23 | Unify the go-nix-helpers URL in `AGENTS.md`, `README.md`, the migration guide and the template per D3                                                                                          | Medium   | S      | Documentation | go-nix-helpers |
| 24 | Publish `flake.treefmtConfigFile` from go-standard (the generated treefmt.toml path)                                                                                                           | High     | M      | Feature       | go-nix-helpers |
| 25 | Publish `flake.toolchainEnv` from go-standard                                                                                                                                                  | High     | M      | Feature       | go-nix-helpers |
| 26 | Publish `flake.vendorHashLocations` and the pinned templ CLI path                                                                                                                              | Medium   | M      | Feature       | go-nix-helpers |
| 27 | Retire the vendorHash algorithm from go-standard per D2; update T76 and the migration guide                                                                                                    | High     | S      | Feature       | go-nix-helpers |
| 28 | Strip version-targeted replaces for modules that get an injected `_local_deps` replace (deletes BuildFlow `flake.nix:488-490`)                                                                 | High     | M      | Feature       | go-nix-helpers |
| 29 | Inject replaces into extra module files (deletes BuildFlow `flake.nix:492-501`)                                                                                                                | High     | M      | Feature       | go-nix-helpers |
| 30 | Detect public dependencies automatically so `validatePrivateDeps` can stay on (ROADMAP theme 5)                                                                                                | High     | L      | Feature       | go-nix-helpers |
| 31 | Option to put the built package on the devShell PATH                                                                                                                                           | Medium   | M      | Feature       | go-nix-helpers |
| 32 | Default `version` to the short rev instead of the 40-character rev                                                                                                                             | Medium   | S      | Feature       | go-nix-helpers |
| 33 | Fix the `apps.fmt` condition at `modules/go-standard.nix:1678` and add a module-test assertion                                                                                                 | Medium   | S      | Bug           | go-nix-helpers |
| 34 | Add a `GOWORK` option and an extra-overlay-entries option                                                                                                                                      | Low      | M      | Feature       | go-nix-helpers |
| 35 | Add a consumer-contract check: `nix fmt` is a no-op after a BuildFlow fix run                                                                                                                  | High     | M      | Quality       | go-nix-helpers |
| 36 | HARVEST this section into `TODO_LIST.md` and `ROADMAP.md`                                                                                                                                      | High     | M      | Documentation | go-nix-helpers |
| 37 | Push the 3 pending commits once CI is green locally (needs your go-ahead)                                                                                                                      | High     | S      | Release       | go-nix-helpers |
| 38 | Retire `scripts/ci-parity.sh`; move its three unique legs into `check_scripts` or `ci.yml`; add a BuildFlow CI job and drop the duplicated shellcheck job                                      | Medium   | S      | Cleanup       | go-nix-helpers |
| 39 | Reconcile the lock-freshness job with the nix2container pin policy                                                                                                                             | Medium   | S      | Quality       | go-nix-helpers |
| 40 | Vendor the dprint plugins locally, or delete `dprint.json` and let BuildFlow regenerate it                                                                                                     | Medium   | S      | Quality       | go-nix-helpers |
| 41 | Keep dprint out of `docs/status/**` and `docs/planning/**`, or make those tables dprint-stable                                                                                                 | Medium   | S      | Quality       | go-nix-helpers |
| 42 | Tell consumers which workarounds are stale: four `projectRootFile` overrides, five templ formatter wrappers, erraudit's vendor-hash note                                                       | Medium   | M      | Cleanup       | consumers      |
| 43 | Support BuildFlow CG3 (codegen before formatters) and a pinned templ CLI path                                                                                                                  | Medium   | L      | Bug           | BuildFlow      |
| 44 | Fix or delete `docs/ci-workflow.yml`, the consumer drop-in                                                                                                                                     | Medium   | S      | Documentation | go-nix-helpers |
| 45 | Template: SHA-pin the actions in `templates/ghcr-push-workflow.yml`, ship a `.buildflow.yml`, drop `go 1.26` and the manual hash dance from `generate-flake.sh`                                | Medium   | S      | Feature       | go-nix-helpers |
| 46 | M8: move the `nix-checker` detection core into a Go module here, fold in `nix-lint.sh`, delete `nix-lint.sh` (needs your OK for Go code here)                                                  | Medium   | L      | Feature       | go-nix-helpers |
| 47 | Docs follow-ups from this session: strike `ROADMAP.md:102-104` (the floor check is implemented), update the `FEATURES.md` script table, record the dprint lesson in `AGENTS.md`                | Low      | S      | Documentation | go-nix-helpers |
| 48 | Recount the module assertions and fix the 228 versus 237 mismatch in `AGENTS.md`                                                                                                               | Low      | S      | Documentation | go-nix-helpers |
| 49 | Wire `scripts/check-concurrent-actors.sh` as a `check_scripts` entry, or delete it; deprecate one of `checks.format` and `checks.treefmt`                                                      | Low      | S      | Cleanup       | go-nix-helpers |
| 50 | Add the missing dependabot entry for `test-assets/mock-templ-stale`, or document why fixtures are tracked                                                                                      | Low      | S      | Quality       | go-nix-helpers |

## g) Questions I can not answer myself

**Question 1, the shell canon (D1).** Do you want tabs or 2 spaces for shell
scripts in this repo and as the go-standard default? I measured every writer:
shfmt's default, treefmt-nix's current default, BuildFlow's `shfmt` lane and
the `.editorconfig` template produce tabs; 38 of 43 consumers with classifiable
scripts are tabbed; the 2-space pin protects one consumer with 24 scripts. I
cannot pick because it reverses your 2026-11-18 decision and both answers are
self-consistent. This blocks items 2, 5 and 37 of section (f).

**Question 2, the vendorHash repair owner (D2).** Should BuildFlow's
`nix-hash-fix` or a Nix app from go-standard be the one repair? The BuildFlow
skill and BuildFlow's own `AGENTS.md` prescribe opposite answers, and
`TODO_LIST.md` T76 prescribes a third direction. Consumers recorded damage
from `nix-hash-fix` (go-aichat, CV, pbx-lens). I cannot pick because it is a
fleet policy, not a fact I can read. This blocks items 19 and 27.

**Question 3, the sweep.** Was it you who ran `buildflow --fix --build-mode=full`
here at 18:52, will it run here again, and do you want its output kept or
reverted? I cannot tell from the repo. It matters because the sweep broke two
gates and one TODO row (section (d), items 1 to 3): keeping its output means
the canon and the row gate follow it, reverting means restoring 25 docs from
`e0c4b70` and reformatting 7 scripts. I did not revert anything because those
are not my changes. This blocks items 2, 3 and 4.

Two further decisions did not get a question: the pin policy (D3) and whether
go-nix-helpers may host Go code (item 46). Both are in section (f).

## Session timeline

| Time     | Event                                                                                                           |
| -------- | --------------------------------------------------------------------------------------------------------------- |
| 18:52    | A BuildFlow run reformats this repo: 7 scripts to tabs, 25 docs, 1 Python file (inferred)                       |
| 18:53:36 | Daemon commit `2e8d1c7` sweeps in 39 files, including a `flake.lock` bump                                       |
| 18:53:48 | CI run 45669527657 starts on `2e8d1c7` and fails at the Format Check                                            |
| 19:07:37 | An SSH session opens; a `buildflow --fix --build-mode=full` sweep runs from it (observed 19:16)                 |
| 19:10    | Your question starts the review                                                                                 |
| 19:19    | BuildFlow dry runs here; root cause read in BuildFlow's source                                                  |
| 19:29    | Eval-only proof for `checks.vendor-hash`; fleet recounts                                                        |
| 19:48    | Review spliced into the kit template                                                                            |
| 19:49:15 | Daemon commit `28f2207` (the review)                                                                            |
| 19:52:15 | Daemon commit `a2d211c` (`AGENTS.md`, 4 corrections)                                                            |
| 19:57    | `CONTRIBUTING.md` edits                                                                                         |
| 21:00    | Status report requested; gates baselined; the docs row gate and the T86 truncation are found                    |
| 21:10    | Dated amendment added to the review                                                                             |
| 21:14:58 | Daemon commit `999a3e4` (`CONTRIBUTING.md` and the amended review)                                              |
| 21:16    | This report is written at pinned commit `999a3e4`                                                               |
| 21:20    | Gates run on this file: `check-rows` PASS; `docs-gates` FAIL on `cadence` (16 unarchived reports, threshold 15) |

No manual commit was made: the harness forbids commits without your request.
The daemon picked up every file within about a minute. Nothing was pushed.

One gate is red because of this report: `docs-gates` on `cadence`, since it is
the 16th unarchived report in `docs/status/`. The archive ritual (section (f),
item 8) is the fix. I did not run it, because it moves other reports and you
asked me to wait.

Now waiting for instructions.
