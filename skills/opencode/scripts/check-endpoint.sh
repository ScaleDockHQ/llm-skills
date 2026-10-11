#!/usr/bin/env bash
# Probe an OpenAI Chat Completions endpoint the way OpenCode uses it (AI SDK openai-compatible).
# Environment:
#   OPENCODE_BASE_URL   API root including /v1 (required), for example http://HOST:PORT/v1
#   OPENCODE_MODEL      served model name (optional; first listed model is used if unset)
#   OPENCODE_KEY_ENV    NAME of the env var holding the key (default LOCAL_LLM_API_KEY); may be unset
# Prints status codes and verdicts only. Never prints the key or response bodies beyond
# short error messages. Needs bash 3.2+, curl, jq. Sends small requests only.
set -u

base="${OPENCODE_BASE_URL:-}"
model="${OPENCODE_MODEL:-}"
keyenv="${OPENCODE_KEY_ENV:-LOCAL_LLM_API_KEY}"
[ -n "$base" ] || { echo "OPENCODE_BASE_URL is not set" >&2; exit 2; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
base="${base%/}"
case "$base" in
  */v1) ;;
  *) echo "WARN base URL does not end in /v1; the SDK appends only /chat/completions" ;;
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
  if [ -z "$model" ]; then model="$(jq -r '.data[0].id // empty' "$body" 2>/dev/null)"; echo "NOTE OPENCODE_MODEL unset; using first listed model: $model"; fi
else
  echo "WARN no model list; set OPENCODE_MODEL explicitly"
fi
[ -n "$model" ] || { echo "FAIL no model name; set OPENCODE_MODEL" >&2; exit 1; }
fail=0

echo "== POST /chat/completions (plain)"
code="$(call POST /chat/completions "$(jq -nc --arg m "$model" '{model:$m,max_tokens:64,messages:[{role:"user",content:"Reply with: ok"}]}')")"
echo "status $code"
if [ "$code" = 200 ]; then
  echo "verdict: finish_reason=$(jq -r '.choices[0].finish_reason // "?"' "$body") reasoning_field=$(jq -r '.choices[0].message | if has("reasoning_content") then "reasoning_content" elif has("reasoning") then "reasoning" else "none" end' "$body" 2>/dev/null)"
else
  echo "FAIL $(errmsg)"; fail=1
  case "$code" in
    401|403) echo "hint: key missing or wrong; check the env var named in {env:NAME}" ;;
    404) echo "hint: wrong base path or unknown model; baseURL must end in /v1 once" ;;
    000) echo "hint: no connection; check host, port, VPN, TLS" ;;
  esac
fi

echo "== POST /chat/completions (stream)"
code="$(call POST /chat/completions "$(jq -nc --arg m "$model" '{model:$m,stream:true,max_tokens:64,messages:[{role:"user",content:"Reply with: ok"}]}')")"
echo "status $code"
if [ "$code" = 200 ]; then
  if grep -q '\[DONE\]' "$body"; then echo "verdict: stream ended with [DONE]"; else echo "WARN stream has no [DONE] terminator"; fail=1; fi
else
  echo "FAIL $(errmsg)"; fail=1
fi

echo "== POST /chat/completions (tool call)"
tool='{"type":"function","function":{"name":"get_time","description":"Return the current time for a timezone.","parameters":{"type":"object","properties":{"tz":{"type":"string"}},"required":["tz"]}}}'
code="$(call POST /chat/completions "$(jq -nc --arg m "$model" --argjson t "$tool" '{model:$m,max_tokens:256,tools:[$t],messages:[{role:"user",content:"What time is it in UTC? Use the get_time tool."}]}')")"
echo "status $code"
if [ "$code" = 200 ]; then
  if jq -e '(.choices[0].message.tool_calls // []) | length > 0' "$body" >/dev/null 2>&1; then
    echo "verdict: tool_calls returned"
  else
    echo "WARN no tool_calls: tool parser or template missing, or the model answered in prose"
  fi
else
  echo "FAIL $(errmsg)"; fail=1
fi

[ "$fail" = 0 ] && echo "RESULT ok" || { echo "RESULT problems found"; exit 1; }
