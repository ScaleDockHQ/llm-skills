#!/usr/bin/env bash
# Convert one model to several EXL3 bitrates in sequence, resuming interrupted jobs.
# Needs bash 3.2+. Reads configuration from the environment; prints no secrets.
#   SRC=<dir>       required: unquantized HF model directory
#   OUT_PREFIX=<p>  required: outputs go to "<p>-<bits>bpw"
#   WORK_ROOT=<dir> required: per-bitrate work dirs are created under it
#   BITS="3.0 4.0"  required: space separated bitrates
#   EXL3_DIR=<dir>  optional: exllamav3 checkout holding convert.py (default ~/src/exllamav3)
#   EXTRA_ARGS="-hq -d 0,1"  optional: extra convert.py arguments
set -euo pipefail

: "${SRC:?set SRC}"
: "${OUT_PREFIX:?set OUT_PREFIX}"
: "${WORK_ROOT:?set WORK_ROOT}"
: "${BITS:?set BITS}"
EXL3_DIR="${EXL3_DIR:-$HOME/src/exllamav3}"
[ -f "$EXL3_DIR/convert.py" ] || { echo "error: $EXL3_DIR/convert.py not found" >&2; exit 1; }
[ -f "$SRC/config.json" ] || { echo "error: $SRC/config.json missing" >&2; exit 1; }

# shellcheck disable=SC2206
extra=(${EXTRA_ARGS:-})

cd "$EXL3_DIR"
for b in $BITS; do
  out="$OUT_PREFIX-${b}bpw"
  work="$WORK_ROOT/$b"
  if [ -f "$out/config.json" ]; then
    echo "skip $out (config.json exists; delete the output to redo)"
    continue
  fi
  echo "== $b bpw -> $out"
  if [ -d "$work" ] && [ -n "$(ls -A "$work" 2>/dev/null)" ]; then
    python convert.py -w "$work" -r
  else
    mkdir -p "$work"
    python convert.py -i "$SRC" -o "$out" -w "$work" -b "$b" ${extra[@]+"${extra[@]}"}
  fi
  # Keep the work dir until the output is evaluated; remove it by hand afterwards.
done
echo "done. Evaluate before deleting work dirs under $WORK_ROOT"
