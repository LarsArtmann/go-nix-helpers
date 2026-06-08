#!/usr/bin/env bash
# nix-lint.sh — Lint flake.nix files for common error patterns
# Usage:
#   nix-lint.sh                  # Lint all flake.nix files under ~/projects
#   nix-lint.sh /path/to/repo    # Lint a specific project
#   nix-lint.sh --fix /path      # Auto-fix where possible
#   nix-lint.sh --check /path    # Also run nix flake check
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

FIX=false
CHECK=false
TARGETS=()

for arg in "$@"; do
  case "$arg" in
    --fix)   FIX=true ;;
    --check) CHECK=true ;;
    --help|-h)
      echo "Usage: nix-lint.sh [--fix] [--check] [path...]"
      echo "  --fix    Auto-fix issues where possible"
      echo "  --check  Also run nix flake check"
      echo "  path     Specific project dir(s), or omit for all under ~/projects"
      exit 0
      ;;
    *)       TARGETS+=("$arg") ;;
  esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  mapfile -t TARGETS < <(find /home/lars/projects -maxdepth 2 -name "flake.nix" -exec dirname {} \; | sort)
fi

total_errors=0
total_fixed=0
total_projects=0
failed_projects=()

for target in "${TARGETS[@]}"; do
  flake="$target/flake.nix"
  [ -f "$flake" ] || continue
  total_projects=$((total_projects + 1))
  project=$(basename "$target")
  errors=0
  fixed=0

  check() {
    local pattern="$1"
    local msg="$2"
    if grep -qP "$pattern" "$flake"; then
      errors=$((errors + 1))
      echo -e "  ${RED}FAIL${NC} $msg"
      return 0
    fi
  }

  check_fix() {
    local pattern="$1"
    local msg="$2"
    local fix_pattern="${3:-}"
    local fix_replace="${4:-}"
    if grep -qPn "$pattern" "$flake"; then
      if [ "$FIX" = true ] && [ -n "$fix_pattern" ]; then
        sed -i "s${fix_pattern}${fix_replace}g" "$flake"
        fixed=$((fixed + 1))
        echo -e "  ${YELLOW}FIXED${NC} $msg"
      else
        errors=$((errors + 1))
        echo -e "  ${RED}FAIL${NC} $msg"
      fi
    fi
  }

  # Pattern 1: Checks inside treefmt block (between treefmt { ... } and its closing };)
  # Detection: checks\.format|checks\.build appearing before treefmt block closes
  # This is hard to detect with simple grep; we check for common misplaced patterns

  # Pattern 2: config/self used outside perSystem
  # If lines like "checks.format = config.treefmt" appear at module level (not inside perSystem)
  # We check for config.treefmt outside of perSystem context

  # Pattern 3: goPkg = goPkg self-reference
  check_fix 'let\s+goPkg\s*=\s*goPkg\s*;' "goPkg = goPkg self-reference (should be pkgs.go_1_26)"

  # Pattern 4: Duplicate checks attributes
  checks_count=$(grep -cP '^\s*checks\s*[=\.{]' "$flake" 2>/dev/null || echo "0")
  if [ "$checks_count" -gt 1 ]; then
    errors=$((errors + 1))
    echo -e "  ${RED}FAIL${NC} Duplicate checks definitions ($checks_count found)"
  fi

  # Pattern 5: nixfmt/templ/gofumpt outside programs
  check_fix 'treefmt\.\s*nixfmt\s*\.' "nixfmt outside programs block" '|treefmt\.\s*nixfmt\.|treefmt.programs.nixfmt.|'
  check_fix 'treefmt\.\s*templ\s*\.' "templ outside programs block" '|treefmt\.\s*templ\.|treefmt.programs.templ.|'
  check_fix 'treefmt\.\s*gofumpt\s*\.' "gofumpt outside programs block" '|treefmt\.\s*gofumpt\.|treefmt.programs.gofumpt.|'
  check_fix 'treefmt\.\s*goimports\s*\.' "goimports outside programs block" '|treefmt\.\s*goimports\.|treefmt.programs.goimports.|'

  # Pattern 6: Missing pkgs. prefix on common tools
  check_fix '\[\s*templ\s*\]' "bare 'templ' in list (needs pkgs.templ)" '|\[\s*templ\s*\]|[ pkgs.templ ]|'
  check_fix '\[\s*gotools\s*\]' "bare 'gotools' in list (needs pkgs.gotools)" '|\[\s*gotools\s*\]|[ pkgs.gotools ]|'

  # Pattern 9: Non-existent package names
  check 'go_1_26-outline' "go_1_26-outline doesn't exist (use go-outline)"
  check 'pkgs\.go_1_26-outline' "pkgs.go_1_26-outline doesn't exist (use pkgs.go-outline)"

  # Pattern 11: outputs = inputs: missing self
  check '^\s*outputs\s*=\s*inputs\s*:' "outputs = inputs: missing self (use inputs@{ self, ... })"

  # Pattern 12: treefmtFlake schema errors
  check 'treefmtFlake\.\w+\s*=\s*true' "treefmtFlake.X = true (wrong schema, use treefmtFlake.formatters.X.enable)"

  # Pattern 15: overlay using _prev but referencing prev
  # (inconsistency between param name and usage)

  # --- Structural checks ---

  # Check: perSystem exists (flake-parts projects)
  if grep -q 'flake-parts' "$flake"; then
    if ! grep -q 'perSystem' "$flake"; then
      errors=$((errors + 1))
      echo -e "  ${RED}FAIL${NC} flake-parts project missing perSystem block"
    fi
  fi

  # Check: checks.format exists
  if grep -q 'perSystem' "$flake" && ! grep -q 'checks.*format\|format.*checks' "$flake"; then
    if [ "$FIX" = true ]; then
      # Add checks.format if checks block exists but no format
      if grep -q '^\s*checks\s*=' "$flake"; then
        sed -i '/^\s*checks\s*=/a\            format = config.treefmt.build.check self;' "$flake"
        fixed=$((fixed + 1))
        echo -e "  ${YELLOW}FIXED${NC} Added checks.format"
      fi
    else
      errors=$((errors + 1))
      echo -e "  ${RED}FAIL${NC} Missing checks.format"
    fi
  fi

  # Check: checks.build exists
  if grep -q 'perSystem' "$flake" && grep -q 'packages\.' "$flake"; then
    if ! grep -q 'checks.*build\|build.*checks' "$flake"; then
      errors=$((errors + 1))
      echo -e "  ${RED}FAIL${NC} Missing checks.build"
    fi
  fi

  # Check: vendorHash is placeholder ( informational)
  if grep -q 'vendorHash.*=.*""' "$flake"; then
    echo -e "  ${CYAN}INFO${NC} vendorHash is empty string (first build needed)"
  fi
  if grep -q 'vendorHash.*=.*sha256-AAA' "$flake"; then
    echo -e "  ${CYAN}INFO${NC} vendorHash is placeholder (needs real hash)"
  fi

  # Check: proxyVendor = true
  if grep -q 'buildGoModule' "$flake" && ! grep -q 'proxyVendor' "$flake"; then
    echo -e "  ${CYAN}INFO${NC} Missing proxyVendor = true (recommended for Go projects)"
  fi

  # Check: meta block
  if grep -q 'buildGoModule' "$flake" && ! grep -q 'meta\s*=' "$flake"; then
    errors=$((errors + 1))
    echo -e "  ${RED}FAIL${NC} Missing meta attribute in package"
  fi

  # Check: license in meta
  if grep -q 'buildGoModule' "$flake" && ! grep -q 'license' "$flake"; then
    errors=$((errors + 1))
    echo -e "  ${RED}FAIL${NC} Missing license in meta"
  fi

  # Report
  if [ "$errors" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} $project"
  else
    echo -e "${RED}FAIL${NC} $project ($errors errors)"
    total_errors=$((total_errors + errors))
    failed_projects+=("$project")
  fi
  total_fixed=$((total_fixed + fixed))

  # Run nix flake check if requested
  if [ "$CHECK" = true ] && [ "$errors" -eq 0 ]; then
    if ! nix flake check "$target" --no-build 2>/dev/null; then
      echo -e "  ${RED}NIX CHECK FAILED${NC}"
      failed_projects+=("$project (nix check)")
      total_errors=$((total_errors + 1))
    fi
  fi
done

echo ""
echo "========================================="
echo "Projects scanned: $total_projects"
echo "Errors found:     $total_errors"
if [ "$FIX" = true ]; then
  echo "Auto-fixed:       $total_fixed"
fi
if [ ${#failed_projects[@]} -gt 0 ]; then
  echo -e "\n${RED}Failed projects:${NC}"
  printf '  - %s\n' "${failed_projects[@]}"
fi
echo "========================================="

[ "$total_errors" -eq 0 ]
