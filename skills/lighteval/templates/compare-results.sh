#!/usr/bin/env bash
# Compare per-task metrics of two Lighteval results_*.json files with stderr context.
# Usage: compare-results.sh <baseline.json> <candidate.json>
# Read-only; needs jq. Reads only the "results" object of each file.
set -euo pipefail

[ "$#" -eq 2 ] || { echo "usage: $0 <baseline.json> <candidate.json>" >&2; exit 2; }
command -v jq >/dev/null || { echo "error: jq not found" >&2; exit 1; }

jq -r -n --slurpfile a "$1" --slurpfile b "$2" '
  ($a[0].results) as $ra | ($b[0].results) as $rb
  | ["task","metric","baseline","candidate","delta","stderr_a","stderr_b"],
    ( $ra | to_entries[] | .key as $t | .value | to_entries[]
      | select(.key | endswith("_stderr") | not)
      | .key as $m | .value as $va
      | ($rb[$t][$m]) as $vb
      | select($vb != null and ($va|type) == "number")
      | [$t, $m, $va, $vb, ($vb - $va), ($ra[$t][$m + "_stderr"] // ""), ($rb[$t][$m + "_stderr"] // "")] )
  | @tsv' | column -t -s "$(printf '\t')"
echo "A delta smaller than about 2x the stderr is noise. Check the 'all' row last and read per-task rows first."
