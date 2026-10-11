#!/usr/bin/env bash
# Read-only Prometheus health check: targets, rules, alert state. Needs bash 3.2+, curl and jq.
# Usage: PROM=http://127.0.0.1:9090 scripts/check.sh
set -uo pipefail
PROM="${PROM:-http://127.0.0.1:9090}"
curl -fsS -m 5 "$PROM/-/ready" >/dev/null && echo "ready: $PROM" || { echo "not ready: $PROM"; exit 1; }
echo "-- targets not up"
curl -fsS -m 10 "$PROM/api/v1/targets" | jq -r '.data.activeTargets[] | select(.health!="up") | "\(.labels.job) \(.scrapeUrl) \(.lastError)"'
echo "-- target counts per job"
curl -fsS -m 10 "$PROM/api/v1/targets" | jq -r '.data.activeTargets | group_by(.labels.job)[] | "\(.[0].labels.job) \(map(select(.health=="up"))|length)/\(length)"'
echo "-- rule groups with errors"
curl -fsS -m 10 "$PROM/api/v1/rules" | jq -r '.data.groups[] | .name as $g | .rules[] | select(.health!="ok") | "\($g) \(.name) \(.lastError)"'
echo "-- firing alerts"
curl -fsS -m 10 "$PROM/api/v1/alerts" | jq -r '.data.alerts[] | select(.state=="firing") | "\(.labels.alertname) \(.labels.severity // "-")"'
echo "-- series in head"
curl -fsS -m 10 "$PROM/api/v1/query" --data-urlencode 'query=prometheus_tsdb_head_series' | jq -r '.data.result[0].value[1] // "n/a"'
