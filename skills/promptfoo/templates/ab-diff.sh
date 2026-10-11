#!/usr/bin/env bash
# Per-item diff of two promptfoo JSONL result files (one provider per file, no --repeat).
# Usage: ab-diff.sh baseline.jsonl candidate.jsonl [max_regressions]
# Prints a JSON summary; exits 1 when regressions exceed max_regressions (default 0), 2 on bad input.
# Needs bash 3.2+ and jq. Reads result files only; never prints secrets.
# promptfoo 0.124.1 JSONL rows are expected to carry `testIdx` and `success`. Check one row of your own
# output first (head -n 1 baseline.jsonl | jq 'keys'); the script exits 2 if either field is missing.
set -euo pipefail

[ "$#" -ge 2 ] || { echo "usage: $0 baseline.jsonl candidate.jsonl [max_regressions]" >&2; exit 2; }
base="$1"; cand="$2"; max="${3:-0}"
case "$max" in ''|*[!0-9]*) echo "max_regressions must be a non-negative integer" >&2; exit 2 ;; esac
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
for f in "$base" "$cand"; do
  [ -s "$f" ] || { echo "missing or empty: $f" >&2; exit 2; }
  jq -e -s 'all(.[]; has("testIdx") and has("success"))' "$f" >/dev/null \
    || { echo "$f: rows lack testIdx/success; inspect your promptfoo output" >&2; exit 2; }
done

summary="$(jq -n --slurpfile a "$base" --slurpfile b "$cand" '
  ($a | map({key: (.testIdx|tostring), value: .success}) | from_entries) as $A
  | ($b | map({key: (.testIdx|tostring), value: .success}) | from_entries) as $B
  | { items: ($A|length),
      candidate_items: ($B|length),
      baseline_pass: ([$A[]|select(.)]|length),
      candidate_pass: ([$B[]|select(.)]|length),
      regressions: [ $A|keys[] | select($A[.] == true  and $B[.] == false) ],
      fixes:       [ $A|keys[] | select($A[.] == false and $B[.] == true ) ],
      missing_in_candidate: [ $A|keys[] | select($B[.] == null) ] }')"

printf '%s\n' "$summary"

items="$(printf '%s' "$summary" | jq '.items')"
cand_items="$(printf '%s' "$summary" | jq '.candidate_items')"
missing="$(printf '%s' "$summary" | jq '.missing_in_candidate | length')"
regs="$(printf '%s' "$summary" | jq '.regressions | length')"

if [ "$items" -ne "$cand_items" ] || [ "$missing" -ne 0 ]; then
  echo "item sets differ (baseline $items, candidate $cand_items, missing $missing): not a like-for-like run" >&2
  exit 2
fi
if [ "$regs" -gt "$max" ]; then
  echo "FAIL: $regs regression(s) > allowed $max" >&2
  exit 1
fi
echo "OK: $regs regression(s) <= allowed $max" >&2
