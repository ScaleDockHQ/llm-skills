#!/usr/bin/env bash
# Probe an Anthropic-Messages endpoint the way Claude Code uses it.
# Reads ANTHROPIC_BASE_URL, ANTHROPIC_MODEL and one credential from the environment:
#   ANTHROPIC_AUTH_TOKEN (Authorization: Bearer) or ANTHROPIC_API_KEY (x-api-key).
# Prints status codes and verdicts only. Never prints the credential or response bodies
# beyond short error messages. Needs bash 3.2+, curl, jq. Read-only: sends small requests.
set -u

base="${ANTHROPIC_BASE_URL:-}"
model="${ANTHROPIC_MODEL:-}"
[ -n "$base" ] || { echo "ANTHROPIC_BASE_URL is not set" >&2; exit 2; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
base="${base%/}"
case "$base" in
  */v1) echo "WARN base URL ends in /v1: Claude Code would call /v1/v1/messages. Use the root URL." ;;
esac

# Credential goes into a temp header file (0600) so it never appears in argv or output.
hdr="$(mktemp)"; body="$(mktemp)"
trap 'rm -f "$hdr" "$body"' EXIT
chmod 600 "$hdr"
{
  echo "anthropic-version: 2023-06-01"
  echo "content-type: application/json"
  if [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then echo "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}"; fi
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then echo "x-api-key: ${ANTHROPIC_API_KEY}"; fi
} > "$hdr"
if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "NOTE no credential variable set; probing without auth (fine for keyless engines)"
fi

call() { # call METHOD PATH [DATA]; writes body file, prints HTTP code
  : > "$body"
  if [ "$1" = GET ]; then
    curl -sS -m "${CHECK_TIMEOUT:-120}" -o "$body" -w '%{http_code}' -H @"$hdr" "$base$2" 2>/dev/null || true
  else
    curl -sS -m "${CHECK_TIMEOUT:-120}" -o "$body" -w '%{http_code}' -H @"$hdr" -X POST "$base$2" -d "$3" 2>/dev/null || true
  fi
}
errmsg() { jq -r '(.error.message // .message // .detail // "") | tostring | .[0:160]' "$body" 2>/dev/null; }

echo "== GET /v1/models"
code="$(call GET /v1/models)"
echo "status $code"
if [ "$code" = 200 ]; then
  echo "models: $(jq -r '[.data[]?.id] | .[0:20] | join(", ")' "$body" 2>/dev/null)"
  if [ -z "$model" ]; then model="$(jq -r '.data[0].id // empty' "$body" 2>/dev/null)"; echo "NOTE ANTHROPIC_MODEL unset; using first listed model: $model"; fi
else
  echo "WARN no model list (discovery will not work; set ANTHROPIC_MODEL explicitly)"
fi
[ -n "$model" ] || { echo "FAIL no model name; set ANTHROPIC_MODEL" >&2; exit 1; }
fail=0

echo "== POST /v1/messages (plain)"
code="$(call POST /v1/messages "$(jq -nc --arg m "$model" '{model:$m,max_tokens:16,messages:[{role:"user",content:"Reply with: ok"}]}')")"
echo "status $code"
if [ "$code" = 200 ]; then
  echo "verdict: type=$(jq -r '.type' "$body") stop_reason=$(jq -r '.stop_reason' "$body") blocks=$(jq -r '[.content[]?.type] | join(",")' "$body")"
else
  echo "FAIL $(errmsg)"; fail=1
  case "$code" in
    401|403) echo "hint: wrong header? try ANTHROPIC_AUTH_TOKEN vs ANTHROPIC_API_KEY, or a revoked key" ;;
    404) echo "hint: no /v1/messages route or unknown model; check the model id and base URL" ;;
    000) echo "hint: no connection; check host, port, VPN, TLS" ;;
  esac
fi

echo "== POST /v1/messages (stream)"
code="$(call POST /v1/messages "$(jq -nc --arg m "$model" '{model:$m,max_tokens:16,stream:true,messages:[{role:"user",content:"Reply with: ok"}]}')")"
echo "status $code"
if [ "$code" = 200 ]; then
  if grep -q 'message_stop' "$body"; then echo "verdict: stream ended with message_stop"; else echo "WARN stream missing message_stop (Claude Code treats this as a dropped connection)"; fail=1; fi
  if grep -q 'message_delta' "$body"; then :; else echo "WARN no message_delta event"; fi
else
  echo "FAIL $(errmsg)"; fail=1
fi

echo "== POST /v1/messages (tool call)"
tool='{"name":"get_time","description":"Return the current time for a timezone.","input_schema":{"type":"object","properties":{"tz":{"type":"string"}},"required":["tz"]}}'
code="$(call POST /v1/messages "$(jq -nc --arg m "$model" --argjson t "$tool" '{model:$m,max_tokens:256,tools:[$t],messages:[{role:"user",content:"What time is it in UTC? Use the get_time tool."}]}')")"
echo "status $code"
if [ "$code" = 200 ]; then
  if jq -e '[.content[]? | select(.type=="tool_use")] | length > 0' "$body" >/dev/null 2>&1; then
    echo "verdict: tool_use block returned"
  else
    echo "WARN no tool_use block: tool parser or template missing, or the model answered in prose"
  fi
else
  echo "FAIL $(errmsg)"; fail=1
fi

echo "== POST /v1/messages/count_tokens (optional)"
code="$(call POST /v1/messages/count_tokens "$(jq -nc --arg m "$model" '{model:$m,messages:[{role:"user",content:"hello"}]}')")"
echo "status $code ($( [ "$code" = 200 ] && echo supported || echo 'absent: Claude Code estimates' ))"

[ "$fail" = 0 ] && echo "RESULT ok" || { echo "RESULT problems found"; exit 1; }
