#!/usr/bin/env bash
# Read-only OpenTelemetry GenAI check: OTEL variables by name, GenAI package versions, content-capture mode,
# and whether the OTLP/HTTP trace route answers. Never prints header or key values.
# Usage: OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 scripts/check.sh
# Needs bash 3.2+ and curl.
set -u

fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }
note() { printf 'note  %s\n' "$1"; }

command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }

if command -v pip >/dev/null 2>&1; then
  for p in opentelemetry-api opentelemetry-sdk opentelemetry-util-genai opentelemetry-instrumentation-genai-openai opentelemetry-instrumentation-openai-v2; do
    v="$(pip show "$p" 2>/dev/null | sed -n 's/^Version: //p')"
    if [ -n "$v" ]; then ok "$p $v"; fi
  done
  if pip show opentelemetry-instrumentation-openai-v2 >/dev/null 2>&1; then
    note "opentelemetry-instrumentation-openai-v2 is deprecated; migrate to opentelemetry-instrumentation-genai-openai"
  fi
fi

for name in OTEL_SERVICE_NAME OTEL_EXPORTER_OTLP_ENDPOINT OTEL_EXPORTER_OTLP_TRACES_ENDPOINT OTEL_EXPORTER_OTLP_PROTOCOL OTEL_EXPORTER_OTLP_HEADERS OTEL_TRACES_EXPORTER OTEL_METRICS_EXPORTER OTEL_LOGS_EXPORTER OTEL_SEMCONV_STABILITY_OPT_IN OTEL_INSTRUMENTATION_GENAI_EMIT_EVENT OTEL_INSTRUMENTATION_GENAI_COMPLETION_HOOK; do
  eval "val=\${$name-__unset__}"
  if [ "$val" = "__unset__" ]; then note "$name not set"; else ok "$name is set"; fi
done

mode="${OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT:-}"
if [ -z "$mode" ]; then
  ok "content capture: none (variable unset)"
else
  lower="$(printf '%s' "$mode" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    no_content) ok "content capture: none" ;;
    span_only|event_only|span_and_event) note "content capture is ON ($lower): prompts and completions are emitted" ;;
    *) bad "invalid OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT value; treated as no_content" ;;
  esac
fi
if [ -n "${OTEL_SEMCONV_STABILITY_OPT_IN:-}" ]; then
  note "OTEL_SEMCONV_STABILITY_OPT_IN only matters to the deprecated openai-v2 package"
fi

url="${OTEL_EXPORTER_OTLP_TRACES_ENDPOINT:-}"
if [ -z "$url" ] && [ -n "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]; then
  url="${OTEL_EXPORTER_OTLP_ENDPOINT%/}/v1/traces"
fi
if [ -z "$url" ]; then
  note "no OTLP endpoint set: the SDK defaults to localhost (gRPC 4317 or HTTP 4318)"
  exit "$fail"
fi
case "$url" in
  http://*|https://*)
    case "$url" in */v1/traces/v1/traces) bad "path /v1/traces is doubled; set the base URL with OTEL_EXPORTER_OTLP_ENDPOINT" ;; esac
    code="$(curl -sS -m 5 -o /dev/null -w '%{http_code}' -X POST "$url" -H 'Content-Type: application/x-protobuf' --data-binary '' 2>/dev/null || true)"
    case "$code" in
      200|400|415) ok "POST $url answers HTTP $code (route exists)" ;;
      401|403) ok "route exists, HTTP $code without credentials (expected when auth is on)" ;;
      404) bad "HTTP 404: wrong path or no OTLP ingest at $url" ;;
      000|"") bad "$url unreachable (a gRPC-only port also looks like this)" ;;
      *) note "HTTP $code from $url" ;;
    esac
    ;;
  *) note "endpoint has no http(s) scheme: $url (gRPC style, not probed)" ;;
esac
exit "$fail"
