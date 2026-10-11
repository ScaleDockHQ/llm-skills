#!/usr/bin/env bash
# Launch an SGLang server with KTransformers CPU+GPU hybrid experts. Edit the variables, review the command, then run.
# Values below follow upstream's Qwen3-30B-A3B BF16 example; set CPUINFER to your PHYSICAL cores and POOLS to your NUMA nodes.
#   lscpu | grep -E "^CPU\(s\)|Thread\(s\) per core|NUMA node\(s\)"
set -euo pipefail

VENV="${KT_VENV:-$HOME/kt-venv}"
MODEL="${KT_MODEL:-/models/Qwen3-30B-A3B}"            # GPU weights (Hugging Face directory)
CPU_WEIGHTS="${KT_WEIGHTS:-$MODEL}"                   # native methods reuse the checkpoint; AMX needs converted weights; LLAMAFILE a GGUF dir
METHOD="${KT_METHOD:-BF16}"                           # BF16, FP8, FP8_PERCHANNEL, RAWINT4, AMXINT8, AMXINT4, LLAMAFILE
HOST="${KT_HOST:-127.0.0.1}"                          # loopback: the server has no authentication by default
PORT="${KT_PORT:-30000}"
CPUINFER="${KT_CPUINFER:?set KT_CPUINFER to the number of physical cores}"
POOLS="${KT_POOLS:?set KT_POOLS to the number of NUMA nodes}"
GPU_EXPERTS="${KT_GPU_EXPERTS:-32}"
NAME="${KT_NAME:-qwen3}"

# shellcheck disable=SC1091
. "$VENV/bin/activate"
# Keep HF_TOKEN (only needed to download gated models) in the environment or a 0600 file; this script never prints it.

exec python -m sglang.launch_server \
  --host "$HOST" --port "$PORT" \
  --model "$MODEL" \
  --kt-weight-path "$CPU_WEIGHTS" \
  --kt-method "$METHOD" \
  --kt-cpuinfer "$CPUINFER" \
  --kt-threadpool-count "$POOLS" \
  --kt-num-gpu-experts "$GPU_EXPERTS" \
  --kt-max-deferred-experts-per-token 2 \
  --attention-backend flashinfer \
  --trust-remote-code \
  --mem-fraction-static 0.80 \
  --chunked-prefill-size 16384 \
  --max-running-requests 4 \
  --served-model-name "$NAME" \
  --enable-mixed-chunk \
  --tensor-parallel-size 1 \
  --disable-shared-experts-fusion \
  --enable-metrics
# Native methods (FP8, RAWINT4, BF16) also take: --kt-gpu-prefill-token-threshold 4096 --kt-enable-dynamic-expert-update
# --trust-remote-code runs code from the model repo: remove it for models that do not need it.
