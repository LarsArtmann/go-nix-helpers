# Status Report — Registry Decision Landed, Master CI Recovery, Push-Truth Correction

**Date:** 2026-11-17 19:43 · **Session window:** ~19:05–19:43 · **Repo:** go-nix-helpers (master `1dc75df`, ahead 4 of origin)

## Scope line — what this report verified, and what it did not

VERIFIED this session, with commands:

- Local master `1dc75df`, **ahead 4** of origin (origin at `214bbdb`); tree clean — `git status` / `git rev-list` after `git fetch` (19:43).
- **Origin already carries the container foundation**: one push at 18:55 delivered everything through `214bbdb`. Pusher identity NOT determinable from inside the repo.
- **Master CI red on EVERY push since ≥2026-10-30** — `gh run list` (8 ci.yml runs, all failures; oldest checked 2026-10-30) + per-job logs of run `44142336281`.
- Three CI root causes diagnosed from logs and **fixed, verified locally**: moduleTest **218/218** (`nix build .#checks.x86_64-linux.moduleTest` + `nix log`), `nix flake check --all-systems --no-build` all-pass, shellcheck clean (same command CI runs: `nix run nixpkgs#shellcheck -- scripts/*.sh`), `nix fmt` idempotent, `docsAnnotations` gate green ×3 reruns.
- Fleet remote scan (250+ repos): **16 Forgejo-remote** projects (`forgejo.home.lan`, `evo-x2.home.lan`); PapDashboard is GitHub-remote (pilot unaffected by the registry decision).
- Daemon behavior: **commits only** — it did not push the follow-up commits in a 13-minute watcher window; my interim "daemon pushes this repo" claim was falsified and corrected (`1dc75df`).

NOT verified (and why):

- **CI verdict on the 4-commit fix chain** — unpushed; gated on owner push approval (§g Q1). Origin's CI stays red until they land.
- **containerSmoke rebuild** (full `nix flake check` WITH builds) — only `--no-build` was run; `container.nix` untouched this session so risk is low, but CI will rebuild it and that is unproven locally.
- **Darwin-leg proof of the vendorHashes fix** — correct by construction on linux (behavior byte-identical) and by symmetry on darwin, but the real proof is the CI macos leg (pending push).
- Who pushed at 18:55; who created `origin/systemnix-vn-version-fix`; whether the concurrent session (source of `214bbdb`'s tab-reindent) is still active.

---

## Self-review (brutal, per the questions asked)

### What did you forget?

1. **Fetch-first discipline at session start.** The inherited summary said "~10 ahead, verify with git status" and I treated `git status`'s missing `[ahead N]` as a curiosity before fetching. The real state (everything already pushed, CI red for weeks) was knowable in the first 30 seconds; I got it at minute ~10 as a side quest.
2. **The 15-00 report's own registry question (§g.2 there) was never annotated** — only the 18-52 report's §g.3 got the ANSWERED verdict. Its items were harvested into TODO_LIST (which IS updated), so nothing is lost, but the older report now reads unanswered.
3. **No check for concurrent-session activity** before editing: the scripts' tab-reindent proves another actor touched this repo minutes before I started. I never looked for live-activity markers; if that session is still running, it can re-drift the scripts at any time.
4. **Full-build verification skipped.** `nix flake check --no-build` + targeted check builds is not the same battery CI runs (CI builds everything per OS). Low risk, honestly unproven.

### What is stupid that we do anyway?

1. **CI badges went unread for ~3 weeks** while every session (mine included, until today) claimed "all gates green" from LOCAL runs. The local battery and the CI matrix are different gates — shellcheck and the darwin leg exist only in CI. A green local `nix flake check` told us nothing about either.
2. **The daemon sweeps whatever is on disk** — foreign tab-reindents, half-finished edit batches (it published 4 of my 6 in-flight edits in `214bbdb`, briefly putting annotations on origin that referenced not-yet-committed code). We accept this and keep only CI as the backstop.
3. **Test configs hardcoded a system string for 7 weeks** (2026-09-30 → today) with the failure visible only on a CI leg nobody looked at. The assertion was "green" everywhere it was ever run locally.

### What could you have done better?

1. **The worst mistake of the session: I wrote a causal claim into permanent docs labeled "verified" when I had observed only a correlation.** "The daemon pushes this repo (verified 2026-11-17)" — origin==local at one instant proves only that SOMEONE pushed. A 13-minute watcher falsified the mechanism. Corrected in `1dc75df` across three files within ~40 minutes, but the failure class is exactly the one I'm supposed to gate: unverified inference promoted to recorded fact.
2. I could have diagnosed the failing-job set before forming hypotheses — my first read ("darwin eval gap", "nix2container missing on darwin") was wrong; the macos Check Flake job was simply fail-fast-canceled collateral of the ubuntu Format failure. Reading the strategy-cancellation line first would have saved a theory cycle.
3. The 4-owner-questions message could have led with "origin CI is red right now" instead of burying it under the registry work — it is the most time-sensitive fact (every push fails publicly).

### Did you lie?

Not knowingly. One false claim was published as fact ("daemon pushes this repo"), falsified and corrected same-session. Every number in this report comes from a command run this session.

### Split brains / ghost systems found

- **No new split brains.** The registry decision fans out to 5 places (option description = source of truth; man page, README, AGENTS.md, T46 restate it) and the push-truth to 3 — intentional audience fanout, but each is a future drift surface; the man page and README should be checked when the option text changes.
- **Ghost system (pre-existing, now visible): `scripts/nix-lint.sh`** is a fleet lint with CI-enforced shellcheck hygiene but no automated execution anywhere — it runs only when a human/agent remembers. Its SC2016 fix serves a tool nothing schedules.

### How are we doing on tests?

- moduleTest 218/218 after my changes; the fix pattern (key configs by `pkgs.stdenv.hostPlatform.system`) is the reusable lesson, now recorded in AGENTS.md.
- Gap: zero local coverage of the two CI-only gates (shellcheck, darwin leg). Improvement item NEW-4 below closes the first; the second is closed only by CI until someone adds a darwin-eval smoke that runs on linux.

### Re-verification of inherited claims (skill question 12)

- "~10 commits ahead, nothing pushed" → **false** (rev-list after fetch: everything through `214bbdb` was on origin).
- "ALL GATES GREEN" (prior session close) → **false as a CI claim** (red since ≥2026-10-30), true only for the local battery.
- "the report's 7 is a miscount" → true but wildly incomplete as a description of what was wrong.
- AGENTS.md counts (218/43/17) → still true today (218 re-derived; 43/17 not re-counted this session — carried).

---

## a) FULLY DONE

| # | Item                                                                                                                                                             | Evidence                                                                    |
| - | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| 1 | Registry decision encoded: `container.registry` description (source of truth), man page, README, AGENTS.md gotcha, T46 note, report §g.3 ANSWERED verdict        | commits `b5a2f42`+`214bbdb` (daemon split the batch); grep-verified on disk |
| 2 | Fleet remote truth established: 16 Forgejo-remote repos on 2 hosts; carve-out wording kept generic in public docs, concrete hosts in AGENTS.md                   | remote scan of 250+ repos                                                   |
| 3 | shfmt tab-drift fixed (5 scripts restored to treefmt format)                                                                                                     | `nix fmt`, idempotence re-run; CI Format Check root cause closed            |
| 4 | shellcheck SC2016 fixed (disable directive + reason on nix-lint pattern 16)                                                                                      | `nix run nixpkgs#shellcheck -- scripts/*.sh` → clean (CI's exact command)   |
| 5 | Darwin vendorHashes test hardcode fixed: configs keyed by `hostSystem`/`otherSystem` from `pkgs.stdenv.hostPlatform.system`; DARWINHASH→OTHERHASH rename         | moduleTest 218/218 locally                                                  |
| 6 | TODO_LIST trued up: T48–T50, T52, T57 → TODO (origin carries the option); T47 note corrected (relock OK, still g/2-gated); T51 gained the Forgejo carve-out note | `2e8621d`, `1dc75df`                                                        |
| 7 | Push-behavior record corrected to verified facts (daemon commits only; 18:55 pusher unknown) in AGENTS.md, T47 note, report §g.1                                 | `1dc75df` after 13-min watcher falsification                                |
| 8 | Report §g.1 annotated (partially moot; narrowed to "push these 4 commits")                                                                                       | `2e8621d` + `1dc75df`                                                       |

## b) PARTIALLY DONE

| # | Item                      | Done                                                                                                             | Missing                                                                                                      |
| - | ------------------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| 1 | Master CI recovery        | 3 root causes fixed, ALL local gates green (218/218, --all-systems --no-build, shellcheck, fmt, docsAnnotations) | Not pushed → CI verdict on the fix chain unknown; origin remains red until owner approves push               |
| 2 | Registry decision shipped | Encoded + committed locally                                                                                      | Unpushed; no consumer has adopted the carve-out yet (first Forgejo-remote adopter pending)                   |
| 3 | CI diagnosis completeness | 6 runs + per-job logs; 4 failing jobs explained (3 causes + 1 cancellation)                                      | Run `44059828196` (09:54, ALL jobs failed) not decomposed — likely infra/flake-parts-tarball fetch, unproven |
| 4 | Push-state investigation  | Mechanism settled (daemon commits-only)                                                                          | Pusher identity + stray-branch creator unknown (§g Q3)                                                       |

## c) NOT STARTED

1. Stray branch `origin/systemnix-vn-version-fix` — existence flagged (AGENTS.md), contents never inspected.
2. Annotation of the 15-00 report's §g.2 (registry) — superseded by TODO_LIST/T46 updates but the file reads unanswered.
3. Full-build `nix flake check` at `1dc75df` (containerSmoke rebuild) — deliberately deferred to pre-push.
4. AGENTS.md numeric-count de-rotting (218/43/17 hardcoded; rotted twice before) — known, untouched.
5. docs-health HARVEST of this report's §f NEW items into TODO_LIST.
6. Local shellcheck gate (closing the CI-vs-local gap mechanically instead of by memory).
7. Everything in TODO_LIST not touched this session: T35–T45, T46, T51–T56, T58, T59.

## d) TOTALLY FUCKED UP

1. **False causal claim published as "verified"** — "the daemon pushes this repo" written into AGENTS.md, TODO_LIST and the report annotation from a single correlation. Corrected in `1dc75df`, but it happened, and it is the exact unverified-inference failure class this fleet's skills exist to gate. The word "verified" must be earned by observing the mechanism, not the outcome.
2. **Transient inconsistent docs on origin** — daemon's `214bbdb` shipped annotations claiming "carve-out encoded in the option description + man page" while those two files were still uncommitted; origin readers got a promise, not the code (closed ~5 min later by `b5a2f42`).
3. **Inherited, not mine but now on the record: CI red for ~3 weeks** across at least 8 pushes while sessions reported "ALL GATES GREEN". The local battery was never the same thing as CI. Nobody ran `gh run list`. (Root causes now fixed; process fix pending — NEW-4/NEW-5.)

## e) WHAT WE SHOULD IMPROVE

1. **Never write "verified X did Y" from outcome correlation** — verify the mechanism (watch the actor, or leave the actor unnamed). Cheap rule, expensive violation.
2. **Fetch before believing any push-state claim** — inherited "ahead N / nothing pushed" claims decay in minutes; `git fetch && git rev-list --left-right --count` costs 2 seconds.
3. **Read CI first at session start in any repo with a daemon** — `gh run list --limit 5` is the fastest health probe we keep skipping.
4. **Close the CI-vs-local gate gap mechanically**: a `scripts/ci-parity.sh` (shellcheck + `nix flake check --all-systems --no-build`) or a flake check job wrapping shellcheck — memory-based parity does not survive sessions.
5. **Kill the hardcoded-count pattern in AGENTS.md** — derive counts at read time or drop the numbers; they have now rotted in two consecutive sessions.
6. **Daemon hygiene**: pre-session `git stash list` / activity check when another session's fingerprints are present; consider re-running `nix fmt` immediately before any push (the tab-drift could return if the concurrent session is still alive).
7. **Fail-fast matrix reading order**: check strategy-cancellation lines before theorizing about canceled legs — one line ("canceled because ubuntu failed") killed two wrong hypotheses.
8. **Report the most time-sensitive fact first** in owner-facing messages (red public CI outranks feature polish).

## f) Next — up to 50 (NEW = harvest candidates; T-refs = already in TODO_LIST)

| #  | Item                                                                                                                  | Est   | Ref/Status             |
| -- | --------------------------------------------------------------------------------------------------------------------- | ----- | ---------------------- |
| 1  | OWNER: push approval for the 4 local commits — origin CI red until landed                                             | 1min  | §g Q1                  |
| 2  | Watch CI on the pushed chain; expect first green master since <2026-10-30                                             | 15min | after NEW-1            |
| 3  | Investigate `origin/systemnix-vn-version-fix` (contents, creator, delete?)                                            | 15min | NEW                    |
| 4  | Local CI-parity gate: wrap `shellcheck scripts/*.sh` + `--all-systems --no-build` into a script/check                 | 1h    | NEW                    |
| 5  | docs-health HARVEST this report's NEW items into TODO_LIST                                                            | 30min | NEW                    |
| 6  | Annotate 15-00 report §g.2 (registry ANSWERED, cross-ref 18-52 §g.3)                                                  | 5min  | NEW                    |
| 7  | Full-build `nix flake check` (containerSmoke rebuild) at HEAD before push                                             | 20min | NEW                    |
| 8  | Determine whether the concurrent session is still active; if yes, coordinate                                          | 10min | NEW                    |
| 9  | Decompose CI run 44059828196 (all-jobs failure, 09:54) — infra vs real                                                | 15min | NEW                    |
| 10 | PapDashboard pilot merge + relock (T47)                                                                               | 30min | T47, g/2-gated         |
| 11 | KeyHolderAI → `container` option                                                                                      | 2h    | T48 unblocked          |
| 12 | standard-bug-tracking-schema → `container` option                                                                     | 2h    | T49 unblocked          |
| 13 | bank-sync → go-standard adoption                                                                                      | 4h    | T50 unblocked          |
| 14 | Fleet sweep: delete remaining hand-rolled dockerTools blocks                                                          | 2h    | T52 after T47–T49      |
| 15 | Post-push consumer audit (`nix flake update` sweeps)                                                                  | 1h    | T57 unblocked          |
| 16 | GHCR push workflow template (consumer CI)                                                                             | 1h    | T46 unblocked          |
| 17 | README registry-auth section (docker login / skopeo)                                                                  | 30min | T45                    |
| 18 | nix-private-go-repos skill: image push works with private deps                                                        | 15min | T53                    |
| 19 | CI: assert `--all-systems --no-build` (T56 — overlaps NEW-4; fold)                                                    | 30min | T56                    |
| 20 | Local aarch64-linux containerSmoke (emulation)                                                                        | 1h    | T54                    |
| 21 | GH Actions runtime delta review from containerSmoke                                                                   | 30min | T55                    |
| 22 | AGENTS.md numeric counts: derive or drop                                                                              | 30min | NEW (this session c/4) |
| 23 | flake-patterns.md: container pattern + anti-patterns                                                                  | 1h    | T35                    |
| 24 | architecture.d2/svg: add container.nix component                                                                      | 30min | T36                    |
| 25 | consumer-audit-checklist.md: container section                                                                        | 30min | T37                    |
| 26 | dashboard.sh: container column across fleet                                                                           | 1h    | T38                    |
| 27 | Structure check: richer mismatch diff                                                                                 | 1h    | T39                    |
| 28 | Test custom `created` round-trip (RFC3339Nano)                                                                        | 30min | T40                    |
| 29 | Multi-arch manifest app (skopeo copy --all)                                                                           | 3h    | T41                    |
| 30 | `container.fromImage` (distroless base)                                                                               | 3h    | T42                    |
| 31 | `container.initializeNixDatabase` passthrough                                                                         | 1h    | T43                    |
| 32 | Tag strategy knob docs                                                                                                | 30min | T44                    |
| ~~33~~ | ~~nix2container lock pin doc note~~ done — T58 DONE 2026-11-18 (pin policy documented at the flake input; graduated into CHANGELOG [Unreleased]) | ~~15min~~ | ~~T58~~ |
| 34 | tryEval message-free pattern → flake-patterns.md                                                                      | 15min | T59                    |
| 35 | Code-Quality-Agent + artmann-technologies-website adopt-or-manual (Forgejo carve-out applies)                         | 15min | T51 owner-gated        |
| 36 | Add a Forgejo-remote fixture/consumer doc example to the migration guide                                              | 30min | NEW                    |
| 37 | Consider a gate that keeps man page + README in sync with option descriptions (drift fanout of the registry decision) | 1h    | NEW                    |

37 items (11 NEW, 24 existing T-refs, 2 owner-gated). No further items invented to pad the count — the remaining ~13 slots would be ROADMAP noise, not commitments.

## g) Questions I cannot figure out myself

1. **Push approval for the 4 local commits** (`b5a2f42` registry carve-out, `78a82e8`+`2e8621d` CI fixes, `1dc75df` record correction)? Origin's master CI is red on every push since ≥2026-10-30 and stays red until these land; I will not push unasked. One word unlocks NEW-1/NEW-2.
2. **PapDashboard templ-file disposition** (unchanged from yesterday's report §g.2): ride the pilot branch into master at merge, cherry-pick to master first, or leave for the owning session? T47 (pilot merge) is gated only on this now.
3. **Who/what is the second actor in this repo?** Something pushed everything at 18:55 and created `origin/systemnix-vn-version-fix`, and something tab-reindented five scripts yesterday evening — none of that is this session or the daemon's commit behavior. Is there an active concurrent session or second daemon I should coordinate with (or is the stray branch safe to delete)?

---

_Verification snapshot at close: local master `1dc75df`, ahead 4 of origin (`214bbdb`), tree clean. Local gates green: moduleTest 218/218, `nix flake check --all-systems --no-build`, shellcheck (CI's exact command), `nix fmt` idempotent, docsAnnotations. NOT run: full-build flake check, any push. Origin CI: red at `214bbdb`, verdict on the fix chain pending push approval._
