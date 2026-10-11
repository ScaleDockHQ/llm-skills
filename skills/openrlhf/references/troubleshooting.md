# Troubleshooting OpenRLHF

> Verified against OpenRLHF/OpenRLHF v0.11.2 (README.md, openrlhf/cli/train_ppo_ray.py assertions and warnings), 2026-10-11

| Symptom                                                                                                   | Cause and fix                                                                                                                                                    |
| --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DeepSpeed GPU device setup error under Ray                                                                | `export RAY_EXPERIMENTAL_NOSET_CUDA_VISIBLE_DEVICES=1` (README).                                                                                                 |
| `num_nodes and num_gpus_per_node must be the same when colocate actor and ref model.`                     | Colocation needs equal actor/ref node and GPU counts (or `--algo.kl.init_coef 0`). Same for critic/reward.                                                       |
| `actor_num_nodes * actor_num_gpus_per_node must be equal to vllm_num_engines * vllm_tensor_parallel_size` | With `--train.colocate_all` (sync), set engines x TP to the actor GPU count.                                                                                     |
| `<estimator> requires n_samples_per_prompt > 1`                                                           | rloo, reinforce_baseline, group_norm, dr_grpo need a group per prompt.                                                                                           |
| `Async RLHF is not supported with --vllm.enable_sleep.`                                                   | Remove `--vllm.enable_sleep` when using `--train.async_enable`.                                                                                                  |
| `--train.partial_rollout_enable requires --train.async_enable.`                                           | Add `--train.async_enable`.                                                                                                                                      |
| `remote_rm_url or agent_func_path must be specified when using dynamic filtering`                         | Provide `--reward.remote_url` or `--train.agent_func_path`; also `n_samples_per_prompt > 1`.                                                                     |
| `The number of sample batches must be greater than or equal to the effective number of actor processes.`  | Raise `--rollout.batch_size` or `--rollout.n_samples_per_prompt`, or lower `--rollout.micro_batch_size`.                                                         |
| `Only support --packing_samples with vLLM.`                                                               | Set `--vllm.num_engines` > 0 or drop packing.                                                                                                                    |
| `VLM training does not support critic model` / `--packing_samples`                                        | Use a critic-free estimator and no packing for VLMs.                                                                                                             |
| `[Warning] '{}' not in args.data.input_template`                                                          | The template is ignored; include `{}`; in bash use $'\\n' for newlines.                                                                                          |
| `--eval_dataset requires either --remote_rm_url or --agent_func_path`                                     | Add a reward file/URL or agent file for eval.                                                                                                                    |
| OOM                                                                                                       | See `references/scaling.md` memory section.                                                                                                                      |
| Flag not recognized after upgrade                                                                         | Flags moved to dotted groups in 0.1x; check `--help` and the matching `examples/scripts`. Older READMEs and blog posts use `--pretrain`, `--remote_rm_url`, etc. |
| Stale vLLM/DeepSpeed ABI errors                                                                           | Use the NGC container, remove preinstalled `xgboost transformer_engine flash_attn pynvml`, then install `openrlhf[vllm]`.                                        |

## Discovery

```bash
ray status; ray job list
ray job logs <submission-id> | tail -50
pip list 2>/dev/null | grep -Ei '^(openrlhf|vllm|deepspeed|ray|torch|transformers) '
```
