#!/usr/bin/env bash
# Submit an API-format ComfyUI workflow, wait for it, and download the outputs.
# Usage: comfy-run.sh workflow_api.json
# Env:   COMFY_URL (default http://127.0.0.1:8188), COMFY_OUT (default ./comfy-out),
#        COMFY_TIMEOUT seconds to wait (default 900), COMFY_POLL seconds between polls (default 3).
# Needs bash 3.2+, curl and jq. Prints no secrets; the workflow file is sent as is.
set -euo pipefail

BASE="${COMFY_URL:-http://127.0.0.1:8188}"
OUT="${COMFY_OUT:-./comfy-out}"
TIMEOUT="${COMFY_TIMEOUT:-900}"
POLL="${COMFY_POLL:-3}"

[ "$#" -eq 1 ] && [ -r "$1" ] || { echo "usage: $0 workflow_api.json" >&2; exit 2; }
command -v curl >/dev/null && command -v jq >/dev/null || { echo "error: curl and jq are required" >&2; exit 2; }

# Reject the UI save format early: API format has no top-level "nodes" array.
if jq -e 'has("nodes") and has("links")' "$1" >/dev/null 2>&1; then
  echo "error: $1 looks like a UI-format workflow; export it with File, Export (API)" >&2
  exit 2
fi

resp="$(jq -c '{prompt: .}' "$1" | curl -sS -w '\n%{http_code}' -X POST "$BASE/prompt" \
  -H 'Content-Type: application/json' -d @-)"
code="${resp##*$'\n'}"
body="${resp%$'\n'*}"
if [ "$code" != "200" ]; then
  echo "error: POST /prompt returned HTTP $code" >&2
  printf '%s\n' "$body" | jq . >&2 2>/dev/null || printf '%s\n' "$body" >&2
  exit 1
fi
id="$(printf '%s' "$body" | jq -r .prompt_id)"
echo "queued prompt_id=$id" >&2

start="$(date +%s)"
while :; do
  hist="$(curl -sS "$BASE/history/$id")"
  if printf '%s' "$hist" | jq -e --arg p "$id" 'has($p)' >/dev/null; then break; fi
  if [ $(( $(date +%s) - start )) -ge "$TIMEOUT" ]; then
    echo "error: timed out after ${TIMEOUT}s waiting for $id (still queued or running?)" >&2
    exit 1
  fi
  sleep "$POLL"
done

status="$(printf '%s' "$hist" | jq -r --arg p "$id" '.[$p].status.status_str // "unknown"')"
if [ "$status" != "success" ]; then
  echo "error: job finished with status=$status" >&2
  printf '%s' "$hist" | jq --arg p "$id" '.[$p].status' >&2
  exit 1
fi

mkdir -p "$OUT"
n=0
# Every output item that has a filename (images, and video/audio nodes that use the same shape).
printf '%s' "$hist" | jq -r --arg p "$id" \
  '.[$p].outputs[] | to_entries[] | .value | arrays | .[] | objects | select(.filename != null)
   | [.filename, (.subfolder // ""), (.type // "output")] | join("|")' |
while IFS='|' read -r fname sub typ; do
  dest="$OUT/$id-$(basename "$fname")"
  curl -fsS -G "$BASE/view" --data-urlencode "filename=$fname" --data-urlencode "subfolder=$sub" \
    --data-urlencode "type=$typ" -o "$dest"
  echo "$dest"
done
