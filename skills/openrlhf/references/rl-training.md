# RL training with OpenRLHF (train_ppo_ray)

> Verified against OpenRLHF/OpenRLHF v0.11.2 (README.md, openrlhf/cli/train_ppo_ray.py, examples/scripts/), 2026-10-11

All RL runs go through `python3 -m openrlhf.cli.train_ppo_ray` submitted to a Ray cluster. Execution is token-in-token-out through an agent executor: single-turn (default) or multi-turn (`--train.agent_func_path`).

## Start Ray and submit

```bash
ray start --head --node-ip-address 0.0.0.0 --num-gpus 8     # use 127.0.0.1 on a single host you do not share
ray start --address <head-ip>:6379 --num-gpus 8             # on each extra node
ray job submit --address="http://127.0.0.1:8265" \
  --runtime-env-json='{"working_dir": "/openrlhf"}' \
  -- python3 -m openrlhf.cli.train_ppo_ray <flags>
```

`templates/reinforce-baseline-hybrid.sh` is a complete 4-GPU example. If DeepSpeed fails to set up GPU devices, `export RAY_EXPERIMENTAL_NOSET_CUDA_VISIBLE_DEVICES=1` (README).

## Algorithms: `--algo.advantage.estimator`

| Value                | Algorithm                                                                  |
| -------------------- | -------------------------------------------------------------------------- |
| (default)            | PPO with critic (`--critic.*` flags, `--critic.adam.lr`)                   |
| `reinforce`          | REINFORCE++                                                                |
| `reinforce_baseline` | REINFORCE++-baseline (README: best for RLVR, robust to reward scale)       |
| `rloo`               | RLOO                                                                       |
| `group_norm`         | GRPO                                                                       |
| `dr_grpo`            | Dr. GRPO (no local /std)                                                   |
| `flash_reinforce`    | FlashREINFORCE, single rollout (`--rollout.n_samples_per_prompt 1`, async) |

The CLI asserts `--rollout.n_samples_per_prompt > 1` for `rloo`, `reinforce_baseline`, `group_norm` and `dr_grpo` (advantages would collapse to 0). Critic-free estimators need no critic model.

Other knobs: `--algo.kl.init_coef` (0 disables the reference model), `--algo.kl.use_loss` with `--algo.kl.estimator k2|k3`, `--actor.policy_loss_type gspo`, `--actor.loss_agg_mode seq-mean-token-mean`, vLLM importance-sampling correction `--algo.advantage.is_correction_level token|seq`, `--algo.advantage.is_correction_mode mask|clip`, `--algo.advantage.is_correction_threshold`, `--reward.overlong_buffer_len` / `--reward.overlong_penalty_factor` (DAPO overlong penalty), `--reward.stop_properly_penalty_coef`, Muon optimizer (`--actor.optim muon`, set `--actor.max_norm 0`).

## Model and GPU flags

- Models: `--actor.model_name_or_path`, `--reward.model_name_or_path` (optional), `--critic.model_name_or_path` (PPO), `--ref.*` and per-role `--<role>.num_nodes` / `--<role>.num_gpus_per_node`.
- vLLM: `--vllm.num_engines`, `--vllm.tensor_parallel_size`, `--vllm.gpu_memory_utilization`, `--vllm.sync_backend nccl`, `--vllm.enforce_eager`, `--vllm.enable_sleep`, `--vllm.enable_prefix_caching`.
- DeepSpeed: `--ds.zero_stage`, `--ds.param_dtype bf16`, `--ds.packing_samples`, `--ds.adam_offload`, `--ds.enable_sleep`, `--ds.ring_attn_size`, `--ds.tensor_parallel_size` (AutoTP), `--ds.deepcompile`, `--ds.attn_implementation flash_attention_2`, LoRA `--ds.lora.rank`.
- Batches: `--rollout.batch_size` (prompts per rollout), `--rollout.n_samples_per_prompt`, `--train.batch_size`, `--train.micro_batch_size`, `--rollout.micro_batch_size`, `--train.dynamic_batch_enable` with `--train.max_tokens_per_gpu` and `--rollout.max_tokens_per_gpu`, `--data.max_len`, `--rollout.max_new_tokens` (older docs: `--prompt_max_len`, `--generate_max_len`).
- Data: `--data.prompt_dataset`, `--data.input_key`, `--data.label_key`, `--data.apply_chat_template`, `--data.max_samples`. VLM: `--data.image_key`, `--data.max_images_per_prompt` (no critic, no packing).

## Checkpoints, resume, logging

- `--ckpt.output_dir` (final model), `--ckpt.path` (training checkpoints), `--ckpt.save_steps`, `--ckpt.save_hf`, `--ckpt.max_num`, `--ckpt.max_mem`, `--ckpt.load_enable` (resume from `--ckpt.path`), `--ckpt.best_metric_key`.
- Logging: `--logger.tensorboard_dir`, `--logger.logging_steps`, wandb via `--logger.wandb.key` (prefer `wandb login` over a literal key). Timing metrics: `timing/make_experience`, `timing/ppo_train`, `timing/broadcast`, `timing/generation`, `timing/step_total`.
- Evaluation: `--eval.dataset`, `--eval.steps`, `--eval.temperature`, `--eval.n_samples_per_prompt`; `--eval.dataset` needs `--reward.remote_url` or `--train.agent_func_path`.

## LoRA merge

LoRA/QLoRA runs save only adapters. Merge:

```bash
python -m openrlhf.cli.lora_combiner \
  --model_path meta-llama/Meta-Llama-3-8B --lora_path ./checkpoint/llama3-8b-rm \
  --output_path ./checkpoint/llama-3-8b-rm-combined [--is_rm] --ds.param_dtype bf16
```

Then serve the merged directory with `vllm serve` (skill `vllm`).

## Discovery

```bash
python3 -m openrlhf.cli.train_ppo_ray --help | grep -E '^\s+--' | head -80
ls examples/scripts/
```
