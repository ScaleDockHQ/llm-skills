# Scaling OpenRLHF: placement, async, Slurm, tuning

> Verified against OpenRLHF/OpenRLHF v0.11.2 (README.md performance section, openrlhf/cli/train_ppo_ray.py, examples/scripts/train_ppo_ray_slurm.sh), 2026-10-11

## Placement modes

| Mode                         | Flags                                                          | Notes                                                                                                                                                                                                                                                                                                                      |
| ---------------------------- | -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hybrid engine (colocate all) | `--train.colocate_all --vllm.enable_sleep --ds.enable_sleep`   | Most stable, strictly on-policy, serial generate then train. Constraint (asserted): `actor.num_nodes*actor.num_gpus_per_node == vllm.num_engines*vllm.tensor_parallel_size`; actor and ref must have equal node and GPU counts when KL init coef > 0. Without `--train.colocate_all`, `--vllm.enable_sleep` is turned off. |
| Partial colocation           | `--train.colocate_actor_ref`, `--train.colocate_critic_reward` | Share GPUs between those pairs (needs equal node/GPU counts per pair).                                                                                                                                                                                                                                                     |
| Separate roles               | no colocate flags                                              | Most GPUs, least memory pressure.                                                                                                                                                                                                                                                                                          |
| Async                        | `--train.async_enable --train.async_queue_size N`              | Highest throughput; larger N is more off-policy. Incompatible with `--vllm.enable_sleep`. With `--train.colocate_all` only DeepSpeed models are colocated.                                                                                                                                                                 |
| Async + partial rollout      | `--train.async_enable --train.partial_rollout_enable`          | vLLM pause/resume for weight sync; in-flight samples can mix old and new weights. Pair with `--algo.advantage.is_correction_level token`.                                                                                                                                                                                  |

Also asserted: `--rollout.n_samples_per_prompt * --rollout.batch_size / --rollout.micro_batch_size` must be at least the effective actor process count (actor GPUs / ring_attn_size / tensor_parallel_size).

## Speed

Sample packing (`--ds.packing_samples`, needs vLLM and flash attention), `--train.dynamic_batch_enable`, `--ds.deepcompile`, `--ds.overlap_comm` (if memory allows), vLLM prefix caching when `n_samples_per_prompt > 1`, `--vllm.sync_backend nccl`, oversampling with `--rollout.vllm_generate_batch_size` greater than `--rollout.batch_size` (async only). Generation: maximize `--rollout.micro_batch_size` and use the smallest vLLM TP that fits. Training: maximize `--train.micro_batch_size`. README starting point for 8x A100 80GB: hybrid engine, `--vllm.gpu_memory_utilization 0.5`, `--train.colocate_all`.

## Memory

Plenty of memory: no `--ds.adam_offload`, `--ds.overlap_comm`, colocate critic/reward and actor/ref. OOM: drop all colocate flags, reduce batch sizes, enable `--actor.gradient_checkpointing_enable`, ZeRO-3, `--ds.adam_offload`, lower `--vllm.gpu_memory_utilization`. Long context: `--ds.ring_attn_size` (needs `--ds.packing_samples`, `ring_flash_attn`) or AutoTP `--ds.tensor_parallel_size`.

## Multi-node and Slurm

Start Ray head and workers (`references/rl-training.md`) and submit with `ray job submit`. `examples/scripts/train_ppo_ray_slurm.sh` launches the Ray head and workers with `srun` containers (`nvcr.io/nvidia/pytorch:26.03-py3`), waits, then submits the job; fill in partition, account, paths and the Ray version it installs. SFT/RM/DPO on Slurm: `train_nonrl_slurm.sh`. Firewall the Ray dashboard and GCS ports to the cluster network.

## Discovery

```bash
ray status
nvidia-smi topo -m
python3 -m openrlhf.cli.train_ppo_ray --help | grep -E 'colocate|num_engines|enable_sleep'
```
