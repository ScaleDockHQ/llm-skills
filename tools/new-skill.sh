#!/usr/bin/env bash
# Scaffold a new skill from tools/skeleton/<kind>/.
# Usage: tools/new-skill.sh <name> <kind>
# Needs bash 3.2+; jq is optional (used only to check catalog.json).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KINDS="workflow product platform technique model-family stack"

usage() {
  echo "usage: tools/new-skill.sh <name> <kind>" >&2
  echo "kinds: $KINDS" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage
name="$1"
kind="$2"

if ! printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || [ "${#name}" -gt 64 ]; then
  echo "error: name must be kebab-case and at most 64 characters: $name" >&2
  exit 2
fi

case " $KINDS " in
  *" $kind "*) ;;
  *) echo "error: unknown kind: $kind" >&2; usage ;;
esac

src="$ROOT/tools/skeleton/$kind"
dest="$ROOT/skills/$name"

[ -d "$src" ] || { echo "error: missing skeleton: $src" >&2; exit 1; }
if [ -e "$dest" ]; then
  echo "error: $dest already exists; refusing to overwrite" >&2
  exit 1
fi

# "my-skill-name" -> "My Skill Name"
title="$(printf '%s' "$name" | awk -F- '{
  for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2)
  OFS = " "; print $0 }' OFS=' ')"
date_month="$(LC_ALL=C date +"%B %Y")"
date_iso="$(date +%Y-%m-%d)"

mkdir -p "$ROOT/skills"
cp -R "$src" "$dest"

# Escape sed replacement metacharacters (only & and \ and the | delimiter matter).
esc() { printf '%s' "$1" | sed -e 's/[&\\|]/\\&/g'; }
n="$(esc "$name")"; t="$(esc "$title")"; k="$(esc "$kind")"
dm="$(esc "$date_month")"; di="$(esc "$date_iso")"

find "$dest" -type f | while IFS= read -r file; do
  sed -e "s|{{name}}|$n|g" -e "s|{{title}}|$t|g" -e "s|{{kind}}|$k|g" \
    -e "s|{{date_month}}|$dm|g" -e "s|{{date_iso}}|$di|g" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
done

echo "created skills/$name ($kind)"

if command -v jq >/dev/null 2>&1 && [ -f "$ROOT/catalog.json" ]; then
  if ! jq -e --arg n "$name" '.skills[] | select(.name == $n)' "$ROOT/catalog.json" >/dev/null; then
    echo "note: $name is not in catalog.json; add an entry before running the validator" >&2
  fi
fi
echo "next: fill in the placeholders, list the skill in README.md, set its catalog status, run pnpm verify"
