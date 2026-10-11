#!/usr/bin/env bash
# Run lm-evaluation-harness against an OpenAI-compatible server.
# Usage: run-endpoint.sh <chat|completions> <model-id> <tasks> [extra lm-eval args...]
# Environment:
#   LLM_BASE_URL   the /v1 root, default http://localhost:8000/v1
#   LLM_API_KEY    optional; exported to OPENAI_API_KEY for the harness (never printed)
#   TOKENIZER      HF repo or path (completions mode; required when the served name is an alias)
#   OUT            output directory, default ./lm-eval-results
#   LIMIT          if set, passes --limit (smoke runs only); unset for a real run
# Verified against lm-evaluation-harness v0.4.13 docs and source on 2026-10-11.
# Needs bash 3.2+ and the lm-eval CLI (pip install "lm_eval[api]==0.4.13") on PATH.
set -euo pipefail

[ "$#" -ge 3 ] || { echo "usage: $0 <chat|completions> <model-id> <tasks> [extra args]" >&2; exit 2; }
mode="$1"; model="$2"; tasks="$3"; shift 3
base="${LLM_BASE_URL:-http://localhost:8000/v1}"
out="${OUT:-./lm-eval-results}"
command -v lm-eval >/dev/null || { echo "lm-eval not found; install it in a venv first" >&2; exit 2; }

export OPENAI_API_KEY="${LLM_API_KEY:-}"

limit_args=()
if [ -n "${LIMIT:-}" ]; then
  limit_args=(--limit "$LIMIT")
  echo "NOTE: --limit $LIMIT is a smoke run; do not report these numbers" >&2
fi

case "$mode" in
  chat)
    lm-eval run --model local-chat-completions \
      --model_args "model=${model},base_url=${base}/chat/completions,num_concurrent=4,max_retries=3,timeout=300" \
      --tasks "$tasks" --apply_chat_template \
      --gen_kwargs "temperature=0,max_gen_toks=1024" \
      --log_samples --output_path "$out" \
      ${limit_args[@]+"${limit_args[@]}"} "$@"
    ;;
  completions)
    [ -n "${TOKENIZER:-}" ] || { echo "set TOKENIZER=<hf-repo-or-path> for completions mode" >&2; exit 2; }
    lm-eval run --model local-completions \
      --model_args "model=${model},base_url=${base}/completions,num_concurrent=4,max_retries=3,tokenized_requests=False,tokenizer_backend=huggingface,tokenizer=${TOKENIZER}" \
      --tasks "$tasks" \
      --log_samples --output_path "$out" \
      ${limit_args[@]+"${limit_args[@]}"} "$@"
    ;;
  *) echo "mode must be chat or completions" >&2; exit 2 ;;
esac
