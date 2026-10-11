#!/usr/bin/env bash
# NeMo RL GRPO smoke test inside a clone of NVIDIA-NeMo/RL (checked against v0.7.0 README).
# Prereq: git clone --recursive https://github.com/NVIDIA-NeMo/RL.git nemo-rl && cd nemo-rl && uv venv
# Needs HF_TOKEN in the environment only for gated models; never write it into this file.
set -euo pipefail

export HF_HOME=${HF_HOME:-$HOME/.cache/huggingface}

# 10-step GSM8K run from examples/configs/grpo_smoke.yaml; DTensor backend, vLLM generation.
uv run examples/run_grpo.py \
  --config examples/configs/grpo_smoke.yaml \
  cluster.gpus_per_node="${GPUS:-1}" \
  checkpointing.checkpoint_dir="${OUT:-results/grpo_smoke}" \
  "$@"

# Next steps (uncomment and adapt):
#  - real run:      uv run examples/run_grpo.py cluster.gpus_per_node=8 policy.model_name=<hf-id> logger.wandb_enabled=True
#  - Megatron:      uv run examples/run_grpo.py --config examples/configs/grpo_math_1B_megatron.yaml
#  - DCP -> HF:     uv run python examples/converters/convert_dcp_to_hf.py \
#                     --config results/grpo/step_N/config.yaml \
#                     --dcp-ckpt-path results/grpo/step_N/policy/weights/ --hf-ckpt-path results/grpo/hf
