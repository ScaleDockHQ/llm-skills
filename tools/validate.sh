#!/usr/bin/env bash
# validate.sh - structure and format checks for every skill in skills/*/.
#
# Usage: tools/validate.sh [skill-name ...]
#   Without arguments every skill is checked. Repository-wide checks always run.
# Requires: bash (3.2+), jq, ruby (with the bundled YAML library).
# Prints PASS/FAIL per check and exits 1 if any check failed.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 2

PASSES=0
FAILS=0
pass() { PASSES=$((PASSES + 1)); printf 'PASS  %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf 'FAIL  %s\n' "$1"; }

for tool in jq ruby; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "validate.sh: $tool is required" >&2
    exit 2
  fi
done

# Frontmatter checks. Prints one "PASS|FAIL<TAB>message" line per check.
read -r -d '' FRONTMATTER_RB <<'RUBY' || true
require "yaml"
require "date"
file, dir = ARGV
out = []
check = lambda { |ok, msg| out << "#{ok ? 'PASS' : 'FAIL'}\t#{msg}" }
text = File.read(file)
m = text.match(/\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(\r?\n|\z)/m)
if m.nil?
  check.call(false, "SKILL.md frontmatter: missing or not delimited by --- lines")
else
  begin
    fm = YAML.safe_load(m[1], permitted_classes: [Date, Time])
  rescue StandardError => e
    fm = nil
    check.call(false, "SKILL.md frontmatter: YAML error: #{e.message.lines.first.strip}")
  end
  if fm.is_a?(Hash)
    check.call(true, "SKILL.md frontmatter parses")
    name = fm["name"]
    if name.is_a?(String) && !name.empty?
      check.call(name.match?(/\A[a-z0-9]+(-[a-z0-9]+)*\z/), "name format (#{name})")
      check.call(name.length <= 64, "name length #{name.length} <= 64")
      check.call(name == dir, "name equals directory (#{name} vs #{dir})")
    else
      check.call(false, "name present")
    end
    desc = fm["description"]
    if desc.is_a?(String) && !desc.strip.empty?
      check.call(desc.length <= 1024, "description length #{desc.length} <= 1024")
    else
      check.call(false, "description present")
    end
    check.call(fm["license"] == "MIT", "license is MIT (#{fm['license'].inspect})")
    md = fm["metadata"]
    if md.is_a?(Hash)
      check.call(md.values.all? { |v| v.is_a?(String) }, "metadata values are strings")
      check.call(md["author"].is_a?(String) && !md["author"].empty?, "metadata.author present")
      check.call(md["version"].is_a?(String) && !md["version"].empty?, "metadata.version present")
    else
      check.call(false, "metadata mapping present")
    end
    if fm.key?("compatibility")
      c = fm["compatibility"]
      check.call(c.is_a?(String) && c.length <= 500, "compatibility length #{c.to_s.length} <= 500")
    end
  elsif !fm.nil?
    check.call(false, "SKILL.md frontmatter is not a mapping")
  end
end
puts out
RUBY

YAML_RB='begin; Psych.parse_stream(File.read(ARGV[0])); rescue StandardError => e; warn e.message.lines.first; exit 1; end'

# Repository-wide: no Python files.
py=$(find . -path ./.git -prune -o -path '*/node_modules' -prune -o -type f -name '*.py' -print)
if [ -z "$py" ]; then
  pass "repo: no *.py files"
else
  fail "repo: *.py files present: $(echo $py)"
fi

# Repository-wide: bench.sh copies identical to the canonical one.
CANON="skills/self-hosted-llms/scripts/bench.sh"
for b in skills/*/scripts/bench.sh; do
  [ -f "$b" ] || continue
  [ "$b" = "$CANON" ] && continue
  if [ -f "$CANON" ] && cmp -s "$b" "$CANON"; then
    pass "repo: $b identical to $CANON"
  else
    fail "repo: $b differs from $CANON"
  fi
done

if [ $# -gt 0 ]; then
  SKILLS=""
  for s in "$@"; do SKILLS="$SKILLS skills/${s%/}"; done
else
  SKILLS=$(ls -d skills/*/ 2>/dev/null | sed 's#/$##')
fi

for d in $SKILLS; do
  s=$(basename "$d")
  if [ ! -d "$d" ]; then
    fail "$s: no such skill directory"
    continue
  fi

  for f in SKILL.md README.md metadata.json LICENSE; do
    if [ -f "$d/$f" ]; then pass "$s: $f exists"; else fail "$s: $f missing"; fi
  done

  if [ -f "$d/SKILL.md" ]; then
    while IFS="$(printf '\t')" read -r status msg; do
      [ -n "$status" ] || continue
      if [ "$status" = PASS ]; then pass "$s: $msg"; else fail "$s: $msg"; fi
    done <<EOF
$(ruby -e "$FRONTMATTER_RB" "$d/SKILL.md" "$s" 2>&1)
EOF
    lines=$(wc -l < "$d/SKILL.md" | tr -d ' ')
    if [ "$lines" -le 300 ]; then pass "$s: SKILL.md $lines lines <= 300"; else fail "$s: SKILL.md $lines lines > 300"; fi
  fi

  if [ -f "$d/metadata.json" ]; then
    if jq -e 'type == "object"' "$d/metadata.json" >/dev/null 2>&1; then
      missing=$(jq -r '[ "version", "organization", "date", "abstract", "references" ] - keys | join(", ")' "$d/metadata.json")
      if [ -z "$missing" ]; then pass "$s: metadata.json has required keys"; else fail "$s: metadata.json missing: $missing"; fi
    else
      fail "$s: metadata.json is not a JSON object"
    fi
  fi

  if [ -f "$d/LICENSE" ]; then
    if cmp -s "$d/LICENSE" LICENSE; then pass "$s: LICENSE identical to root"; else fail "$s: LICENSE differs from root"; fi
  fi

  if [ -d "$d/references" ]; then
    n=0; bad=""
    for r in "$d"/references/*.md; do
      [ -f "$r" ] || continue
      n=$((n + 1))
      # First non-blank line is the H1; the next one is "> Verified against ..., YYYY-MM-DD".
      head2=$(grep -v '^[[:space:]]*$' "$r" | head -n 2)
      h1=$(printf '%s\n' "$head2" | sed -n 1p)
      ver=$(printf '%s\n' "$head2" | sed -n 2p)
      case "$h1" in "# "*) ;; *) bad="$bad $(basename "$r")"; continue ;; esac
      printf '%s\n' "$ver" | grep -Eq '^> Verified against .+, [0-9]{4}-[0-9]{2}-[0-9]{2}$' || bad="$bad $(basename "$r")"
    done
    if [ -z "$bad" ]; then pass "$s: $n references start with an H1 and a '> Verified against ..., <date>' line"; else fail "$s: H1 + '> Verified against ..., <date>' header missing or malformed in:$bad"; fi
  fi

  while IFS= read -r f; do
    if jq empty "$f" >/dev/null 2>&1; then pass "$s: json ok ${f#$d/}"; else fail "$s: invalid JSON ${f#$d/}"; fi
  done < <(find "$d" -type f -name '*.json' | sort)

  while IFS= read -r f; do
    if err=$(ruby -ryaml -e "$YAML_RB" "$f" 2>&1 | tr "\n" " "; exit "${PIPESTATUS[0]}"); then pass "$s: yaml ok ${f#$d/}"; else fail "$s: invalid YAML ${f#$d/}: $err"; fi
  done < <(find "$d" -type f \( -name '*.yaml' -o -name '*.yml' \) | sort)

  while IFS= read -r f; do
    if err=$(bash -n "$f" 2>&1 | tr "\n" " "; exit "${PIPESTATUS[0]}"); then pass "$s: bash -n ${f#$d/}"; else fail "$s: bash -n ${f#$d/}: $err"; fi
  done < <(find "$d" -type f -name '*.sh' | sort)
done

echo
echo "validate.sh: $PASSES passed, $FAILS failed"
[ "$FAILS" -eq 0 ]
