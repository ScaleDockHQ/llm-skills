#!/usr/bin/env bash
# Read-only probe of an OpenAI- and Anthropic-compatible endpoint, the way a client would call it.
# Needs bash 3.2+, curl and jq. Never prints the key; prints status codes and short summaries only.
#
# Usage:
#   BASE=http://localhost:4000 MODEL=coder LLM_API_KEY_FILE=~/.config/llm/key scripts/check-endpoint.sh
#   BASE=http://localhost:11434 MODEL=qwen3:8b scripts/check-endpoint.sh        # no key needed
# Env:
#   BASE               server root WITHOUT /v1 (default http://localhost:8000)
#   MODEL              model name exactly as the client will send it (default: first id from /v1/models)
#   LLM_API_KEY        key value, or
#   LLM_API_KEY_FILE   path to a file holding the key (preferred; keep it mode 0600)
set -uo pipefail

BASE="${BASE:-http://localhost:8000}"
BASE="${BASE%/}"
BASE="${BASE%/v1}"

KEY="${LLM_API_KEY:-}"
if [ -z "$KEY" ] && [ -n "${LLM_API_KEY_FILE:-}" ]; then
  KEY="$(tr -d '\r\n' <"$LLM_API_KEY_FILE")"
fi

AUTH_H="X-Probe: check-endpoint"
[ -n "$KEY" ] && AUTH_H="Authorization: Bearer $KEY"

call() { # method path body [extra curl args...] -> prints the HTTP code, body goes to $TMP
  local method="$1" path="$2" body="${3:-}"
  shift 3
  if [ -n "$body" ]; then
    curl -sS -m 60 -o "$TMP" -w '%{http_code}' -X "$method" "$BASE$path" -H 'Content-Type: application/json' "$@" -d "$body"
  else
    curl -sS -m 30 -o "$TMP" -w '%{http_code}' -X "$method" "$BASE$path" "$@"
  fi
}

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo "base: $BASE  key: $([ -n "$KEY" ] && echo set || echo none)"

code="$(call GET /v1/models '' -H "$AUTH_H")"
echo "GET  /v1/models                 -> $code"
if [ "$code" = "200" ]; then
  ids="$(jq -r '[.data[]?.id] | .[0:8] | join(", ")' "$TMP" 2>/dev/null)"
  echo "     first ids: ${ids:-<none>}"
  [ -z "${MODEL:-}" ] && MODEL="$(jq -r '.data[0].id // empty' "$TMP" 2>/dev/null)"
fi
if [ -z "${MODEL:-}" ]; then
  echo "set MODEL to the name your client sends" >&2
  exit 2
fi
echo "model: $MODEL"

code="$(call POST /v1/chat/completions \
  "{\"model\":\"$MODEL\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" -H "$AUTH_H")"
echo "POST /v1/chat/completions       -> $code"
[ "$code" != "200" ] && echo "     $(jq -r '.error.message // .error // .detail // .' "$TMP" 2>/dev/null | head -c 200)"

code="$(call POST /v1/chat/completions \
  "{\"model\":\"$MODEL\",\"max_tokens\":128,\"messages\":[{\"role\":\"user\",\"content\":\"What is the weather in Paris? Use the tool.\"}],\"tools\":[{\"type\":\"function\",\"function\":{\"name\":\"get_weather\",\"parameters\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}},\"required\":[\"city\"]}}}]}" \
  -H "$AUTH_H")"
tc="$(jq -r '.choices[0].message.tool_calls[0].function.name // empty' "$TMP" 2>/dev/null)"
echo "POST /v1/chat/completions tools -> $code  tool_call: ${tc:-none}"

code="$(call POST /v1/chat/completions \
  "{\"model\":\"$MODEL\",\"max_tokens\":16,\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" -H "$AUTH_H")"
chunks="$(grep -c '^data:' "$TMP" 2>/dev/null || true)"
echo "POST /v1/chat/completions stream-> $code  sse data lines: ${chunks:-0}"

# Anthropic Messages. Servers differ on which auth header they honour, so try Bearer then x-api-key.
body="{\"model\":\"$MODEL\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}"
code="$(call POST /v1/messages "$body" -H 'anthropic-version: 2023-06-01' -H "$AUTH_H")"
echo "POST /v1/messages (Bearer)      -> $code"
if [ -n "$KEY" ]; then
  code="$(call POST /v1/messages "$body" -H 'anthropic-version: 2023-06-01' -H "x-api-key: $KEY")"
  echo "POST /v1/messages (x-api-key)   -> $code"
fi
