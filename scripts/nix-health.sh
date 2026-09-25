#!/usr/bin/env bash
# nix-health.sh — pre-flight canary for local Nix verification batches.
#
# Surfaces the two host failures that silently invalidate local builds
# (observed 2026-09-25 after a nix-daemon restart):
#   1. /run/binfmt vanished while /etc/nix/nix.conf still binds it via
#      extra-sandbox-paths — EVERY sandboxed build fails with a cryptic
#      sandbox setup error. Fix (root): systemctl restart systemd-binfmt.service
#   2. Auto-GC thresholds (min-free/max-free) let the daemon delete unrooted
#      flake source copies between eval and check phases ("path ...-source
#      is not valid"). Fix (root): raise max-free / drop auto-GC in
#      /etc/nix/nix.conf and restart nix-daemon.
#
# Usage: scripts/nix-health.sh [--quiet]
# Exit 0 = healthy enough for local build verification; exit 1 = blocked
# (eval-only work still fine; CI on GitHub Actions is unaffected).
set -uo pipefail

QUIET=false
[ "${1:-}" = "--quiet" ] && QUIET=true

fail=0
warn=0

note() { "$QUIET" || echo "$1"; }

# --- 1. binfmt mount -------------------------------------------------------
# Only a blocker when nix.conf actually references /run/binfmt.
nix_conf="/etc/nix/nix.conf"
conf_references_binfmt=false
[ -r "$nix_conf" ] && grep -q "/run/binfmt" "$nix_conf" && conf_references_binfmt=true

if [ -d /run/binfmt ]; then
  note "OK   /run/binfmt present"
elif $conf_references_binfmt; then
  echo "FAIL /run/binfmt missing while $nix_conf references it — all local builds will fail."
  echo "     Fix (root): systemctl restart systemd-binfmt.service"
  fail=1
else
  note "OK   /run/binfmt not needed (nix.conf does not reference it)"
fi

# --- 2. daemon reachable ---------------------------------------------------
if daemon_pid=$(pidof nix-daemon 2>/dev/null | awk '{print $1}'); then
  if elapsed=$(ps -o etimes= -p "$daemon_pid" 2>/dev/null | tr -d ' '); then
    hours=$((elapsed / 3600))
    note "OK   nix-daemon up (pid $daemon_pid, ~${hours}h)"
  fi
else
  echo "FAIL nix-daemon not running"
  fail=1
fi

# --- 3. auto-GC risk --------------------------------------------------------
if [ -r "$nix_conf" ]; then
  min_free=$(grep -oP '^\s*min-free\s*=\s*\K[0-9]+' "$nix_conf" | tail -1)
  max_free=$(grep -oP '^\s*max-free\s*=\s*\K[0-9]+' "$nix_conf" | tail -1)
  if [ -n "${min_free:-}" ] || [ -n "${max_free:-}" ]; then
    free_bytes=$(df -B1 --output=avail /nix/store | tail -1 | tr -d ' ')
    hr() { numfmt --to=iec "$1" 2>/dev/null || echo "${1}B"; }
    echo "WARN auto-GC armed (min-free=${min_free:-unset} max-free=${max_free:-unset}); store free: $(hr "$free_bytes")"
    echo "     Unrooted source copies can vanish between eval and check; prefer"
    echo "     git-worktree verification or raise the thresholds (root)."
    warn=1
  else
    note "OK   auto-GC not configured"
  fi
fi

# --- 4. store disk ----------------------------------------------------------
if free_kb=$(df -k --output=avail /nix/store 2>/dev/null | tail -1 | tr -d ' '); then
  if [ "$free_kb" -lt 10485760 ]; then
    echo "FAIL /nix/store has less than 10 GiB free"
    fail=1
  else
    note "OK   /nix/store free: $((free_kb / 1048576)) GiB"
  fi
fi

echo "---"
if [ "$fail" -ne 0 ]; then
  echo "BLOCKED for local builds — eval-only verification still possible."
  exit 1
fi
[ "$warn" -ne 0 ] && echo "CAUTION: local builds possible but flaky checks likely."
exit 0
