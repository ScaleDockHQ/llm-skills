#!/usr/bin/env bash
# Read-only Datadog Agent Observability check. Needs bash 3.2+; curl and jq optional. Prints variable NAMES and versions, never values.
set -uo pipefail
echo "-- ddtrace / dd-trace"
(pip show ddtrace 2>/dev/null | grep -E '^(Name|Version)') || echo "ddtrace not installed in this Python"
(pip show litellm 2>/dev/null | grep -E '^(Name|Version)') || echo "litellm not installed in this Python"
[ -f package.json ] && jq -r '(.dependencies // {}) + (.devDependencies // {}) | to_entries[] | select(.key=="dd-trace") | "\(.key) \(.value)"' package.json 2>/dev/null
echo "-- env names present"
env | cut -d= -f1 | grep -E '^(DD_|OTEL_EXPORTER)' | sort || true
[ -n "${DD_API_KEY:-}" ] && echo "DD_API_KEY: set" || echo "DD_API_KEY: not set"
echo "-- Datadog Agent (if any)"
command -v datadog-agent >/dev/null 2>&1 && datadog-agent version 2>/dev/null | head -1 || echo "no datadog-agent binary on PATH"
(curl -s -o /dev/null -m 3 -w 'agent trace port 8126 -> HTTP %{http_code}\n' http://127.0.0.1:8126/info) 2>/dev/null || echo "nothing on 127.0.0.1:8126"
echo "-- newest releases"
curl -fsS -m 8 https://pypi.org/pypi/ddtrace/json 2>/dev/null | jq -r '"ddtrace " + .info.version' 2>/dev/null || echo "ddtrace lookup failed"
