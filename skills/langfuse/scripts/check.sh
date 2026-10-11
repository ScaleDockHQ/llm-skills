#!/usr/bin/env bash
# Read-only Langfuse health and key check. Needs bash 3.2+, curl and jq.
# Usage: LANGFUSE_HOST=http://localhost:3000 scripts/check.sh
# Optional: LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY (names only are printed, never values).
set -uo pipefail

host="${LANGFUSE_HOST:-http://localhost:3000}"
worker="${LANGFUSE_WORKER_URL:-http://localhost:3030}"

echo "web health:    $(curl -sS -m 5 -o /dev/null -w '%{http_code}' "$host/api/public/health?failIfDatabaseUnavailable=true")"
echo "web ready:     $(curl -sS -m 5 -o /dev/null -w '%{http_code}' "$host/api/public/ready")"
echo "worker health: $(curl -sS -m 5 -o /dev/null -w '%{http_code}' "$worker/api/health")"
curl -sS -m 5 "$host/api/public/health" | jq -r '"version: \(.version // "unknown")"' 2>/dev/null

if [ -n "${LANGFUSE_PUBLIC_KEY:-}" ] && [ -n "${LANGFUSE_SECRET_KEY:-}" ]; then
  code="$(curl -sS -m 10 -o /tmp/lf-projects.$$ -w '%{http_code}' \
    -u "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" "$host/api/public/projects")"
  echo "key check:     HTTP $code (200 = keys valid for this host)"
  [ "$code" = "200" ] && jq -r '.data[] | "project: \(.name)"' /tmp/lf-projects.$$
  rm -f /tmp/lf-projects.$$
else
  echo "key check:     skipped (LANGFUSE_PUBLIC_KEY / LANGFUSE_SECRET_KEY not set)"
fi
