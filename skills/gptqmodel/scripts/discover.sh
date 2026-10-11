#!/usr/bin/env bash
# Read-only environment report for GPT-QModel work. Needs bash 3.2+; prints no secrets.
#   MODEL_DIR=<dir>  optional: a local model directory to inspect
set -uo pipefail

echo "== python"; python3 --version 2>&1
for m in torch transformers gptqmodel vllm sglang datasets evalution; do
  python3 -c "import $m;print('$m', getattr($m, '__version__', '?'))" 2>/dev/null || echo "$m missing"
done
python3 -c "import torch;print('cuda', torch.version.cuda, 'available', torch.cuda.is_available())" 2>/dev/null || true
echo "== gpus"
nvidia-smi --query-gpu=index,name,compute_cap,memory.total,memory.used --format=csv 2>/dev/null || echo "no nvidia-smi"
echo "== disk and memory"
df -h "${MODEL_DIR:-.}" | tail -1
free -g 2>/dev/null | sed -n 2p || true
echo "== env (names only)"
env | grep -E '^GPTQMODEL_' | cut -d= -f1 || true
echo "== kernel cache"
ls "${GPTQMODEL_CACHE_DIR:-$HOME/.cache/gptqmodel}" 2>/dev/null | head || echo "none"
if [ -n "${MODEL_DIR:-}" ] && [ -f "$MODEL_DIR/config.json" ]; then
  echo "== model"
  jq '{architectures, model_type, torch_dtype, dtype, quantization_config}' "$MODEL_DIR/config.json"
fi
