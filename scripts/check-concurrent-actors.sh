#!/usr/bin/env bash
# check-concurrent-actors.sh — detect out-of-session file changes before final claims
#
# The 2026-11-17 formatter incident bit twice: a concurrent actor (editor with
# a different formatter config, or the heuristic auto-commit daemon sweeping
# whatever is on disk) re-tab-indented scripts 25 minutes after a green gate,
# and the damage shipped under a green battery. This script is the pre-final
# check: it snapshots a baseline at session start and, at check time, lists
# every file that changed on disk since the baseline EXCEPT the paths you
# explicitly allow (the session's edit set).
#
# Usage:
#   scripts/check-concurrent-actors.sh baseline
#       Record the baseline (timestamp + HEAD + status snapshot).
#
#   scripts/check-concurrent-actors.sh check [--warn] [allowed-path ...]
#       Compare now against the baseline. Files with mtime >= baseline that
#       are NOT under an allowed path are reported. Exit 1 if any are found
#       (0 with --warn). Allowed paths match by prefix (a directory allows
#       everything under it; "." allows everything).
#
# Notes:
# - mtime is the source of truth, not git status: committed damage is still
#   damage. Commits since the baseline are listed for context (daemon
#   heuristic commits are the usual suspects).
# - Baseline lives in .git/CONCURRENT-ACTORS-BASELINE (never committed).
# - Re-run `nix fmt` + gates if this fires and you adopt the changes; rebase
#   or repair from last-good if you do not (annotate-then-format-then-re-gate).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASELINE_FILE="$REPO_ROOT/.git/CONCURRENT-ACTORS-BASELINE"

die() {
	echo "ERROR: $*" >&2
	exit 2
}

cmd_baseline() {
	date +%s >"$BASELINE_FILE.timestamp"
	git -C "$REPO_ROOT" rev-parse HEAD >"$BASELINE_FILE.head"
	git -C "$REPO_ROOT" status --porcelain >"$BASELINE_FILE.status"
	echo "Baseline recorded: $(cat "$BASELINE_FILE.head" | cut -c1-8) at $(date -d @"$(cat "$BASELINE_FILE.timestamp")" '+%Y-%m-%d %H:%M:%S%z')"
}

is_allowed() {
	local file="$1"
	shift
	local allowed
	for allowed in "$@"; do
		if [[ $file == "$allowed" || $file == "$allowed"/* ]]; then
			return 0
		fi
	done
	return 1
}

cmd_check() {
	[ -f "$BASELINE_FILE.timestamp" ] || die "no baseline; run 'check-concurrent-actors.sh baseline' first"
	local baseline_ts baseline_head
	baseline_ts="$(cat "$BASELINE_FILE.timestamp")"
	baseline_head="$(cat "$BASELINE_FILE.head")"

	local warn=false
	if [ "${1:-}" = "--warn" ]; then
		warn=true
		shift
	fi
	local allowed_paths=("$@")

	echo "Baseline: $(echo "$baseline_head" | cut -c1-8) ($(date -d @"$baseline_ts" '+%H:%M:%S'))"

	# Context: commits that appeared since the baseline (daemon or foreign actor).
	local new_commits
	new_commits="$(git -C "$REPO_ROOT" log --oneline "$baseline_head"..HEAD 2>/dev/null || true)"
	if [ -n "$new_commits" ]; then
		echo "Commits since baseline:"
		while IFS= read -r line; do echo "  $line"; done <<<"$new_commits"
	fi

	# Every tracked file modified on disk since the baseline. bash's -nt test
	# compares full nanosecond mtimes against a reference file stamped with
	# the baseline epoch (portable: no GNU-find -newermt dependency).
	local ref
	ref="$(mktemp)"
	touch -d "@$baseline_ts" "$ref"
	local changed=""
	local file
	while IFS= read -r -d '' file; do
		if [ "$REPO_ROOT/$file" -nt "$ref" ]; then
			changed+="$file"$'\n'
		fi
	done < <(git -C "$REPO_ROOT" ls-files -z)
	rm -f "$ref"

	local unexpected=()
	if [ -n "$changed" ]; then
		while IFS= read -r file; do
			if ! is_allowed "$file" "${allowed_paths[@]:-.}"; then
				unexpected+=("$file")
			fi
		done <<<"$changed"
	fi

	if [ "${#unexpected[@]}" -eq 0 ]; then
		echo "OK: no out-of-session file changes detected."
		exit 0
	fi

	echo "OUT-OF-SESSION CHANGES (not in the allowed edit set):"
	printf '  %s\n' "${unexpected[@]}"
	if [ "$warn" = true ]; then
		echo "(warn-only)"
		exit 0
	fi
	cat >&2 <<'EOF'

Concurrent actor detected. Before any final claim:
  1. Inspect the files above (git diff / git log) and decide: adopt or repair.
  2. Adopt: nix fmt + re-run all gates on the merged result.
  3. Repair: restore from last-good commits, then re-gate.
EOF
	exit 1
}

case "${1:-}" in
baseline)
	cmd_baseline
	;;
check)
	shift
	cmd_check "$@"
	;;
*)
	die "usage: $0 baseline | $0 check [--warn] [allowed-path ...]"
	;;
esac
