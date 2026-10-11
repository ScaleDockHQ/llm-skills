#!/usr/bin/env bash
# Read-only Sentry agent-tracing check. Needs bash 3.2+; curl and jq optional. Prints variable NAMES and versions, never values.
set -uo pipefail
echo "-- SDKs"
(pip show sentry-sdk 2>/dev/null | grep -E '^(Name|Version)') || echo "sentry-sdk not installed in this Python"
(pip show litellm openai 2>/dev/null | grep -E '^(Name|Version)') || true
[ -f package.json ] && jq -r '(.dependencies // {}) + (.devDependencies // {}) | to_entries[] | select(.key | test("^@sentry/")) | "\(.key) \(.value)"' package.json 2>/dev/null
echo "-- env names present"
env | cut -d= -f1 | grep -E '^(SENTRY_|OTEL_EXPORTER)' | sort || true
[ -n "${SENTRY_DSN:-}" ] && echo "SENTRY_DSN: set" || echo "SENTRY_DSN: not set"
echo "-- reachability (any HTTP code means reachable)"
host="${SENTRY_HOST:-https://sentry.io}"
code=$(curl -s -o /dev/null -m 8 -w '%{http_code}' "$host/" 2>/dev/null || true)
echo "$host -> HTTP ${code:-none}"
echo "-- newest releases"
curl -fsS -m 8 https://pypi.org/pypi/sentry-sdk/json 2>/dev/null | jq -r '"sentry-sdk " + .info.version' 2>/dev/null || echo "sentry-sdk lookup failed"
curl -fsS -m 8 https://registry.npmjs.org/@sentry%2fnode/latest 2>/dev/null | jq -r '"@sentry/node " + .version' 2>/dev/null || echo "@sentry/node lookup failed"
