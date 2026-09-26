# Postmortem: lock bumps are eval changes; and the silent host break

_Written 2026-09-25. Two cases that cost hours each and share one lesson:
the failure was invisible until a full `nix flake check` with builds ran._

## Case 1 — "just a lock bump" broke evaluation (2026-09-07)

**What happened:** a parallel session bumped `flake.lock` (`528488a`,
36-docs sweep + nixpkgs lock bump) between two green states. Evaluation
broke — but every consumer and every observer assumed a lock bump was
behavior-neutral and hunted the diff of the CODE changes instead.

**Root cause:** a flake input bump is an EVALUATION-surface change. The
pinned nixpkgs revision changed attribute shapes that our fixtures and
module logic read at eval time. Bisecting across clean worktrees — green
at `0817f80`, broken at `528488a`, green again with the fixture fix —
isolated it in minutes AFTER someone finally bisected.

**Lesson (mechanism, not slogan):** after ANY `flake.lock` change in this
repo, run `nix flake check --no-build` before anything else. Lock bumps
are commits to the eval graph, not metadata. Bisect first when a green →
red transition has more than one suspect commit — clean worktrees make
parallel-session noise irrelevant.

## Case 2 — the host broke silently and invalidated "verified" (2026-09-25, 04:06)

**What happened:** a NixOS switch restarted the Nix daemon at 04:06.
Afterwards:

1. **Every local build failed** — `/run/binfmt` vanished while
   `/etc/nix/nix.conf` still binds it via `extra-sandbox-paths`, so every
   sandboxed build died during sandbox setup.
2. **`nix flake check` went flaky-to-deterministically-broken** — the
   daemon's auto-GC (`max-free = 30G` against a 145G store) deleted
   unrooted flake source copies BETWEEN the eval and check phases
   (`path ...-source is not valid`).

**The expensive part was not the break — it was the misdiagnosis:** three
theories were tried in order (pathExists-context — wrong, retracted;
dirty-tree/daemon-commit race — partially right; GC deleting unrooted
copies — root cause). The wrong first theory cost ~30 minutes and got
published in a status report before being corrected. And under time
pressure with builds unavailable, eight moduleTest assertions were
committed "eval-verified" that had NEVER been green — discovered (and
fixed, along with a real `cgoEnabled` bug they were hiding) only when
builds returned and the full suite ran.

**Root fixes (both need root):** restart
`systemd-binfmt.service`; raise/disable nix.conf auto-GC thresholds and
restart the daemon.

**What now guards against a repeat:**

- `scripts/nix-health.sh` — pre-flight canary (binfmt presence vs nix.conf
  references, daemon age, auto-GC exposure, store headroom). Run it before
  any local verification batch; it would have caught both failures in
  seconds.
- Never trust "eval-verified" for assertions that assert CONTENT of
  warnings, env vars, or thrown messages: `toString` of a tryEval-captured
  error is `""` on Nix 2.34 — such tests pass vacuously-false or fail
  silently. Assert against pure builders, flattened derivation attrs, or
  throw-site source text instead (see test-module.nix).
- The auto-commit daemon + dirty trees make `nix flake check` flaky under
  GC pressure: verify from a clean tree (`git worktree add /tmp/x HEAD`)
  or commit before checking.
- CI (GitHub Actions) is unaffected by local host state — when the host
  is broken, pushing and letting CI be the build oracle is legitimate
  (with owner approval; this repo does not push without it).

*Evidence: `docs/status/2026-09-25_04-33_pareto-execution-session-interrupted.md`
(theory 1, later retracted), `docs/status/2026-09-25_04-39_pareto-execution-wrapup-and-corrections.md`
(corrected root-cause analysis), commit `105c981` (the 8-assertion repair

- `cgoEnabled` fix).*
