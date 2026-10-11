#!/usr/bin/env bash
# Read-only probe of an OpenAI-compatible endpoint the way an IDE client uses it.
# Usage: LLM_API_KEY_FILE=~/.config/llm/key scripts/probe.sh <base-url-with-/v1> <model>
#   or:  LLM_API_KEY=... scripts/probe.sh https://llm.example.com/v1 coder
# Checks: public reachability hint, /models, chat, streaming, tool call.
# Never prints the key. Needs bash 3.2+, curl, jq.
set -u

base="${1:-}"
model="${2:-}"
[ -n "$base" ] && [ -n "$model" ] || { echo "usage: probe.sh <base-url> <model>" >&2; exit 2; }
base="${base%/}"

key="${LLM_API_KEY:-}"
if [ -z "$key" ] && [ -n "${LLM_API_KEY_FILE:-}" ] && [ -r "$LLM_API_KEY_FILE" ]; then
  key="$(tr -d '\r\n' <"$LLM_API_KEY_FILE")"
fi
auth=()
[ -n "$key" ] && auth=(-H "Authorization: Bearer $key")

host="$(printf '%s' "$base" | sed -E 's#^[a-z]+://([^/:]+).*#\1#')"
case "$host" in
  localhost | 127.* | 10.* | 192.168.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[01].* | *.local | *.lan | *.internal | *.ts.net)
    echo "WARN  host '$host' looks private. Clients that call from a vendor cloud cannot reach it." ;;
  *) echo "INFO  host '$host' looks public" ;;
esac

code() { curl -sS -m "${PROBE_TIMEOUT:-60}" -o "$1" -w '%{http_code}' "${@:2}" 2>/dev/null || true; }
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

c="$(code "$tmp" "$base/models" ${auth[@]+"${auth[@]}"})"
echo "models      HTTP $c  $(jq -r '[.data[]?.id] | if length>0 then (.[0:8]|join(", ")) else "no ids" end' "$tmp" 2>/dev/null)"
jq -e --arg m "$model" '[.data[]?.id] | index($m)' "$tmp" >/dev/null 2>&1 || echo "WARN  model '$model' not listed by /models (may still work)"

body="$(jq -nc --arg m "$model" '{model:$m,messages:[{role:"user",content:"Reply with: ok"}],max_tokens:16}')"
c="$(code "$tmp" "$base/chat/completions" ${auth[@]+"${auth[@]}"} -H 'Content-Type: application/json' -d "$body")"
echo "chat        HTTP $c  $(jq -r '.choices[0].message.content // .error.message // .error // "?"' "$tmp" 2>/dev/null | head -c 120)"

body="$(jq -nc --arg m "$model" '{model:$m,stream:true,messages:[{role:"user",content:"Count to 3"}],max_tokens:32}')"
c="$(code "$tmp" "$base/chat/completions" ${auth[@]+"${auth[@]}"} -H 'Content-Type: application/json' -d "$body")"
echo "stream      HTTP $c  data-lines=$(grep -c '^data:' "$tmp" 2>/dev/null || true)  done=$(grep -c '^data: \[DONE\]' "$tmp" 2>/dev/null || true)"

body="$(jq -nc --arg m "$model" '{model:$m,max_tokens:128,tool_choice:"auto",
  messages:[{role:"user",content:"What is the weather in Paris? Use the tool."}],
  tools:[{type:"function",function:{name:"get_weather",description:"Get weather",parameters:{type:"object",properties:{city:{type:"string"}},required:["city"]}}}]}')"
c="$(code "$tmp" "$base/chat/completions" ${auth[@]+"${auth[@]}"} -H 'Content-Type: application/json' -d "$body")"
echo "tool call   HTTP $c  tool_calls=$(jq -r '.choices[0].message.tool_calls | length' "$tmp" 2>/dev/null || echo "?")  (0 means the engine or template did not emit tool calls)"
