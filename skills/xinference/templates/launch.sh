#!/usr/bin/env bash
# Launch one model on a running Xinference server and run a smoke test.
# Usage: ENDPOINT=http://127.0.0.1:9997 KEY_FILE=~/.xinference-key ./launch.sh   (run `xinference login` first on an authenticated server)
# Adjust the model flags for your hardware; check combinations with: xinference engine -n <model>
set -euo pipefail
ENDPOINT="${ENDPOINT:-http://127.0.0.1:9997}"
KEY_FILE="${KEY_FILE:-$HOME/.xinference-key}"   # 0600 file holding an API key
AUTH=()
if [ -r "$KEY_FILE" ]; then AUTH=(-H "Authorization: Bearer $(cat "$KEY_FILE")"); fi

xinference launch -e "$ENDPOINT" \
  --model-engine "${ENGINE:-transformers}" \
  -n "${MODEL:-qwen2.5-instruct}" -s "${SIZE:-0_5}" -f "${FORMAT:-pytorch}" \
  --model-uid "${UID_NAME:-qwen-test}"

curl -s ${AUTH[@]+"${AUTH[@]}"} "$ENDPOINT/v1/models" | jq -r '.data[].id'
curl -s ${AUTH[@]+"${AUTH[@]}"} "$ENDPOINT/v1/chat/completions" -H 'Content-Type: application/json' \
  -d "{\"model\":\"${UID_NAME:-qwen-test}\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hi\"}],\"max_tokens\":32}" \
  | jq '.choices[0].message'
