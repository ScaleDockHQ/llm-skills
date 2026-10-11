#!/usr/bin/env bash
# build-catalog.sh - write an enriched, static OpenAI-style model list.
#
# Fetches GET <gateway>/v1/models, merges per-model metadata from a catalog
# JSON file (context window, capabilities, real created dates, names) and
# writes models.json atomically for Caddy to serve at /v1/models.
# Dependencies: bash, curl, jq. The API key is never printed.
#
# Options / environment:
#   --gateway URL     LLM_GATEWAY_URL   default http://127.0.0.1:4000
#   --catalog FILE    LLM_CATALOG       default /opt/llm-stack/catalog.json
#   --out FILE        LLM_CATALOG_OUT   default /var/lib/llm-stack/catalog/models.json
#   --key-file FILE   LLM_KEY_FILE      file with the key, or an env file with a
#                                       LITELLM_MASTER_KEY=... line
#                     LLM_API_KEY       key from the environment (if no key file)
#   --strict                            fail if a gateway model has no catalog entry
#   --dry-run                           print the result instead of writing it

set -u

GATEWAY="${LLM_GATEWAY_URL:-http://127.0.0.1:4000}"
CATALOG="${LLM_CATALOG:-/opt/llm-stack/catalog.json}"
OUT="${LLM_CATALOG_OUT:-/var/lib/llm-stack/catalog/models.json}"
KEY_FILE="${LLM_KEY_FILE:-}"
STRICT=0
DRY=0

die() { echo "build-catalog: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --gateway) GATEWAY="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --key-file) KEY_FILE="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

command -v curl >/dev/null 2>&1 || die "curl not found"
command -v jq >/dev/null 2>&1 || die "jq not found"
[ -r "$CATALOG" ] || die "cannot read catalog $CATALOG"
jq -e '.models | type == "object"' "$CATALOG" >/dev/null 2>&1 || die "$CATALOG has no .models object"

KEY=""
if [ -n "$KEY_FILE" ]; then
  [ -r "$KEY_FILE" ] || die "cannot read key file"
  KEY=$(grep -m1 '^LITELLM_MASTER_KEY=' "$KEY_FILE" | cut -d= -f2- | tr -d '"'"'"'\r')
  [ -n "$KEY" ] || KEY=$(head -n 1 "$KEY_FILE" | tr -d '\r\n')
elif [ -n "${LLM_API_KEY:-}" ]; then
  KEY="$LLM_API_KEY"
fi
[ -n "$KEY" ] || die "no API key (use --key-file or LLM_API_KEY)"

TMP=$(mktemp "${TMPDIR:-/tmp}/catalog.XXXXXX") || die "mktemp failed"
trap 'rm -f "$TMP" "$TMP.out"' EXIT

code=$(printf 'header = "Authorization: Bearer %s"\n' "$KEY" |
  curl -sS -K - -o "$TMP" -w '%{http_code}' --max-time 30 "${GATEWAY%/}/v1/models") || die "gateway unreachable at $GATEWAY"
[ "$code" = 200 ] || die "gateway returned HTTP $code for /v1/models"
jq -e '.data | type == "array"' "$TMP" >/dev/null 2>&1 || die "gateway response has no .data array"

missing=$(jq -r --slurpfile cat "$CATALOG" '.data[].id | select(($cat[0].models[($cat[0].aliases[.] // .)] // null) == null)' "$TMP")
if [ -n "$missing" ]; then
  echo "build-catalog: no catalog entry for: $(echo $missing)" >&2
  [ "$STRICT" = 1 ] && die "strict mode: add the models above to $CATALOG"
fi

jq --slurpfile cat "$CATALOG" '
  ($cat[0].defaults // {}) as $def
  | {object: "list",
     data: [ .data[] | . as $m
             | ($cat[0].models[($cat[0].aliases[$m.id] // $m.id)] // {}) as $c
             | ($m + $def + $c + {id: $m.id, object: "model"}) ]}
' "$TMP" > "$TMP.out" || die "merge failed"

count=$(jq '.data | length' "$TMP.out")
if [ "$DRY" = 1 ]; then
  cat "$TMP.out"
  exit 0
fi

mkdir -p "$(dirname "$OUT")" || die "cannot create $(dirname "$OUT")"
chmod 644 "$TMP.out"
mv "$TMP.out" "$OUT" || die "cannot write $OUT"
echo "build-catalog: wrote $count models to $OUT"
