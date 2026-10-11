#!/usr/bin/env bash
# Read-only OpenLLMetry check. Shows which TRACELOOP_* and OTEL_* variables are set (names only), the installed
# SDK version, and whether the OTLP/HTTP trace route answers. Never prints header or key values.
# Usage: TRACELOOP_BASE_URL=http://phoenix:6006 scripts/check.sh
# Needs bash 3.2+ and curl.
set -u

fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }
note() { printf 'note  %s\n' "$1"; }

command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }

if command -v pip >/dev/null 2>&1; then
  v="$(pip show traceloop-sdk 2>/dev/null | sed -n 's/^Version: //p')"
  if [ -n "$v" ]; then ok "traceloop-sdk $v installed"; else note "traceloop-sdk not installed in this Python"; fi
fi

for name in TRACELOOP_BASE_URL TRACELOOP_HEADERS TRACELOOP_API_KEY TRACELOOP_TRACE_CONTENT TRACELOOP_METRICS_ENABLED TRACELOOP_LOGGING_ENABLED OTEL_SERVICE_NAME OTEL_TRACES_SAMPLER OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT; do
  eval "val=\${$name-__unset__}"
  if [ "$val" = "__unset__" ]; then note "$name not set"; else ok "$name is set"; fi
done

if [ "${TRACELOOP_TRACE_CONTENT:-true}" != "false" ]; then note "content capture is ON (default): prompts and completions go to the backend"; fi

base="${TRACELOOP_BASE_URL:-}"
if [ -z "$base" ]; then
  note "TRACELOOP_BASE_URL empty: the SDK would use the Traceloop cloud and need a key"
  exit "$fail"
fi
case "$base" in
  http://*|https://*)
    base="${base%/}"
    case "$base" in */v1/traces) bad "base URL ends with /v1/traces; the SDK appends it, remove it" ;; esac
    code="$(curl -sS -m 5 -o /dev/null -w '%{http_code}' -X POST "$base/v1/traces" -H 'Content-Type: application/x-protobuf' --data-binary '' 2>/dev/null || true)"
    case "$code" in
      200|400|415) ok "POST $base/v1/traces answers HTTP $code (route exists)" ;;
      401|403) ok "route exists, HTTP $code without credentials (expected when auth is on)" ;;
      404) bad "HTTP 404: wrong base URL or backend lacks OTLP ingest" ;;
      000|"") bad "$base unreachable" ;;
      *) note "HTTP $code from $base/v1/traces" ;;
    esac
    ;;
  *) note "no http(s) prefix: the SDK will use gRPC to $base (not probed)" ;;
esac
exit "$fail"
