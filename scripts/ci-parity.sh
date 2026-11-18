#!/usr/bin/env bash
# ci-parity.sh — run every CI-only gate locally before declaring green
#
# CI (github actions) has gates that a plain local `nix flake check` lacks:
#   1. Format Check  — treefmt --fail-on-change (CI job "check")
#   2. shellcheck    — `nix run nixpkgs#shellcheck -- scripts/*.sh`, style
#                      severity (a single info-level SC2016 fails the job)
#   3. macOS leg     — checks evaluate on darwin too; hardcoded system
#                      strings in test configs fail ONLY there
#   4. flake.lock freshness — `nix flake update` must be a no-op (went red
#                      2026-11-18: stale nixpkgs pin)
#
# Master stayed red for weeks unnoticed because these gates ran only in CI.
# This script is the local mirror: run it before any "green" claim or push.
# It also covers the eval surface of `nix flake check --all-systems --no-build`
# (darwin + aarch64 eval gaps) which the default single-system check omits.
#
# Usage:
#   scripts/ci-parity.sh            # fmt + shellcheck + all-systems eval + lock
#   scripts/ci-parity.sh --full     # additionally a full (building) flake check
#   scripts/ci-parity.sh --ci-jobs  # additionally the heavy CI-only build
#                                   # legs: integration checks, template smoke,
#                                   # old-nixpkgs moduleTest degradation
#
# Exit code: non-zero if ANY gate fails; each gate's output is streamed.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

FULL=false
CI_JOBS=false
for arg in "$@"; do
  case "$arg" in
  --full) FULL=true ;;
  --ci-jobs) CI_JOBS=true ;;
  *) echo "ci-parity: unknown flag '$arg' (try --full or --ci-jobs)" >&2 && exit 2 ;;
  esac
done

SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')
fail=0

step() {
  echo ""
  echo "=== $* ==="
}

gate() {
  name=$1
  shift
  step "$name"
  if "$@"; then
    echo "$name: OK"
  else
    echo "$name: FAILED" >&2
    fail=1
  fi
}

gate "Format Check (treefmt --fail-on-change)" nix fmt -- --fail-on-change

gate "shellcheck (style severity, exactly as CI)" \
  nix run nixpkgs#shellcheck -- scripts/*.sh

gate "Eval check, ALL systems (darwin/aarch64 eval gaps)" \
  nix flake check --all-systems --no-build

gate "flake.lock freshness (nix flake update must be a no-op)" bash -c '
  cp flake.lock /tmp/ci-parity-lock-backup
  nix flake update
  if diff -q flake.lock /tmp/ci-parity-lock-backup >/dev/null; then
    exit 0
  fi
  echo "flake.lock is stale — nix flake update changed it:" >&2
  diff flake.lock /tmp/ci-parity-lock-backup | head -20 >&2 || true
  git restore -- flake.lock
  exit 1
'

if [ "$CI_JOBS" = true ]; then
  gate "Integration checks (verify moduleTest pureFunctions structural)" \
    nix build --no-link \
    ".#checks.$SYSTEM.verify" \
    ".#checks.$SYSTEM.moduleTest" \
    ".#checks.$SYSTEM.pureFunctions" \
    ".#checks.$SYSTEM.structural"

  gate "Template smoke legs (generate-flake flags)" bash -c '
    set -e
    scripts/generate-flake.sh --dir /tmp/ci-parity-smoke-basic smoke-basic
    nix-instantiate --parse /tmp/ci-parity-smoke-basic/flake.nix >/dev/null
    scripts/generate-flake.sh --dir /tmp/ci-parity-smoke-templ --templ smoke-templ
    nix-instantiate --parse /tmp/ci-parity-smoke-templ/flake.nix >/dev/null
    scripts/generate-flake.sh --dir /tmp/ci-parity-smoke-gomod --go-mod smoke-gomod
    test -f /tmp/ci-parity-smoke-gomod/go.mod
    nix-instantiate --parse /tmp/ci-parity-smoke-gomod/flake.nix >/dev/null
    scripts/generate-flake.sh --dir /tmp/ci-parity-smoke-deps --private-deps smoke-deps
    grep -q "deps = {" /tmp/ci-parity-smoke-deps/flake.nix
    nix-instantiate --parse /tmp/ci-parity-smoke-deps/flake.nix >/dev/null
    scripts/generate-flake.sh --dir /tmp/ci-parity-smoke-combined --go-mod --private-deps --templ smoke-combined
    grep -q "enableTempl = true" /tmp/ci-parity-smoke-combined/flake.nix
    nix-instantiate --parse /tmp/ci-parity-smoke-combined/flake.nix >/dev/null
    scripts/generate-flake.sh --dir /tmp/ci-parity-smoke-dryrun --dry-run smoke-dryrun >/dev/null 2>&1
    test ! -d /tmp/ci-parity-smoke-dryrun
  '

  gate "old-nixpkgs moduleTest (auto-default degradation leg)" \
    nix build --no-link \
    --override-input nixpkgs github:NixOS/nixpkgs/567a49d1913ce81ac6e9582e3553dd90a955875f \
    ".#checks.$SYSTEM.moduleTest"
fi

if [ "$FULL" = true ]; then
  gate "FULL flake check (builds everything, incl. containerSmoke)" \
    nix flake check --all-systems
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "CI-PARITY: ALL GATES GREEN"
else
  echo "CI-PARITY: RED — fix above before pushing" >&2
fi
exit "$fail"
