# Training with verl

> Verified against verl-project/verl v0.9.1 (docs/start/quickstart.rst, docs/algo/grpo.md, docs/examples/config.rst, docs/perf/perf_tuning.rst, docs/advance/ppo_lora.rst, examples/), 2026-10-11

## Entrypoints

- RL (PPO, GRPO and variants): `python3 -m verl.trainer.main_ppo <key=value ...>`. Config comes from `verl/trainer/config/ppo_trainer.yaml` (Megatron: `ppo_megatron_trainer.yaml`) plus command-line overrides. `+key=value` adds a key that is not in the config.
- SFT: `torchrun --standalone --nnodes=1 --nproc_per_node=<N> -m verl.trainer.sft_trainer data.train_files=... data.messages_key=messages model.path=... engine=fsdp trainer.default_local_dir=<dir>` (see `examples/sft/gsm8k/`; there are also Megatron and Automodel engines).
- Data is parquet. `examples/data_preprocess/gsm8k.py --local_save_dir ~/data/gsm8k` shows the schema (prompt, data_source, ground_truth for the reward).
- Example scripts per algorithm live in `examples/<algo>_trainer/` (grpo, ppo, rloo, reinforce_plus_plus, remax, gspo, gmpo, dppo, cispo, sapo, on_policy_distillation, ...). Copy the one nearest your model.

## Algorithms

`algorithm.adv_estimator`: `gae` (PPO, needs a critic), `grpo`, `reinforce_plus_plus`, `reinforce_plus_plus_baseline`, `rloo`, `rloo_vectorized`, `grpo_vectorized`. Further docs under `docs/algo/`: DAPO, GPG, DrGRPO (a GRPO variant), SPIN, SPPO, OPO, entropy, rollout correction, on-policy distillation.

GRPO (no critic) per docs:

- `algorithm.adv_estimator=grpo`, `actor_rollout_ref.rollout.n` > 1 (group size; default 1), `actor_rollout_ref.actor.use_kl_loss=True`, `kl_loss_coef` default 0.001, `kl_loss_type` one of kl, abs, mse, low_var_kl, full; `algorithm.use_kl_in_reward=False`.
- `loss_agg_mode` default `token-mean` (the paper's sample-level `seq-mean-token-mean` can be unstable in long-CoT). DrGRPO: `loss_agg_mode=seq-mean-token-sum-norm`, `use_kl_loss=False`, `algorithm.norm_adv_by_std_in_grpo=False`.
- Number of responses per step = `data.train_batch_size * rollout.n`.

## Key config groups

- `data.*`: `train_files`, `val_files`, `train_batch_size`, `max_prompt_length`, `max_response_length`, `filter_overlong_prompts`, `truncation`.
- `actor_rollout_ref.model.*`: `path`, `use_remove_padding`, `enable_gradient_checkpointing`, `enable_activation_offload` (FSDP only), `use_liger`.
- `actor_rollout_ref.actor.*`: `optim.lr`, `ppo_mini_batch_size`, `ppo_micro_batch_size_per_gpu`, `use_dynamic_bsz`, `ppo_max_token_len_per_gpu`, `clip_ratio` (0.2), `ppo_epochs`, `fsdp_config.param_offload` / `optimizer_offload`.
- `actor_rollout_ref.rollout.*`: `name` (vllm, sglang, trtllm), `tensor_model_parallel_size`, `gpu_memory_utilization` (default 0.5), `n`, `enforce_eager`, `free_cache_engine`, `calculate_log_probs`.
- `actor_rollout_ref.ref.*`: `log_prob_micro_batch_size_per_gpu`, `fsdp_config.param_offload`.
- `critic.*` (PPO only): `model.path`, `optim.lr`, `ppo_micro_batch_size_per_gpu`.
- `trainer.*`: `n_gpus_per_node`, `nnodes`, `logger` (`console`, or `'["console","wandb"]'`), `project_name`, `experiment_name`, `save_freq`, `test_freq`, `total_epochs`, `val_before_train`, `resume_mode` (`auto`, `disable`, `resume_path`), `default_local_dir`.

## Batch sizes

- Algorithmic sizes (`train_batch_size`, `ppo_mini_batch_size`) are global across workers. Performance sizes (`*_micro_batch_size_per_gpu`, `*_max_token_len_per_gpu`) are per GPU. Use the `_per_gpu` keys.
- Micro-batch settings should not change convergence; they only bound memory.
- Prefer `use_dynamic_bsz=True` with `ppo_max_token_len_per_gpu` at least 2 x (max_prompt_length + max_response_length); forward-only limits can be larger.
- Quickstart OOM relief under 32 GB: `ppo_micro_batch_size_per_gpu=1` for actor and critic.

## LoRA RL (FSDP/FSDP2)

`actor_rollout_ref.model.lora_rank=<8..64>`, `lora_alpha`, `target_modules=all-linear`; optional `lora_adapter_path`, `lora.merge` (merge adapters before syncing to the rollout engine). For 70B+ or < 48 GB: `actor_rollout_ref.rollout.layered_summon=True`. Megatron LoRA has its own `lora` key; FSDP options are ignored there. Checkpoint only adapters with `checkpoint.save_lora_only=True`.

## Logging and tracking

`trainer.logger='["console","wandb"]'` with `WANDB_API_KEY` in the environment. `ray_init.timeline_json_file=/tmp/ray_timeline.json` writes a Ray timeline at the end. `+trainer.wandb_proxy=<url>` sets a proxy for wandb only. Key metric: `val/test_score/<data_source>` every `trainer.test_freq` steps.

## Discovery

```bash
python3 -m verl.trainer.main_ppo --help 2>&1 | head -30
sed -n 1,80p verl/trainer/config/ppo_trainer.yaml
ls examples/*_trainer/ | head -50
```
