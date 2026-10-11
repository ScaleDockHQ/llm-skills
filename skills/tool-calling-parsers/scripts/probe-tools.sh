#!/usr/bin/env bash
# Probe tool calling on an OpenAI-compatible endpoint (bash 3.2+, curl, jq).
# Usage: probe-tools.sh BASE_URL MODEL [tool_choice]
#   BASE_URL     e.g. http://127.0.0.1:8000/v1
#   tool_choice  auto (default) | required | none | get_weather (named function)
# Auth: LLM_API_KEY_FILE (path to a 0600 file) or LLM_API_KEY; the key is never printed.
# Output: HTTP status, finish_reason, parsed tool calls, and whether markup leaked into content.
set -euo pipefail

base="${1:?usage: probe-tools.sh BASE_URL MODEL [tool_choice]}"
model="${2:?usage: probe-tools.sh BASE_URL MODEL [tool_choice]}"
choice="${3:-auto}"
base="${base%/}"

command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

key=""
if [ -n "${LLM_API_KEY_FILE:-}" ]; then
  [ -r "$LLM_API_KEY_FILE" ] || { echo "cannot read LLM_API_KEY_FILE" >&2; exit 2; }
  key="$(tr -d '\r\n' <"$LLM_API_KEY_FILE")"
elif [ -n "${LLM_API_KEY:-}" ]; then
  key="$LLM_API_KEY"
fi

tools='[{"type":"function","function":{"name":"get_weather","description":"Get the current weather in a city","parameters":{"type":"object","properties":{"city":{"type":"string"},"unit":{"type":"string","enum":["celsius","fahrenheit"]}},"required":["city","unit"],"additionalProperties":false}}}]'

case "$choice" in
  auto|required|none) tc="$(jq -n --arg c "$choice" '$c')" ;;
  *) tc="$(jq -n --arg n "$choice" '{type:"function",function:{name:$n}}')" ;;
esac

body="$(jq -n --arg m "$model" --argjson t "$tools" --argjson tc "$tc" \
  '{model:$m,temperature:0,max_tokens:1024,messages:[{role:"user",content:"What is the weather in Paris in celsius? Use the tool."}],tools:$t,tool_choice:$tc}')"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
args=(-sS -o "$tmp" -w '%{http_code}' -H 'Content-Type: application/json' -d "$body")
[ -n "$key" ] && args+=(-H "Authorization: Bearer $key")
code="$(curl "${args[@]}" "$base/chat/completions")" || { echo "request failed"; exit 1; }

echo "http_status: $code"
if [ "$code" != "200" ]; then
  jq -r '.error.message? // .error? // .' "$tmp" 2>/dev/null | head -c 600
  echo
  exit 1
fi

echo "finish_reason: $(jq -r '.choices[0].finish_reason // "n/a"' "$tmp")"
n="$(jq '.choices[0].message.tool_calls // [] | length' "$tmp")"
echo "tool_calls: $n"
jq -r '.choices[0].message.tool_calls // [] | .[] | "  \(.function.name) \(.function.arguments)"' "$tmp"

# Arguments must be valid JSON with the required keys.
bad=0
if [ "$n" -gt 0 ]; then
  if jq -e '.choices[0].message.tool_calls | all(.[]; (.function.arguments | fromjson | has("city") and has("unit")))' "$tmp" >/dev/null 2>&1; then
    echo "arguments_valid: yes"
  else
    echo "arguments_valid: NO"; bad=1
  fi
fi

# Raw markup left in content means the parser did not match the model's format.
content="$(jq -r '.choices[0].message.content // ""' "$tmp")"
if printf '%s' "$content" | grep -Eqi '<tool_call>|tool_calls_section|\[TOOL_CALLS\]|<function='; then
  echo "markup_in_content: YES (parser or template mismatch)"; bad=1
else
  echo "markup_in_content: no"
fi

if [ "$choice" != "none" ] && [ "$n" -eq 0 ]; then
  echo "no tool call returned (expected for auto only if the model chose not to call)"
  [ "$choice" = "auto" ] || bad=1
fi
exit "$bad"
