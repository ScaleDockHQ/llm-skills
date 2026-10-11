#!/usr/bin/env bash
# Compare the metrics of two lm-eval results_*.json files (baseline, candidate).
# Usage: compare-results.sh baseline.json candidate.json
# Prints one TSV row per task and metric: task, metric, baseline, candidate, delta, stderr_sum, verdict.
# verdict is "within-noise" when |delta| <= 2 * (stderr_baseline + stderr_candidate), else "moved".
# Assumes metric keys look like "<metric>,<filter>" with a matching "<metric>_stderr,<filter>" key,
# the convention seen in lm-eval results. Check one results file first: jq '.results' results_*.json
# Needs bash 3.2+ and jq. Reads files only; never prints secrets.
set -euo pipefail

[ "$#" -eq 2 ] || { echo "usage: $0 baseline.json candidate.json" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
for f in "$1" "$2"; do
  jq -e '.results | type == "object"' "$f" >/dev/null 2>&1 || { echo "$f: no .results object" >&2; exit 2; }
done

jq -r -n --slurpfile a "$1" --slurpfile b "$2" '
  def stderr_key($k): ($k | sub(","; "_stderr,")) as $s | if ($k | contains(",")) then $s else ($k + "_stderr") end;
  def num($v): if ($v | type) == "number" then $v else null end;
  ($a[0].results) as $A | ($b[0].results) as $B
  | $A | keys[] as $task
  | ($A[$task]) as $ta | ($B[$task] // {}) as $tb
  | $ta | keys[]
  | select(test("stderr") | not) | select(. != "alias") as $k
  | num($ta[$k]) as $x | num($tb[$k]) as $y
  | select($x != null)
  | (num($ta[stderr_key($k)]) // 0) as $sa
  | (num($tb[stderr_key($k)]) // 0) as $sb
  | if $y == null then [$task, $k, $x, "missing", "", "", "missing-in-candidate"]
    else ($y - $x) as $d
      | ($sa + $sb) as $s
      | [$task, $k, $x, $y, $d, $s, (if (($d | fabs) <= 2 * $s) then "within-noise" else "moved" end)]
    end
  | @tsv'
