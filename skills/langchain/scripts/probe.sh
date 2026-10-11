#!/usr/bin/env bash
# Probe an OpenAI- or Anthropic-compatible endpoint the way an SDK would.
# Usage: BASE_URL=http://host:8000/v1 MODEL=name KEY_FILE=~/.config/llm/key scripts/probe.sh [openai|anthropic]
# BASE_URL for openai ends in /v1; for anthropic it is the root without /v1.
# Reads the key from KEY_FILE (0600) or LLM_API_KEY; never prints it. Needs curl and jq.
set -euo pipefail
API="${1:-openai}"
: "${BASE_URL:?set BASE_URL}" "${MODEL:?set MODEL}"
KEY="${LLM_API_KEY:-}"
if [ -z "$KEY" ] && [ -n "${KEY_FILE:-}" ]; then KEY="$(tr -d '\n' < "$KEY_FILE")"; fi
KEY="${KEY:-none}"
BASE_URL="${BASE_URL%/}"
tool='{"type":"function","function":{"name":"get_weather","description":"Weather by city","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}'
atool='{"name":"get_weather","description":"Weather by city","input_schema":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}'
call() { curl -sS -m 120 -w '\n%{http_code}' "$@"; }
show() { body="${1%$'\n'*}"; code="${1##*$'\n'}"; echo "  http $code"; printf '%s' "$body" | jq -c "$2" 2>/dev/null || printf '%s\n' "${body:0:300}"; }
case "$API" in
  openai)
    H=(-H "Authorization: Bearer $KEY" -H "Content-Type: application/json")
    echo "models:"; show "$(call "${H[@]}" "$BASE_URL/models")" '[.data[]?.id][:10]'
    echo "chat:"; show "$(call "${H[@]}" "$BASE_URL/chat/completions" -d "{\"model\":\"$MODEL\",\"max_tokens\":32,\"messages\":[{\"role\":\"user\",\"content\":\"Say ok\"}]}")" '.choices[0].message.content // .error'
    echo "tool call:"; show "$(call "${H[@]}" "$BASE_URL/chat/completions" -d "{\"model\":\"$MODEL\",\"max_tokens\":128,\"messages\":[{\"role\":\"user\",\"content\":\"Weather in Paris? Use the tool.\"}],\"tools\":[$tool]}")" '.choices[0].message.tool_calls[0].function // .error // "NO tool_calls"'
    echo "json_schema:"; show "$(call "${H[@]}" "$BASE_URL/chat/completions" -d "{\"model\":\"$MODEL\",\"max_tokens\":128,\"messages\":[{\"role\":\"user\",\"content\":\"Give city Paris\"}],\"response_format\":{\"type\":\"json_schema\",\"json_schema\":{\"name\":\"c\",\"schema\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}},\"required\":[\"city\"]}}}}")" '.choices[0].message.content // .error'
    echo "stream (usage chunk):"; curl -sS -N -m 60 "${H[@]}" "$BASE_URL/chat/completions" -d "{\"model\":\"$MODEL\",\"max_tokens\":16,\"stream\":true,\"stream_options\":{\"include_usage\":true},\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" | grep -c '"usage":{' | sed 's/^/  chunks with usage: /' || true ;;
  anthropic)
    H=(-H "x-api-key: $KEY" -H "Authorization: Bearer $KEY" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json")
    echo "messages:"; show "$(call "${H[@]}" "$BASE_URL/v1/messages" -d "{\"model\":\"$MODEL\",\"max_tokens\":32,\"messages\":[{\"role\":\"user\",\"content\":\"Say ok\"}]}")" '.content[0].text // .error'
    echo "tool use:"; show "$(call "${H[@]}" "$BASE_URL/v1/messages" -d "{\"model\":\"$MODEL\",\"max_tokens\":128,\"messages\":[{\"role\":\"user\",\"content\":\"Weather in Paris? Use the tool.\"}],\"tools\":[$atool]}")" '[.content[]|select(.type=="tool_use")][0] // .error // "NO tool_use"' ;;
  *) echo "usage: probe.sh [openai|anthropic]" >&2; exit 2 ;;
esac
