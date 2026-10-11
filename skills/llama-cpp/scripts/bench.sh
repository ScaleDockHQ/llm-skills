#!/usr/bin/env bash
# bench.sh - fixed-protocol throughput benchmark for any OpenAI-compatible
# /v1/chat/completions endpoint. Dependencies: bash 3.2+, curl, jq, awk.
# License: MIT.

set -u

BASE_URL="${LLM_BASE_URL:-}"
MODEL="${LLM_MODEL:-}"
RUNS=5
WARMUP=1
MAX_TOKENS=256
PROMPT_TOKENS=0
CONCURRENCY=1
KEY_FILE=""
TIMEOUT=600

usage() {
  cat <<'EOF'
Usage: bench.sh --base-url URL --model NAME [options]

Measures an OpenAI-compatible chat completions endpoint with streaming
requests and fixed built-in prompts, so results are comparable across runs,
machines and configuration changes.

Required (flag or environment variable):
  --base-url URL       API base including /v1, e.g. http://127.0.0.1:8080/v1
                       (env LLM_BASE_URL)
  --model NAME         model name exactly as the endpoint expects it
                       (env LLM_MODEL)

Options:
  --runs N             measured runs per test (default 5)
  --warmup N           unmeasured warmup requests before testing (default 1)
  --max-tokens N       max_tokens for the decode test (default 256)
  --prompt-tokens N    also run a long-prompt prefill test with roughly N
                       prompt tokens (cold: unique prefix per run; warm:
                       identical prompt, exercises prefix caching)
  --concurrency N      also run N simultaneous decode requests per run and
                       report aggregate tok/s (default 1 = skip)
  --key-file PATH      file containing the API key (first line is used)
  --timeout SECONDS    per-request timeout (default 600)
  -h, --help           show this help

API key: --key-file, else env LLM_API_KEY, else no Authorization header.
The key is passed to curl on stdin and is never printed or logged.

Metrics (per run, then the median):
  ttfb      seconds until the first response byte (curl time_starttransfer).
            This approximates time-to-first-token: servers may flush headers,
            an empty role chunk, or loading-progress chunks before the first
            real token, and a cold model swap is included in it.
  total     seconds until the stream ended (curl time_total)
  decode    completion_tokens / (total - ttfb), tokens per second
  prefill   prompt_tokens / ttfb, tokens per second (long-prompt test only)
  aggregate sum(completion_tokens) / slowest total, under concurrency

Token counts come from the final usage chunk (stream_options.include_usage).
If the server sends no usage, counts fall back to the number of content
chunks and are marked with '~'.

Examples:
  bench.sh --base-url http://127.0.0.1:8080/v1 --model qwen-coder
  bench.sh --base-url https://llm.example.com/v1 --model qwen-coder \
    --key-file ~/.config/llm-stack/test.key --prompt-tokens 8000 --concurrency 4
EOF
}

die() { echo "bench.sh: $*" >&2; exit 1; }

is_int() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

while [ $# -gt 0 ]; do
  case "$1" in
    --base-url) BASE_URL="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --runs) RUNS="${2:-}"; shift 2 ;;
    --warmup) WARMUP="${2:-}"; shift 2 ;;
    --max-tokens) MAX_TOKENS="${2:-}"; shift 2 ;;
    --prompt-tokens) PROMPT_TOKENS="${2:-}"; shift 2 ;;
    --concurrency) CONCURRENCY="${2:-}"; shift 2 ;;
    --key-file) KEY_FILE="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done

[ -n "$BASE_URL" ] || die "missing --base-url (or LLM_BASE_URL)"
[ -n "$MODEL" ] || die "missing --model (or LLM_MODEL)"
for n in "$RUNS" "$WARMUP" "$MAX_TOKENS" "$PROMPT_TOKENS" "$CONCURRENCY" "$TIMEOUT"; do
  is_int "$n" || die "numeric option expected, got: $n"
done
[ "$RUNS" -ge 1 ] || die "--runs must be >= 1"
[ "$CONCURRENCY" -ge 1 ] || die "--concurrency must be >= 1"
command -v curl >/dev/null 2>&1 || die "curl not found"
command -v jq >/dev/null 2>&1 || die "jq not found"

BASE_URL="${BASE_URL%/}"
URL="$BASE_URL/chat/completions"

API_KEY=""
if [ -n "$KEY_FILE" ]; then
  [ -r "$KEY_FILE" ] || die "cannot read key file"
  API_KEY=$(head -n 1 "$KEY_FILE" | tr -d '\r\n')
elif [ -n "${LLM_API_KEY:-}" ]; then
  API_KEY="$LLM_API_KEY"
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/bench.XXXXXX") || die "mktemp failed"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT TERM

DECODE_PROMPT='Explain, step by step, how a hash table works: hashing, buckets, collision handling with chaining and open addressing, load factor, resizing, and the time complexity of insert, lookup and delete. Write in plain prose without code.'
FILLER='The following passage is reference material for a later question. A lighthouse keeper records the weather every hour, noting wind direction, wind speed, cloud cover, visibility, sea state and barometric pressure, and then compares each entry with the previous day so that slow changes become visible before a storm arrives. '
PREFILL_QUESTION='Based only on the reference material above, what does the keeper record every hour? Answer in one short sentence.'

# Build a request body. $1 = prompt text, $2 = max_tokens, $3 = output file.
# The prompt goes through stdin so long prompts never hit argument limits.
make_body() {
  printf '%s' "$1" | jq -Rs --arg model "$MODEL" --argjson max "$2" '{
    model: $model,
    messages: [{role: "user", content: .}],
    max_tokens: $max,
    temperature: 0,
    stream: true,
    stream_options: {include_usage: true}
  }' > "$3"
}

# Long prompt of roughly $1 tokens (about 60 tokens per filler block).
make_long_prompt() {
  blocks=$(( ($1 + 59) / 60 ))
  [ "$blocks" -ge 1 ] || blocks=1
  out=""
  i=0
  while [ "$i" -lt "$blocks" ]; do
    out="$out$FILLER"
    i=$((i + 1))
  done
  printf '%s\n\n%s' "$out" "$PREFILL_QUESTION"
}

# One streaming request. $1 = body file, $2 = output prefix.
# Writes $2.sse (stream), $2.timing ("http ttfb total").
do_request() {
  if [ -n "$API_KEY" ]; then
    printf 'header = "Authorization: Bearer %s"\n' "$API_KEY" |
      curl -sS -N -K - -o "$2.sse" -w '%{http_code} %{time_starttransfer} %{time_total}\n' \
        --max-time "$TIMEOUT" -H 'Content-Type: application/json' \
        --data-binary "@$1" "$URL" > "$2.timing" 2> "$2.err"
  else
    curl -sS -N -o "$2.sse" -w '%{http_code} %{time_starttransfer} %{time_total}\n' \
      --max-time "$TIMEOUT" -H 'Content-Type: application/json' \
      --data-binary "@$1" "$URL" < /dev/null > "$2.timing" 2> "$2.err"
  fi
}

# Parse one result. $1 = output prefix. Prints "ok ttfb total prompt completion approx"
# or "err message".
parse_result() {
  read -r code ttfb total < "$1.timing" 2>/dev/null || code=000
  if [ "$code" = "000" ]; then
    echo "err no HTTP response: $(head -c 200 "$1.err" 2>/dev/null | tr '\n' ' ')"
    return
  fi
  if [ "$code" != "200" ]; then
    echo "err HTTP $code: $(head -c 300 "$1.sse" 2>/dev/null | tr '\n' ' ')"
    return
  fi
  usage_json=$(sed -n 's/^data: *//p' "$1.sse" | grep -v '^\[DONE\]' |
    jq -c 'select(.usage != null) | .usage' 2>/dev/null | tail -n 1)
  approx=""
  if [ -n "$usage_json" ]; then
    pt=$(printf '%s' "$usage_json" | jq -r '.prompt_tokens // 0')
    ct=$(printf '%s' "$usage_json" | jq -r '.completion_tokens // 0')
  else
    pt=0
    ct=$(sed -n 's/^data: *//p' "$1.sse" | grep -v '^\[DONE\]' |
      jq -r 'select((.choices // [])[0].delta | (.content // .reasoning_content // .reasoning // "") != "") | 1' 2>/dev/null | wc -l | tr -d ' ')
    approx="~"
  fi
  echo "ok $ttfb $total $pt $ct $approx"
}

median() { sort -n | awk '{a[NR]=$1} END {if (NR==0) {print "n/a"; exit} if (NR%2) print a[(NR+1)/2]; else printf "%.4f\n", (a[NR/2]+a[NR/2+1])/2}'; }

fmt() { awk -v v="$1" 'BEGIN { if (v == "n/a") print v; else printf "%.2f", v }'; }

# Run a sequential test. $1 = label, $2 = mode (decode|prefill-cold|prefill-warm).
run_test() {
  label="$1"; mode="$2"
  : > "$WORK/ttfb.list"; : > "$WORK/total.list"; : > "$WORK/decode.list"; : > "$WORK/prefill.list"
  echo
  echo "== $label"
  printf '%-5s %8s %8s %8s %8s %10s %10s\n' run ttfb_s total_s prompt compl decode_t/s prefill_t/s
  r=1
  while [ "$r" -le "$RUNS" ]; do
    case "$mode" in
      decode) make_body "$DECODE_PROMPT" "$MAX_TOKENS" "$WORK/body.json" ;;
      prefill-cold) make_body "Run $r-$$-$(date +%s). $LONG_PROMPT" 8 "$WORK/body.json" ;;
      prefill-warm) make_body "$LONG_PROMPT" 8 "$WORK/body.json" ;;
    esac
    do_request "$WORK/body.json" "$WORK/r"
    set -- $(parse_result "$WORK/r")
    if [ "$1" != "ok" ]; then
      shift; echo "$r     error: $*"
      r=$((r + 1)); continue
    fi
    ttfb=$2; total=$3; pt=$4; ct=$5; approx=${6:-}
    dec=$(awk -v c="$ct" -v t="$total" -v f="$ttfb" 'BEGIN { d=t-f; if (d>0 && c>0) printf "%.4f", c/d; else print "n/a" }')
    pre="n/a"
    [ "$mode" = decode ] || pre=$(awk -v p="$pt" -v f="$ttfb" 'BEGIN { if (f>0 && p>0) printf "%.4f", p/f; else print "n/a" }')
    printf '%-5s %8s %8s %8s %8s %10s %10s\n' "$r" "$(fmt "$ttfb")" "$(fmt "$total")" "$pt" "$approx$ct" "$(fmt "$dec")" "$(fmt "$pre")"
    echo "$ttfb" >> "$WORK/ttfb.list"; echo "$total" >> "$WORK/total.list"
    [ "$dec" != "n/a" ] && echo "$dec" >> "$WORK/decode.list"
    [ "$pre" != "n/a" ] && echo "$pre" >> "$WORK/prefill.list"
    r=$((r + 1))
  done
  m_ttfb=$(median < "$WORK/ttfb.list"); m_total=$(median < "$WORK/total.list")
  m_dec=$(median < "$WORK/decode.list"); m_pre=$(median < "$WORK/prefill.list")
  printf '%-5s %8s %8s %8s %8s %10s %10s\n' median "$(fmt "$m_ttfb")" "$(fmt "$m_total")" - - "$(fmt "$m_dec")" "$(fmt "$m_pre")"
  case "$mode" in
    decode) SUM_DECODE="$m_dec"; SUM_TTFB="$m_ttfb" ;;
    prefill-cold) SUM_PREFILL_COLD="$m_pre" ;;
    prefill-warm) SUM_PREFILL_WARM="$m_pre" ;;
  esac
}

# Concurrency test: $CONCURRENCY simultaneous decode requests per run.
run_concurrency() {
  : > "$WORK/agg.list"
  echo
  echo "== concurrency $CONCURRENCY (decode prompt, max_tokens $MAX_TOKENS)"
  printf '%-5s %8s %10s %12s %8s\n' run ok compl_sum slowest_s agg_t/s
  make_body "$DECODE_PROMPT" "$MAX_TOKENS" "$WORK/body.json"
  r=1
  while [ "$r" -le "$RUNS" ]; do
    j=1
    while [ "$j" -le "$CONCURRENCY" ]; do
      do_request "$WORK/body.json" "$WORK/c$j" &
      j=$((j + 1))
    done
    wait
    ok=0; sum=0; slowest=0
    j=1
    while [ "$j" -le "$CONCURRENCY" ]; do
      set -- $(parse_result "$WORK/c$j")
      if [ "$1" = "ok" ]; then
        ok=$((ok + 1)); sum=$((sum + $5))
        slowest=$(awk -v a="$slowest" -v b="$3" 'BEGIN { print (b>a)?b:a }')
      fi
      j=$((j + 1))
    done
    agg=$(awk -v s="$sum" -v t="$slowest" 'BEGIN { if (t>0 && s>0) printf "%.4f", s/t; else print "n/a" }')
    printf '%-5s %8s %10s %12s %8s\n' "$r" "$ok/$CONCURRENCY" "$sum" "$(fmt "$slowest")" "$(fmt "$agg")"
    [ "$agg" != "n/a" ] && echo "$agg" >> "$WORK/agg.list"
    r=$((r + 1))
  done
  SUM_AGG=$(median < "$WORK/agg.list")
  printf '%-5s %8s %10s %12s %8s\n' median - - - "$(fmt "$SUM_AGG")"
}

SUM_DECODE="n/a"; SUM_TTFB="n/a"; SUM_PREFILL_COLD="n/a"; SUM_PREFILL_WARM="n/a"; SUM_AGG="n/a"

echo "bench.sh  endpoint: $URL"
echo "          model: $MODEL  runs: $RUNS  warmup: $WARMUP  max_tokens: $MAX_TOKENS"
echo "          prompt_tokens: $PROMPT_TOKENS  concurrency: $CONCURRENCY  auth: $([ -n "$API_KEY" ] && echo yes || echo no)"
echo "          started: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [ "$WARMUP" -gt 0 ]; then
  echo
  echo "== warmup ($WARMUP request(s), not measured; includes any cold model load)"
  make_body "$DECODE_PROMPT" 32 "$WORK/body.json"
  w=1
  while [ "$w" -le "$WARMUP" ]; do
    do_request "$WORK/body.json" "$WORK/w"
    set -- $(parse_result "$WORK/w")
    if [ "$1" = "ok" ]; then echo "warmup $w ok ($(fmt "$3") s)"; else shift; echo "warmup $w error: $*"; fi
    w=$((w + 1))
  done
fi

run_test "decode (fixed prompt, max_tokens $MAX_TOKENS)" decode

if [ "$PROMPT_TOKENS" -gt 0 ]; then
  LONG_PROMPT=$(make_long_prompt "$PROMPT_TOKENS")
  run_test "prefill cold (~$PROMPT_TOKENS prompt tokens, unique prefix per run)" prefill-cold
  run_test "prefill warm (~$PROMPT_TOKENS prompt tokens, identical prompt: prefix cache)" prefill-warm
fi

if [ "$CONCURRENCY" -gt 1 ]; then
  run_concurrency
fi

echo
echo "== summary (medians)"
echo "model=$MODEL ttfb_s=$(fmt "$SUM_TTFB") decode_tps=$(fmt "$SUM_DECODE") prefill_cold_tps=$(fmt "$SUM_PREFILL_COLD") prefill_warm_tps=$(fmt "$SUM_PREFILL_WARM") concurrency=$CONCURRENCY aggregate_tps=$(fmt "$SUM_AGG")"
[ "$SUM_DECODE" != "n/a" ] || exit 1
