#!/usr/bin/env bash
# Compare headline metrics of two Inspect logs (.eval or .json) side by side.
# Usage: compare-logs.sh <baseline-log> <candidate-log>
# Needs inspect (in the active venv) and jq. Read-only; prints no secrets.
set -euo pipefail

[ "$#" -eq 2 ] || { echo "usage: $0 <baseline-log> <candidate-log>" >&2; exit 2; }
command -v inspect >/dev/null || { echo "error: inspect not on PATH (activate the venv)" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq not found" >&2; exit 1; }

summarize() {
  # "inspect log dump" prints any log as JSON regardless of on-disk format.
  inspect log dump "$1" | jq -r '
    [.eval.model, .eval.task, .status] as $h
    | ($h | @tsv),
      (.results.scores[]? | .name as $s | .metrics | to_entries[] | [$s, .key, (.value.value|tostring)] | @tsv)'
}

echo "== baseline: $1"; summarize "$1"
echo "== candidate: $2"; summarize "$2"
echo "A difference smaller than about 2x the reported stderr is noise; compare per-sample before deciding."
