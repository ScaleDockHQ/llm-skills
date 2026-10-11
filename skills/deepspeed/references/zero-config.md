# ZeRO configuration

> Verified against DeepSpeed v0.19.7, 2026-10-11

## Stages

ZeRO partitions training state across data-parallel ranks:

| Stage | Partitioned         | Notes                                                                       |
| ----- | ------------------- | --------------------------------------------------------------------------- |
| 0     | nothing             | disabled (default)                                                          |
| 1     | optimizer states    | least communication                                                         |
| 2     | + gradients         | HF docs: use this unless the model does not fit                             |
| 3     | + 16-bit parameters | gathers params during forward/backward; ZeRO-Infinity adds CPU/NVMe offload |

Every extra stage and offload level lowers peak memory and adds communication. Try 2 before 3, then offload.

## Batch size rule

`train_batch_size = train_micro_batch_size_per_gpu x gradient_accumulation_steps x number of GPUs`. Specify two of the three; DeepSpeed infers the third. With a Hugging Face trainer set all three to `"auto"`.

## Precision

`bf16: {"enabled": true}` needs hardware support (for example A100) and cannot be combined with `fp16` or `amp`. `fp16` takes loss-scale keys (`loss_scale`, `initial_scale_power`, ...). Newer bf16 options: `bf16_master_weights_and_grads` and `bf16_optimizer_states` (supported on stages 1-3; if optimizer states stay fp32 on those settings, ZeRO-Offload with `DeepSpeedCPUAdam` is required). Defaults for the new options are `false`.

## ZeRO keys (defaults from config-json)

| Key                                                                             | Default         | Meaning                                                          |
| ------------------------------------------------------------------------------- | --------------- | ---------------------------------------------------------------- |
| `stage`                                                                         | 0               | see above                                                        |
| `overlap_comm`                                                                  | false           | overlap gradient reduction with backward                         |
| `reduce_scatter`                                                                | true            | reduce-scatter instead of allreduce                              |
| `reduce_bucket_size`, `allgather_bucket_size`                                   | 5e8             | elements per collective; smaller uses less memory, slower        |
| `contiguous_gradients`                                                          | true            | avoids fragmentation                                             |
| `stage3_prefetch_bucket_size`                                                   | 5e8             | prefetch buffer                                                  |
| `stage3_param_persistence_threshold`                                            | 1e5             | do not partition parameters smaller than this                    |
| `stage3_max_live_parameters`                                                    | 1e9             | params resident per GPU before releasing                         |
| `stage3_max_reuse_distance`                                                     | 1e9             | keep params that will be reused soon                             |
| `stage3_gather_16bit_weights_on_model_save`                                     | false           | gather full 16-bit weights when saving with `save_16bit_model()` |
| `zero_hpz_partition_size`, `zero_quantized_weights`, `zero_quantized_gradients` | 1, false, false | ZeRO++ communication savers                                      |
| `round_robin_gradients`                                                         |                 | stage 1/2 CPU-offload gradient copying speed-up                  |

`cpu_offload` is deprecated; use `offload_optimizer`.

## Offload

```json
"offload_optimizer": { "device": "cpu", "pin_memory": true },
"offload_param":     { "device": "cpu", "pin_memory": true }
```

- `offload_optimizer`: CPU offload for stages 1-3; NVMe only for stage 3. Optimizer computation runs on CPU regardless of device. Other keys: `nvme_path` (default `/local_nvme`), `ratio` (default 1, the share updated on the CPU side), `buffer_count` (4), `fast_init`.
- `offload_param`: stage 3 only; `device` cpu or nvme; NVMe keys `nvme_path`, `buffer_count` (5), `buffer_size` (1e8), `max_in_cpu` (1e9).
- `pin_memory` now defaults to `true`. Pinned pages are non-swappable and count against `ulimit -l`; on low-memlock hosts set `false` if you see OOM.
- NVMe needs the `aio` section (Linux libaio): `block_size` 1048576, `queue_depth` 8, `thread_count` 1, `single_submit` false, `overlap_events` true. Check `ds_report` for the AIO op.
- With HF Trainer and optimizer offload, set `zero_force_ds_cpu_optimizer: false` to use DeepSpeed's CPU Adam.

Check the host: free RAM must hold the offloaded state across all ranks on the node (`free -h`). Offload slows steps; measure.

## Starting points

- `templates/ds_zero2.json`: stage 2, `overlap_comm`, 2e8 buckets, all `"auto"`.
- `templates/ds_zero3.json`: stage 3 with 16-bit gather on save, all `"auto"`.
- `templates/ds_zero3_offload.json`: stage 3 with CPU optimizer and parameter offload.

These follow the Transformers DeepSpeed guide. With ZeRO-3 and Hugging Face, create `TrainingArguments` before loading the model so parameters are sharded at load; otherwise the model sits on each GPU and nothing is saved.

## Other config areas

Activation checkpointing, flops profiler, monitoring (TensorBoard/W&B/CSV), communication logging, autotuning, tensor parallel (AutoTP), expert parallel, DeepCompile and sequence parallelism have their own sections in https://www.deepspeed.ai/docs/config-json/. Read the section for your version before enabling; several are recent or experimental.
