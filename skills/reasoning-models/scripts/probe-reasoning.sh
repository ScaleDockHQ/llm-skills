#!/usr/bin/env bash
# Probe reasoning output on an OpenAI-compatible endpoint (bash 3.2+, curl, jq).
# Usage: probe-reasoning.sh BASE_URL MODEL [mode]
#   mode  default | think-on | think-off | effort-low | effort-high
#         think-on/off send chat_template_kwargs.enable_thinking true/false;
#         effort-* send reasoning_effort low/high.
# Auth: LLM_API_KEY_FILE (path to a 0600 file) or LLM_API_KEY; the key is never printed.
# Reports: HTTP status, which field holds the trace (reasoning or reasoning_content),
# trace and answer lengths, reasoning tokens, and whether think tags leaked into content.
set -euo pipefail

base="${1:?usage: probe-reasoning.sh BASE_URL MODEL [mode]}"
model="${2:?usage: probe-reasoning.sh BASE_URL MODEL [mode]}"
mode="${3:-default}"
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

extra='{}'
case "$mode" in
  default) ;;
  think-on) extra='{"chat_template_kwargs":{"enable_thinking":true}}' ;;
  think-off) extra='{"chat_template_kwargs":{"enable_thinking":false}}' ;;
  effort-low) extra='{"reasoning_effort":"low"}' ;;
  effort-high) extra='{"reasoning_effort":"high"}' ;;
  *) echo "unknown mode: $mode" >&2; exit 2 ;;
esac

body="$(jq -n --arg m "$model" --argjson x "$extra" \
  '{model:$m,temperature:0,max_tokens:2048,messages:[{role:"user",content:"What is 17 times 23? Answer with the number only."}]} + $x')"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
args=(-sS -o "$tmp" -w '%{http_code}' -H 'Content-Type: application/json' -d "$body")
[ -n "$key" ] && args+=(-H "Authorization: Bearer $key")
code="$(curl "${args[@]}" "$base/chat/completions")" || { echo "request failed"; exit 1; }

echo "mode: $mode"
echo "http_status: $code"
if [ "$code" != "200" ]; then
  jq -r '.error.message? // .error? // .' "$tmp" 2>/dev/null | head -c 600
  echo
  exit 1
fi

echo "finish_reason: $(jq -r '.choices[0].finish_reason // "n/a"' "$tmp")"
r1="$(jq -r '.choices[0].message.reasoning // ""' "$tmp")"
r2="$(jq -r '.choices[0].message.reasoning_content // ""' "$tmp")"
content="$(jq -r '.choices[0].message.content // ""' "$tmp")"
field="none"
[ -n "$r1" ] && field="reasoning"
[ -n "$r2" ] && field="reasoning_content"
[ -n "$r1" ] && [ -n "$r2" ] && field="both"
echo "trace_field: $field"
echo "trace_chars: $(( ${#r1} + ${#r2} ))"
echo "answer_chars: ${#content}"
echo "reasoning_tokens: $(jq -r '.usage.completion_tokens_details.reasoning_tokens // "n/a"' "$tmp")"
echo "completion_tokens: $(jq -r '.usage.completion_tokens // "n/a"' "$tmp")"

bad=0
if printf '%s' "$content" | grep -Eqi '</?think>|<\|channel\|>'; then
  echo "tags_in_content: YES (reasoning parser or format missing)"; bad=1
else
  echo "tags_in_content: no"
fi
if [ -z "$content" ]; then
  echo "empty_answer: YES (thinking may have used all max_tokens)"; bad=1
fi
if [ "$mode" = "think-off" ] && [ "$field" != "none" ]; then
  echo "note: trace returned although thinking was turned off; check the kwarg name for this family"; bad=1
fi
exit "$bad"
