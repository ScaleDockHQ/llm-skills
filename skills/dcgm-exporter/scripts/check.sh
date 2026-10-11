#!/usr/bin/env bash
# Read-only dcgm-exporter check. Needs bash 3.2+, curl. Usage: DCGM=http://127.0.0.1:9400 scripts/check.sh
set -uo pipefail
DCGM="${DCGM:-http://127.0.0.1:9400}"
nvidia-smi -L 2>/dev/null || echo "nvidia-smi not available on this host"
body="$(curl -fsS -m 10 "$DCGM/metrics")" || { echo "no response from $DCGM/metrics"; exit 1; }
echo "DCGM_ series: $(printf '%s\n' "$body" | grep -c '^DCGM_')"
echo "-- families"
printf '%s\n' "$body" | grep -E '^DCGM_' | cut -d'{' -f1 | sort -u
echo "-- profiling fields present: $(printf '%s\n' "$body" | grep -c '^DCGM_FI_PROF_')"
echo "-- GPU count by series: $(printf '%s\n' "$body" | grep '^DCGM_FI_DEV_GPU_TEMP' | wc -l | tr -d ' ')"
echo "-- first label set"
printf '%s\n' "$body" | grep -m1 '^DCGM_FI_DEV_GPU_TEMP' | sed -E 's/UUID="[^"]*"/UUID="..."/'
