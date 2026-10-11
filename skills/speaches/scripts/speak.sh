#!/usr/bin/env bash
# Synthesise speech through a running Speaches server and write it to a file.
# Usage: speak.sh "text to speak" out.wav [model] [voice]
# Env:   SPEACHES_BASE_URL  default http://127.0.0.1:8000
#        SPEACHES_KEY_FILE  optional file holding the bearer key (never printed); or SPEACHES_API_KEY in the environment
# Needs bash 3.2+, curl and jq. The TTS model must already be downloaded. Output format follows the file extension.
set -euo pipefail

BASE="${SPEACHES_BASE_URL:-http://127.0.0.1:8000}"
[ "$#" -ge 2 ] || { echo "usage: $0 \"text\" out.wav [model] [voice]" >&2; exit 2; }
TEXT="$1"; OUT="$2"
MODEL="${3:-speaches-ai/Kokoro-82M-v1.0-ONNX}"
VOICE="${4:-af_heart}"
command -v curl >/dev/null && command -v jq >/dev/null || { echo "error: curl and jq are required" >&2; exit 2; }

ext="${OUT##*.}"
case "$ext" in
  mp3|wav|flac|opus|aac|pcm) fmt="$ext" ;;
  *) echo "error: output extension must be mp3, wav, flac, opus, aac or pcm" >&2; exit 2 ;;
esac

key="${SPEACHES_API_KEY:-}"
if [ -z "$key" ] && [ -n "${SPEACHES_KEY_FILE:-}" ]; then
  [ -r "$SPEACHES_KEY_FILE" ] || { echo "error: cannot read SPEACHES_KEY_FILE" >&2; exit 2; }
  key="$(tr -d '\n' < "$SPEACHES_KEY_FILE")"
fi
auth=()
[ -n "$key" ] && auth=(-H "Authorization: Bearer $key")

payload="$(jq -n --arg m "$MODEL" --arg v "$VOICE" --arg t "$TEXT" --arg f "$fmt" \
  '{model:$m, voice:$v, input:$t, response_format:$f}')"

code="$(curl -sS -o "$OUT" -w '%{http_code}' ${auth[@]+"${auth[@]}"} -H 'Content-Type: application/json' \
  -d "$payload" "$BASE/v1/audio/speech")" || { echo "error: cannot reach $BASE" >&2; exit 1; }

if [ "$code" != "200" ]; then
  echo "error: HTTP $code from $BASE" >&2
  head -c 600 "$OUT" >&2; echo >&2
  rm -f "$OUT"
  exit 1
fi
echo "wrote $OUT"
