#!/usr/bin/env bash
# Docs-annotation gates over docs/status/ — CI-enforced docs-health
# annotate discipline. Vendored from the docs-health skill's
# completeness gates; row classification lives in check-rows.py
# (vendored alongside, attribution in its header).
#
# Gate 1 (archived completeness): every file under docs/status/archived/
#   carries at least one strikethrough resolution (`~~`). A file in
#   archived/ with zero annotations was archived by mistake.
# Gate 2 (row uniformity): check-rows.py over ALL of docs/status/ plus
#   docs/planning/ and docs/reviews/ — no table may mix struck and
#   unstruck rows (the planted-miss class from the 2026-09-16 F12.3
#   miss). Sections that are informational by design (retrospectives,
#   metrics tables) carry an explicit "intentionally bare" note instead
#   of annotations.
#
# Usage: check-docs-annotations.sh [repo-root]
#   repo-root defaults to two levels above this script (works against a
#   read-only store checkout, which is how the flake check invokes it).
# Exit 0 = both gates green; exit 1 lists offenders.
#
# SCOPE (deliberate): docs/status/, docs/planning/, docs/reviews/ ONLY.
# TODO_LIST.md, FEATURES.md, CHANGELOG.md and other living docs are NOT
# gated — they are continuously rewritten, so strike-through residue
# there is meaningless. Planting a broken table outside the scoped dirs
# proves nothing; the gate is green there BY DESIGN.
set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
status_dir="$root/docs/status"

if [ ! -d "$status_dir/archived" ]; then
  echo "FAIL: $status_dir/archived does not exist (wrong repo root?)" >&2
  exit 1
fi

fail=0

bare=$(grep -rLn '~~' "$status_dir/archived" || true)
if [ -n "$bare" ]; then
  echo "FAIL (gate 1: archived completeness) — no strikethrough resolution found in:" >&2
  printf '  %s\n' "$bare" >&2
  fail=1
else
  echo "PASS (gate 1: archived completeness)"
fi

mapfile -d '' files < <(
  find "$status_dir" "$root/docs/planning" "$root/docs/reviews" \
    -name '*.md' -print0 2>/dev/null | sort -z
)
if [ "${#files[@]}" -eq 0 ]; then
  echo "FAIL: no markdown files found to check (wrong repo root?)" >&2
  exit 1
fi
if python3 "$root/scripts/check-rows.py" "${files[@]}"; then
  echo "PASS (gate 2: row uniformity)"
else
  echo "FAIL (gate 2): row uniformity — see offenders above" >&2
  fail=1
fi

exit "$fail"
