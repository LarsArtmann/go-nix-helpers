#!/usr/bin/env bash
# dashboard.sh — Overview of all project flake check status
# Usage: dashboard.sh [--check] [--json]
set -euo pipefail

CHECK=false
JSON=false

for arg in "$@"; do
  case "$arg" in
  --check) CHECK=true ;;
  --json) JSON=true ;;
  --help | -h)
    echo "Usage: dashboard.sh [--check] [--json]"
    echo "  --check  Run nix flake check --no-build on each project"
    echo "  --json   Output JSON format"
    exit 0
    ;;
  esac
done

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Projects root is configurable; defaults to ~/projects.
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
# Go version considered current, derived from this repo's nixpkgs pin via
# lib.newestGoAttr — no manual bump site. Falls back when eval is impossible
# (offline, broken daemon); override with GO_LATEST=go_1_28 etc.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GO_LATEST="${GO_LATEST:-$(nix eval --raw "$REPO_ROOT#lib.newestGoAttr" 2>/dev/null || echo go_1_27)}"

pass=0
fail=0
skip=0
results=()
rows=()

# Heuristic container-state classifier (grep-based, no eval — fast enough for
# a fleet sweep; authoritative state is each repo's nix flake show):
#   std        go-standard container option (container.enable = true)
#   hand       hand-rolled dockerTools block (migration debt)
#   dockerfile Dockerfile only (no Nix container story)
#   -          no container story at all
container_state() {
  local dir="$1"
  if grep -A4 -E '^[[:space:]]*container[[:space:]]*=[[:space:]]*\{|container[[:space:]]*\.[[:space:]]*enable' \
    "$dir/flake.nix" 2>/dev/null | grep -q 'enable[[:space:]]*=[[:space:]]*true'; then
    echo "std"
  elif grep -q 'dockerTools' "$dir/flake.nix" 2>/dev/null; then
    echo "hand"
  elif [ -f "$dir/Dockerfile" ]; then
    echo "dockerfile"
  else
    echo "-"
  fi
}

for f in $(find "$PROJECTS_DIR" -maxdepth 2 -name "flake.nix" -exec dirname {} \; | sort); do
  project=$(basename "$f")

  if [ "$CHECK" = true ]; then
    if result=$(cd "$f" && nix flake check --no-build 2>&1); then
      status="PASS"
      pass=$((pass + 1))
    else
      error=$(echo "$result" | grep "error:" | head -1 | sed 's/.*error: //')
      status="FAIL"
      fail=$((fail + 1))
    fi
  else
    # Quick static analysis: warn on any pinned go_1_X that is not the latest.
    if grep -qE 'go_1_[0-9]+' "$f/flake.nix" 2>/dev/null && ! grep -q "$GO_LATEST" "$f/flake.nix" 2>/dev/null; then
      status="WARN"
      skip=$((skip + 1))
    else
      status="OK"
      pass=$((pass + 1))
    fi
    error=""
  fi

  if [ "$JSON" = true ]; then
    # Escape backslashes and double-quotes so the emitted JSON stays valid.
    esc_error=$(printf '%s' "${error:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    results+=("{\"project\":\"$project\",\"status\":\"$status\",\"container\":\"$(container_state "$f")\",\"error\":\"$esc_error\"}")
  else
    cstate="$(container_state "$f")"
    case "$status" in
    PASS | OK) rows+=("$(printf "${GREEN}%-32s${NC} %-4s %s\n" "$project" "$status" "$cstate")") ;;
    FAIL) rows+=("$(printf "${RED}%-32s${NC} %-4s %s %s\n" "$project" "$status" "$cstate" "${error:0:60}")") ;;
    WARN) rows+=("$(printf "${YELLOW}%-32s${NC} %-4s %s\n" "$project" "$status" "$cstate")") ;;
    esac
  fi
done

if [ "$JSON" = true ]; then
  printf '[%s]\n' "$(
    IFS=,
    echo "${results[*]}"
  )"
else
  # Canary line first: `dashboard.sh | head -1` shows fleet health.
  echo "CANARY  pass=$pass fail=$fail warn=$skip — $(
    if [ "$fail" -gt 0 ]; then
      echo "FLEET RED"
    elif [ "$skip" -gt 0 ]; then
      echo "fleet yellow"
    else
      echo "fleet green"
    fi
  )"
  printf '%b\n' "${rows[@]}"
  echo ""
  echo "========================================="
  echo "Total: $((pass + fail + skip))  Pass: $pass  Fail: $fail  Warn: $skip"
  echo "Container: std=go-standard  hand=dockerTools  dockerfile=Dockerfile-only  -=none"
  echo "========================================="
fi
