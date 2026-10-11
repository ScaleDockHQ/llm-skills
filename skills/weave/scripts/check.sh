#!/usr/bin/env bash
# Read-only Weave setup check. Needs bash 3.2+; curl optional. Prints variable NAMES and versions, never values.
# Usage: scripts/check.sh   (WANDB_BASE_URL optional for Dedicated/Self-Managed)
set -uo pipefail
echo "-- weave package"
(pip show weave 2>/dev/null | grep -E '^(Name|Version|Requires-Python)') || echo "weave not installed in this Python"
python3 --version 2>/dev/null
echo "-- env names present"
env | cut -d= -f1 | grep -E '^(WANDB_|WEAVE_|OTEL_EXPORTER)' | sort || true
[ -n "${WANDB_API_KEY:-}" ] && echo "WANDB_API_KEY: set" || echo "WANDB_API_KEY: not set"
echo "-- reachability"
base="${WANDB_BASE_URL:-https://api.wandb.ai}"
code=$(curl -s -o /dev/null -m 8 -w '%{http_code}' "$base/" 2>/dev/null || true)
echo "$base -> HTTP ${code:-none}"
trace="${WEAVE_TRACE_URL:-https://trace.wandb.ai}"
code=$(curl -s -o /dev/null -m 8 -w '%{http_code}' "$trace/" 2>/dev/null || true)
echo "$trace -> HTTP ${code:-none} (any response means reachable)"
