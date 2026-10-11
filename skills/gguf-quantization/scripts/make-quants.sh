#!/usr/bin/env bash
# Produce several GGUF quants from one 16-bit GGUF and an optional imatrix.
# Needs bash 3.2+. Reads configuration from the environment; prints no secrets.
#   M=<prefix>          required: prefix such that "$M-BF16.gguf" exists (the 16-bit source)
#   TYPES="Q4_K_M ..."  required: quant types to produce
#   IMATRIX=<file>      optional: importance matrix passed to llama-quantize
#   LLAMA_BIN=<dir>     optional: directory holding llama-quantize (default: from PATH)
#   EXTRA_ARGS="..."    optional: extra llama-quantize options, e.g. "--token-embedding-type q8_0"
#   DRY_RUN=1           only print final sizes (llama-quantize --dry-run)
#   SRC_TYPE=BF16       optional: suffix of the 16-bit source (default BF16)
set -euo pipefail

: "${M:?set M to the file prefix}"
: "${TYPES:?set TYPES to a space separated list}"
SRC_TYPE="${SRC_TYPE:-BF16}"
SRC="$M-$SRC_TYPE.gguf"
[ -f "$SRC" ] || { echo "error: missing $SRC" >&2; exit 1; }

if [ -n "${LLAMA_BIN:-}" ]; then
  QUANT="$LLAMA_BIN/llama-quantize"
else
  QUANT="$(command -v llama-quantize || true)"
fi
[ -x "$QUANT" ] || { echo "error: llama-quantize not found; set LLAMA_BIN" >&2; exit 1; }

imatrix_args=()
if [ -n "${IMATRIX:-}" ]; then
  [ -f "$IMATRIX" ] || { echo "error: missing imatrix $IMATRIX" >&2; exit 1; }
  imatrix_args=(--imatrix "$IMATRIX")
fi

# shellcheck disable=SC2206
extra=(${EXTRA_ARGS:-})

for t in $TYPES; do
  out="$M-$t.gguf"
  if [ -n "${DRY_RUN:-}" ]; then
    echo "== $t (dry run)"
    "$QUANT" --dry-run ${imatrix_args[@]+"${imatrix_args[@]}"} ${extra[@]+"${extra[@]}"} "$SRC" "$t"
    continue
  fi
  if [ -f "$out" ]; then echo "skip $out (exists)"; continue; fi
  echo "== $t -> $out"
  "$QUANT" ${imatrix_args[@]+"${imatrix_args[@]}"} ${extra[@]+"${extra[@]}"} "$SRC" "$out" "$t"
done
ls -l "$M"-*.gguf
