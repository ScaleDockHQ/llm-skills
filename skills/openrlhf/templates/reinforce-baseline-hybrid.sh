#!/usr/bin/env bash
# REINFORCE++-baseline RLVR on a hybrid engine (actor, ref and vLLM share GPUs).
# Adapted from examples/scripts/train_reinforce_baseline_hybrid_engine.sh
# (OpenRLHF v0.11.2). Start Ray first: ray start --head --node-ip-address 127.0.0.1 --num-gpus 4
# Sizes are starting points for a smoke run; raise them after one clean step.
set -euo pipefail

MODEL_PATH=${MODEL_PATH:-Qwen/Qwen3-4B-Thinking-2507}
DATASET_PATH=${DATASET_PATH:-zhuzilin/dapo-math-17k}
SAVE_PATH=${SAVE_PATH:-$PWD/exp/run1}
REWARD_FILE=${REWARD_FILE:-$PWD/reward_func.py}     # see references/rewards-and-agents.md
NGPUS=${NGPUS:-4}

ray job submit --address="http://127.0.0.1:8265" \
  --runtime-env-json="{\"working_dir\": \"$PWD\"}" \
  -- python3 -m openrlhf.cli.train_ppo_ray \
  --actor.model_name_or_path "$MODEL_PATH" \
  --ckpt.output_dir "$SAVE_PATH" \
  --ckpt.path "$SAVE_PATH/ckpt" \
  --ckpt.save_hf --ckpt.max_num 3 --ckpt.save_steps 10 --ckpt.load_enable \
  --reward.remote_url "$REWARD_FILE" \
  --data.prompt_dataset "$DATASET_PATH" \
  --data.input_key prompt --data.label_key label \
  --data.apply_chat_template \
  --data.max_len 8192 --rollout.max_new_tokens 4096 \
  --data.max_samples 2000 \
  --rollout.batch_size 32 --rollout.n_samples_per_prompt 4 \
  --train.batch_size 128 --train.micro_batch_size 1 --rollout.micro_batch_size 8 \
  --train.max_epochs 1 --train.num_episodes 1 \
  --train.dynamic_batch_enable --train.max_tokens_per_gpu 16192 --rollout.max_tokens_per_gpu 32768 \
  --ref.num_nodes 1 --ref.num_gpus_per_node "$NGPUS" \
  --actor.num_nodes 1 --actor.num_gpus_per_node "$NGPUS" \
  --vllm.num_engines 2 --vllm.tensor_parallel_size $((NGPUS / 2)) \
  --vllm.gpu_memory_utilization 0.7 --vllm.sync_backend nccl --vllm.enforce_eager \
  --train.colocate_all --ds.enable_sleep --vllm.enable_sleep \
  --ds.zero_stage 3 --ds.param_dtype bf16 --ds.packing_samples \
  --actor.gradient_checkpointing_enable \
  --algo.advantage.estimator reinforce_baseline \
  --actor.adam.lr 5e-7 --actor.entropy_coef 0.0 \
  --algo.kl.init_coef 1e-5 --algo.kl.use_loss --algo.kl.estimator k2 \
  --logger.tensorboard_dir "$SAVE_PATH/runs" --logger.logging_steps 1 --eval.steps -1
