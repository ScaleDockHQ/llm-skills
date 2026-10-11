#!/usr/bin/env bash
# Transcribe one audio file through a running Speaches server and print the text.
# Usage: transcribe.sh audio.wav [model] [language]
# Env:   SPEACHES_BASE_URL  default http://127.0.0.1:8000
#        SPEACHES_KEY_FILE  optional file holding the bearer key (never printed); or SPEACHES_API_KEY in the environment
# Needs bash 3.2+, curl and jq. The model must already be downloaded (POST /v1/models/<id>).
set -euo pipefail

BASE="${SPEACHES_BASE_URL:-http://127.0.0.1:8000}"
MODEL="${2:-Systran/faster-whisper-small}"
LANG_CODE="${3:-}"

[ "$#" -ge 1 ] && [ -r "$1" ] || { echo "usage: $0 audio.wav [model] [language]" >&2; exit 2; }
command -v curl >/dev/null && command -v jq >/dev/null || { echo "error: curl and jq are required" >&2; exit 2; }

key="${SPEACHES_API_KEY:-}"
if [ -z "$key" ] && [ -n "${SPEACHES_KEY_FILE:-}" ]; then
  [ -r "$SPEACHES_KEY_FILE" ] || { echo "error: cannot read SPEACHES_KEY_FILE" >&2; exit 2; }
  key="$(tr -d '\n' < "$SPEACHES_KEY_FILE")"
fi
auth=()
[ -n "$key" ] && auth=(-H "Authorization: Bearer $key")

lang=()
[ -n "$LANG_CODE" ] && lang=(-F "language=$LANG_CODE")

resp="$(curl -sS -w '\n%{http_code}' ${auth[@]+"${auth[@]}"} "$BASE/v1/audio/transcriptions" \
  -F "file=@$1" -F "model=$MODEL" ${lang[@]+"${lang[@]}"})" || { echo "error: cannot reach $BASE" >&2; exit 1; }
code="${resp##*$'\n'}"
body="${resp%$'\n'*}"

if [ "$code" != "200" ]; then
  echo "error: HTTP $code from $BASE" >&2
  printf '%s\n' "$body" >&2
  exit 1
fi
printf '%s\n' "$body" | jq -r '.text'
