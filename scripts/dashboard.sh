#!/usr/bin/env bash
# dashboard.sh — Overview of all project flake check status
# Usage: dashboard.sh [--check] [--json]
set -euo pipefail

CHECK=false
JSON=false

for arg in "$@"; do
  case "$arg" in
    --check) CHECK=true ;;
    --json)  JSON=true ;;
    --help|-h)
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
CYAN='\033[0;36m'
NC='\033[0m'

pass=0
fail=0
skip=0
results=()

for f in $(find /home/lars/projects -maxdepth 2 -name "flake.nix" -exec dirname {} \; | sort); do
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
    # Quick static analysis only
    if grep -q 'go_1_25\b' "$f/flake.nix" 2>/dev/null; then
      status="WARN"
      skip=$((skip + 1))
    else
      status="OK"
      pass=$((pass + 1))
    fi
    error=""
  fi

  if [ "$JSON" = true ]; then
    results+=("{\"project\":\"$project\",\"status\":\"$status\",\"error\":\"${error:-}\"}")
  else
    case "$status" in
      PASS|OK)  printf "${GREEN}%-40s${NC} %s\n" "$project" "$status" ;;
      FAIL)     printf "${RED}%-40s${NC} %s %s\n" "$project" "$status" "${error:0:60}" ;;
      WARN)     printf "${YELLOW}%-40s${NC} %s\n" "$project" "$status" ;;
    esac
  fi
done

if [ "$JSON" = true ]; then
  printf '[%s]\n' "$(IFS=,; echo "${results[*]}")"
else
  echo ""
  echo "========================================="
  echo "Total: $((pass + fail + skip))  Pass: $pass  Fail: $fail  Warn: $skip"
  echo "========================================="
fi
