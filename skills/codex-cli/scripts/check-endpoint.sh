#!/usr/bin/env bash
# Probe an OpenAI Responses endpoint the way Codex CLI uses it.
# Environment:
#   CODEX_BASE_URL   API root including /v1 (required), for example http://HOST:PORT/v1
#   CODEX_MODEL      served model name (optional; first listed model is used if unset)
#   CODEX_KEY_ENV    NAME of the env var holding the key (default LOCAL_LLM_API_KEY); may be unset
# Prints status codes and verdicts only. Never prints the key or response bodies beyond
# short error messages. Needs bash 3.2+, curl, jq. Sends small requests only.
set -u

base="${CODEX_BASE_URL:-}"
model="${CODEX_MODEL:-}"
keyenv="${CODEX_KEY_ENV:-LOCAL_LLM_API_KEY}"
[ -n "$base" ] || { echo "CODEX_BASE_URL is not set" >&2; exit 2; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
base="${base%/}"
case "$base" in
  */v1) ;;
  *) echo "WARN base URL does not end in /v1; Codex appends only /responses" ;;
esac

# Credential goes into a temp header file (0600) so it never appears in argv or output.
hdr="$(mktemp)"; body="$(mktemp)"
trap 'rm -f "$hdr" "$body"' EXIT
chmod 600 "$hdr"
echo "content-type: application/json" > "$hdr"
key="${!keyenv:-}"
if [ -n "$key" ]; then
  echo "Authorization: Bearer $key" >> "$hdr"
else
  echo "NOTE env var $keyenv is not set; probing without auth (fine for keyless engines)"
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

echo "== GET /models"
code="$(call GET /models)"
echo "status $code"
if [ "$code" = 200 ]; then
  echo "models: $(jq -r '[.data[]?.id] | .[0:20] | join(", ")' "$body" 2>/dev/null)"
  if [ -z "$model" ]; then model="$(jq -r '.data[0].id // empty' "$body" 2>/dev/null)"; echo "NOTE CODEX_MODEL unset; using first listed model: $model"; fi
else
  echo "WARN no model list; set CODEX_MODEL explicitly"
fi
[ -n "$model" ] || { echo "FAIL no model name; set CODEX_MODEL" >&2; exit 1; }
fail=0

echo "== POST /responses (plain)"
code="$(call POST /responses "$(jq -nc --arg m "$model" '{model:$m,max_output_tokens:64,input:[{role:"user",content:[{type:"input_text",text:"Reply with: ok"}]}]}')")"
echo "status $code"
if [ "$code" = 200 ]; then
  echo "verdict: object=$(jq -r '.object // "?"' "$body") status=$(jq -r '.status // "?"' "$body") output_types=$(jq -r '[.output[]?.type] | join(",")' "$body")"
else
  echo "FAIL $(errmsg)"; fail=1
  case "$code" in
    401|403) echo "hint: key missing or wrong; check the env var named by env_key" ;;
    404) echo "hint: no /responses route (chat-only engine: use LiteLLM's bridge) or unknown model" ;;
    000) echo "hint: no connection; check host, port, VPN, TLS" ;;
  esac
fi

echo "== POST /responses (stream)"
code="$(call POST /responses "$(jq -nc --arg m "$model" '{model:$m,stream:true,max_output_tokens:64,input:[{role:"user",content:[{type:"input_text",text:"Reply with: ok"}]}]}')")"
echo "status $code"
if [ "$code" = 200 ]; then
  if grep -q 'response.completed' "$body"; then echo "verdict: stream ended with response.completed"; else echo "WARN stream has no response.completed event"; fail=1; fi
else
  echo "FAIL $(errmsg)"; fail=1
fi

echo "== POST /responses (function call)"
tool='{"type":"function","name":"get_time","description":"Return the current time for a timezone.","parameters":{"type":"object","properties":{"tz":{"type":"string"}},"required":["tz"]}}'
code="$(call POST /responses "$(jq -nc --arg m "$model" --argjson t "$tool" '{model:$m,max_output_tokens:256,tools:[$t],input:[{role:"user",content:[{type:"input_text",text:"What time is it in UTC? Use the get_time tool."}]}]}')")"
echo "status $code"
if [ "$code" = 200 ]; then
  if jq -e '[.output[]? | select(.type=="function_call")] | length > 0' "$body" >/dev/null 2>&1; then
    echo "verdict: function_call item returned"
  else
    echo "WARN no function_call item: tool parser or template missing, or the model answered in prose"
  fi
else
  echo "FAIL $(errmsg)"; fail=1
fi

[ "$fail" = 0 ] && echo "RESULT ok" || { echo "RESULT problems found"; exit 1; }
