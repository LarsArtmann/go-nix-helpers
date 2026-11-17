#!/usr/bin/env bash
# ci-parity.sh — run every CI-only gate locally before declaring green
#
# CI (github actions) has gates that a plain local `nix flake check` lacks:
#   1. Format Check  — treefmt --fail-on-change (CI job "check")
#   2. shellcheck    — `nix run nixpkgs#shellcheck -- scripts/*.sh`, style
#                      severity (a single info-level SC2016 fails the job)
#   3. macOS leg     — checks evaluate on darwin too; hardcoded system
#                      strings in test configs fail ONLY there
#
# Master stayed red for weeks unnoticed because these gates ran only in CI.
# This script is the local mirror: run it before any "green" claim or push.
# It also covers the eval surface of `nix flake check --all-systems --no-build`
# (darwin + aarch64 eval gaps) which the default single-system check omits.
#
# Usage:
#   scripts/ci-parity.sh          # fmt + shellcheck + all-systems eval check
#   scripts/ci-parity.sh --full   # additionally a full (building) flake check
#
# Exit code: non-zero if ANY gate fails; each gate's output is streamed.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

FULL=false
[ "${1:-}" = "--full" ] && FULL=true

fail=0

step() {
  echo ""
  echo "=== $* ==="
}

step "Format Check (treefmt --fail-on-change)"
if nix fmt -- --fail-on-change; then
  echo "fmt: OK"
else
  echo "fmt: FAILED — run 'nix fmt', re-stage, and re-run this script" >&2
  fail=1
fi

step "shellcheck (style severity, exactly as CI)"
if nix run nixpkgs#shellcheck -- scripts/*.sh; then
  echo "shellcheck: OK"
else
  echo "shellcheck: FAILED — fix every finding (info-level counts in CI)" >&2
  fail=1
fi

step "Eval check, ALL systems (catches darwin/aarch64 eval gaps)"
if nix flake check --all-systems --no-build; then
  echo "eval: OK"
else
  echo "eval: FAILED" >&2
  fail=1
fi

if [ "$FULL" = true ]; then
  step "FULL flake check (builds everything, incl. containerSmoke)"
  if nix flake check --all-systems; then
    echo "full: OK"
  else
    echo "full: FAILED" >&2
    fail=1
  fi
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "CI-PARITY: ALL GATES GREEN"
else
  echo "CI-PARITY: RED — fix above before pushing" >&2
fi
exit "$fail"
