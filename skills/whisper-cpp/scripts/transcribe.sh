#!/usr/bin/env bash
# Transcribe one audio file through a running whisper-server and print the text.
# Usage: transcribe.sh audio.wav [language]      (language: code such as nl, default auto)
# Env:   WHISPER_URL  full transcription URL (default http://127.0.0.1:8080/inference;
#                     use http://127.0.0.1:8080/v1/audio/transcriptions if mounted there)
#        WHISPER_FORMAT  json (default), text, srt, vtt, verbose_json
#        WHISPER_KEY_FILE  optional file holding a bearer token (for a proxy in front); never printed
# Needs bash 3.2+, curl and jq. Non-WAV input needs the server started with --convert.
set -euo pipefail

URL="${WHISPER_URL:-http://127.0.0.1:8080/inference}"
FORMAT="${WHISPER_FORMAT:-json}"
LANG_CODE="${2:-auto}"

[ "$#" -ge 1 ] && [ -r "$1" ] || { echo "usage: $0 audio.wav [language]" >&2; exit 2; }
command -v curl >/dev/null && command -v jq >/dev/null || { echo "error: curl and jq are required" >&2; exit 2; }

auth=()
if [ -n "${WHISPER_KEY_FILE:-}" ]; then
  [ -r "$WHISPER_KEY_FILE" ] || { echo "error: cannot read WHISPER_KEY_FILE" >&2; exit 2; }
  auth=(-H "Authorization: Bearer $(tr -d '\n' < "$WHISPER_KEY_FILE")")
fi

resp="$(curl -sS -w '\n%{http_code}' ${auth[@]+"${auth[@]}"} "$URL" \
  -F "file=@$1" -F "response_format=$FORMAT" -F "language=$LANG_CODE")" || { echo "error: cannot reach $URL" >&2; exit 1; }
code="${resp##*$'\n'}"
body="${resp%$'\n'*}"

if [ "$code" != "200" ]; then
  echo "error: HTTP $code from $URL" >&2
  printf '%s\n' "$body" >&2
  exit 1
fi

if [ "$FORMAT" = "json" ]; then
  printf '%s\n' "$body" | jq -r '.text'
else
  printf '%s\n' "$body"
fi
