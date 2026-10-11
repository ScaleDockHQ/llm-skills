#!/usr/bin/env bash
# Synthesise speech through a running Kokoro-FastAPI server and write it to a file.
# Usage: speak.sh "text to speak" out.mp3 [voice]
# Env:   KOKORO_BASE_URL  default http://127.0.0.1:8880
#        KOKORO_KEY_FILE  optional file with a bearer token for a gateway in front (never printed)
# Needs bash 3.2+, curl and jq. Output format follows the extension (mp3, wav, opus, flac, aac, pcm).
set -euo pipefail

BASE="${KOKORO_BASE_URL:-http://127.0.0.1:8880}"
[ "$#" -ge 2 ] || { echo "usage: $0 \"text\" out.mp3 [voice]" >&2; exit 2; }
TEXT="$1"; OUT="$2"; VOICE="${3:-af_heart}"
command -v curl >/dev/null && command -v jq >/dev/null || { echo "error: curl and jq are required" >&2; exit 2; }

ext="${OUT##*.}"
case "$ext" in
  mp3|wav|opus|flac|aac|pcm) fmt="$ext" ;;
  *) echo "error: output extension must be mp3, wav, opus, flac, aac or pcm" >&2; exit 2 ;;
esac

auth=()
if [ -n "${KOKORO_KEY_FILE:-}" ]; then
  [ -r "$KOKORO_KEY_FILE" ] || { echo "error: cannot read KOKORO_KEY_FILE" >&2; exit 2; }
  auth=(-H "Authorization: Bearer $(tr -d '\n' < "$KOKORO_KEY_FILE")")
fi

payload="$(jq -n --arg v "$VOICE" --arg t "$TEXT" --arg f "$fmt" \
  '{model:"kokoro", voice:$v, input:$t, response_format:$f}')"

code="$(curl -sS -o "$OUT" -w '%{http_code}' ${auth[@]+"${auth[@]}"} -H 'Content-Type: application/json' \
  -d "$payload" "$BASE/v1/audio/speech")" || { echo "error: cannot reach $BASE" >&2; exit 1; }

if [ "$code" != "200" ]; then
  echo "error: HTTP $code from $BASE" >&2
  head -c 600 "$OUT" >&2; echo >&2
  rm -f "$OUT"
  exit 1
fi
echo "wrote $OUT"
