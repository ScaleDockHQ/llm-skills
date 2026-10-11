#!/usr/bin/env bash
# Read-only LM Studio health check. Needs bash 3.2+, curl and jq.
# Usage: lms-health.sh [base-url]        (default http://127.0.0.1:1234)
# Auth: set LM_API_TOKEN in the environment if Require Authentication is on. The token is never printed.
set -u

base="${1:-http://127.0.0.1:1234}"
fail=0

auth=()
if [ -n "${LM_API_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer ${LM_API_TOKEN}")
fi

if command -v lms >/dev/null 2>&1; then
  echo "lms: found"
  lms server status --json --quiet 2>/dev/null || echo "lms: server status unavailable"
else
  echo "lms: not on PATH (run LM Studio once, or see references/install.md)"
fi

code="$(curl -s -o /tmp/lms-health.$$ -w '%{http_code}' --max-time 5 "${auth[@]+"${auth[@]}"}" "${base}/v1/models" 2>/dev/null)"
case "$code" in
  200)
    n="$(jq -r '.data | length' /tmp/lms-health.$$ 2>/dev/null || echo '?')"
    echo "api: ok (${base}/v1/models, ${n} models listed)"
    jq -r '.data[].id' /tmp/lms-health.$$ 2>/dev/null | head -20
    ;;
  401|403)
    echo "api: authentication required (set LM_API_TOKEN)"
    fail=1
    ;;
  000)
    echo "api: no response from ${base} (server stopped, wrong port or bind?)"
    fail=1
    ;;
  *)
    echo "api: unexpected HTTP ${code}"
    fail=1
    ;;
esac
rm -f /tmp/lms-health.$$

if command -v lms >/dev/null 2>&1; then
  echo "loaded models:"
  lms ps 2>/dev/null | head -20
fi

exit "$fail"
