#!/usr/bin/env bash
# Wrapper around f5-tts_infer-cli with guard rails: checks the reference length and the tools.
# Usage: clone.sh ref.wav "exact reference transcript" "text to speak" [out.wav]
# Env:   F5_MODEL  default F5TTS_v1_Base
# Needs bash 3.2+, f5-tts_infer-cli, and ffprobe (ffmpeg) to check the reference length.
# The pretrained weights are CC-BY-NC. Clone only voices you have permission to use.
set -euo pipefail

[ "$#" -ge 3 ] || { echo "usage: $0 ref.wav \"ref transcript\" \"text to speak\" [out.wav]" >&2; exit 2; }
REF="$1"; REF_TEXT="$2"; GEN_TEXT="$3"; OUT="${4:-out.wav}"
MODEL="${F5_MODEL:-F5TTS_v1_Base}"

[ -r "$REF" ] || { echo "error: cannot read $REF" >&2; exit 2; }
command -v f5-tts_infer-cli >/dev/null || { echo "error: f5-tts_infer-cli not found; activate the environment (references/install.md)" >&2; exit 2; }

if command -v ffprobe >/dev/null; then
  dur="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$REF" | cut -d. -f1)"
  if [ "${dur:-0}" -ge 12 ]; then
    echo "warning: reference is ${dur}s; upstream advises under 12 s with trailing silence" >&2
  fi
else
  echo "warning: ffprobe not found; skipping the reference length check (ffmpeg is also required by F5-TTS)" >&2
fi

dir="$(dirname "$OUT")"; file="$(basename "$OUT")"
mkdir -p "$dir"
f5-tts_infer-cli --model "$MODEL" --ref_audio "$REF" --ref_text "$REF_TEXT" --gen_text "$GEN_TEXT" \
  --output_dir "$dir" --output_file "$file"
[ -s "$OUT" ] && echo "wrote $OUT" || { echo "error: no output written" >&2; exit 1; }
