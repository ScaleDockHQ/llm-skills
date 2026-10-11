#!/usr/bin/env bash
# Small GRPO smoke run on GSM8K. Run from a verl checkout; adapted from the
# quickstart flags in docs/start/quickstart.rst (v0.9.1). Values are starting
# points: lower batch sizes or raise offload if you hit OOM.
set -xeuo pipefail

MODEL_PATH=${MODEL_PATH:-Qwen/Qwen2.5-0.5B-Instruct}
DATA_DIR=${DATA_DIR:-$HOME/data/gsm8k}
# Prepare data once: python3 examples/data_preprocess/gsm8k.py --local_save_dir "$DATA_DIR"

UV_RUN="uv run --frozen --all-packages --extra vllm --extra fsdp"

$UV_RUN python3 -m verl.trainer.main_ppo \
  algorithm.adv_estimator=grpo \
  data.train_files="$DATA_DIR/train.parquet" \
  data.val_files="$DATA_DIR/test.parquet" \
  data.train_batch_size=64 \
  data.max_prompt_length=512 \
  data.max_response_length=512 \
  actor_rollout_ref.model.path="$MODEL_PATH" \
  actor_rollout_ref.actor.optim.lr=1e-6 \
  actor_rollout_ref.actor.ppo_mini_batch_size=32 \
  actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=4 \
  actor_rollout_ref.actor.use_kl_loss=True \
  actor_rollout_ref.actor.kl_loss_coef=0.001 \
  actor_rollout_ref.actor.kl_loss_type=low_var_kl \
  actor_rollout_ref.rollout.name=vllm \
  actor_rollout_ref.rollout.n=4 \
  actor_rollout_ref.rollout.tensor_model_parallel_size=1 \
  actor_rollout_ref.rollout.gpu_memory_utilization=0.4 \
  actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=8 \
  actor_rollout_ref.ref.log_prob_micro_batch_size_per_gpu=4 \
  algorithm.use_kl_in_reward=False \
  trainer.logger=console \
  trainer.val_before_train=False \
  trainer.n_gpus_per_node=1 \
  trainer.nnodes=1 \
  trainer.save_freq=20 \
  trainer.test_freq=10 \
  trainer.total_epochs=1 \
  ray_kwargs.ray_init.runtime_env.py_executable="$UV_RUN" \
  "$@" 2>&1 | tee verl_grpo_smoke.log
