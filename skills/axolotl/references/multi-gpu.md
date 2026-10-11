# Multi-GPU and cloud launches with Axolotl

> Verified against axolotl-ai-cloud/axolotl v0.20.0 (docs/multi-gpu.qmd, docs/cli.qmd, docs/faq.qmd on main), 2026-10-11

Three parallelism strategies are mutually exclusive: DeepSpeed (ZeRO 1-3), FSDP (FSDP2 only, recommended) and DDP (default when neither is set). Context parallelism and FSDP + QLoRA layer on top.

## Launching

```bash
axolotl train cfg.yml --launcher torchrun -- --nproc_per_node=2 --nnodes=1
axolotl train cfg.yml --launcher accelerate -- --config_file=accelerate_config.yml --num_processes=4
axolotl train cfg.yml --launcher python      # single process, no accelerate
```

Arguments after `--` go to the launcher. Remove `deepspeed:` from the config for a single GPU (a leftover `deepspeed:` gives `ModuleNotFoundError: No module named 'mpi4py'`).

## FSDP2

```yaml
fsdp_version: 2
fsdp_config:
  offload_params: false
  cpu_ram_efficient_loading: true
  auto_wrap_policy: TRANSFORMER_BASED_WRAP
  transformer_layer_cls_to_wrap: Qwen3DecoderLayer # model-specific decoder layer class
  state_dict_type: FULL_STATE_DICT
  reshard_after_forward: true
```

- FSDP1 is removed: `fsdp_version: 1` and the top-level `fsdp:` list raise errors; `fsdp_version` defaults to 2.
- Migration from FSDP1 names: `fsdp_sharding_strategy` -> `reshard_after_forward`; `fsdp_cpu_ram_efficient_loading` -> `cpu_ram_efficient_loading`; `fsdp_state_dict_type` -> `state_dict_type`; `fsdp_activation_checkpointing` -> `activation_checkpointing`; `fsdp_use_orig_params`, `fsdp_sync_module_states`, `fsdp_limit_all_gathers`, backward prefetch keys are dropped with a warning; `fsdp_forward_prefetch` is rejected.
- With `SIZE_BASED_WRAP` also set `min_num_params`.
- Find `transformer_layer_cls_to_wrap`: look at `_no_split_modules` in the model's `modeling_<name>.py` in transformers (for `LlamaForCausalLM` it is `LlamaDecoderLayer`).
- `FULL_STATE_DICT` assembles the whole checkpoint on rank 0's CPU, so rank 0 needs enough host RAM. LoRA/QLoRA checkpoints store adapter tensors only.
- FSDP + QLoRA has its own guide: https://docs.axolotl.ai/docs/fsdp_qlora.html.
- Combine sharded checkpoints afterwards with `axolotl merge-sharded-fsdp-weights cfg.yml`.

## DeepSpeed

```bash
axolotl fetch deepspeed_configs
axolotl train cfg.yml --deepspeed deepspeed_configs/zero1.json
```

Shipped configs: `zero1.json`, `zero1_torch_compile.json`, `zero2.json`, `zero3.json`, `zero3_bf16.json`, `zero3_bf16_cpuoffload_params.json`, `zero3_bf16_cpuoffload_all.json`. Start at ZeRO 1, move to 2 then 3 only if needed; choose the config that offloads the least.

## Context parallelism

`context_parallel_size` splits long sequences across GPUs (axolotl-ringmaster under FSDP2: Ulysses head-parallel attention with Ring attention for the remainder; DeepSpeed Ulysses under DeepSpeed). Guide: https://docs.axolotl.ai/docs/sequence_parallelism.html.

## Memory and stability

OOM: lower `micro_batch_size` and `eval_batch_size`, adjust `gradient_accumulation_steps`, use a higher ZeRO stage. Instability: start with ZeRO-2, watch the loss, check the learning rate. Hangs for minutes with no progress: usually NCCL (https://docs.axolotl.ai/docs/nccl.html). More: `references/troubleshooting.md`.

## Remote launchers

`axolotl train cfg.yml --cloud cloud.yaml` runs on Modal, Baseten or Nebius (`provider:` in the cloud YAML; `pip install 'axolotl[modal]'` or `'axolotl[baseten]'`). Baseten and Nebius Serverless Jobs support training only. Example Modal keys: `gpu` (`l40s`, `a100-40gb`, `a100-80gb`, `a10g`, `h100`, `t4`, `l4`), `gpu_count`, `timeout`, `volumes`, `secrets`. Renting GPUs in general: skill `cloud-llms`.
