# Multi-GPU, multi-node and DeepSpeed in LLaMA-Factory

> Verified against LLaMA-Factory v0.9.5, 2026-10-11

## How the launcher decides

In `launcher.py`, `llamafactory-cli train` starts `torchrun` when `FORCE_TORCHRUN` is enabled, or when more than one device is visible and neither Ray nor KTransformers is in use. Variables it reads:

| Variable                                              | Default              | Meaning                                                                                         |
| ----------------------------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------- |
| `NNODES`                                              | `1`                  | number of nodes                                                                                 |
| `NODE_RANK`                                           | `0`                  | rank of this node                                                                               |
| `NPROC_PER_NODE`                                      | visible device count | processes per node                                                                              |
| `MASTER_ADDR`                                         | `127.0.0.1`          | rendezvous host                                                                                 |
| `MASTER_PORT`                                         | a free port          | rendezvous port                                                                                 |
| `MAX_RESTARTS`, `RDZV_ID`, `MIN_NNODES`, `MAX_NNODES` | unset                | elastic, fault-tolerant jobs                                                                    |
| `OPTIM_TORCH`                                         | on                   | sets `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` and `TORCH_NCCL_AVOID_RECORD_STREAMS=1` |

Select GPUs with `CUDA_VISIBLE_DEVICES`.

## Single node

```bash
CUDA_VISIBLE_DEVICES=0,1,2,3 llamafactory-cli train mytrain.yaml
```

## Multi-node (run the matching line on each node)

```bash
FORCE_TORCHRUN=1 NNODES=2 NODE_RANK=0 MASTER_ADDR=<node0-ip> MASTER_PORT=29500 llamafactory-cli train mytrain.yaml
FORCE_TORCHRUN=1 NNODES=2 NODE_RANK=1 MASTER_ADDR=<node0-ip> MASTER_PORT=29500 llamafactory-cli train mytrain.yaml
```

Elastic variant (from `examples/README.md`): `FORCE_TORCHRUN=1 MIN_NNODES=1 MAX_NNODES=3 MAX_RESTARTS=3 RDZV_ID=<job-id> MASTER_ADDR=<ip> MASTER_PORT=29500 llamafactory-cli train ...`. Keep the same YAML, code and package versions on all nodes. Open the rendezvous port only on the cluster network.

## DeepSpeed

Add one key to the YAML (example `examples/train_lora/qwen3_lora_sft_ds3.yaml`):

```yaml
deepspeed: examples/deepspeed/ds_z3_config.json # ds_z0_config.json, ds_z2_config.json, ds_z3_config.json
```

and launch with `FORCE_TORCHRUN=1`. Install the extra first: `pip install -r requirements/deepspeed.txt` (pins `deepspeed<=0.18.4`). The bundled ZeRO-3 file uses `"auto"` for batch sizes, clipping and bf16/fp16, `stage: 3`, `overlap_comm: false`, `stage3_gather_16bit_weights_on_model_save: true`. Prefer `auto` so the YAML stays the single source of truth; hand-set values that disagree with the YAML can silently train with the wrong values.

Upstream `examples/deepspeed/` ships `ds_z0_config.json`, `ds_z2_config.json`, `ds_z2_offload_config.json`, `ds_z2_autotp_config.json`, `ds_z3_config.json`, `ds_z3_offload_config.json` and `ds_z3_fp8_config.json`. For config semantics, stage trade-offs, offload and checkpoint conversion, use the `deepspeed` skill.

When a ZeRO-3 run saves, the gather option above is what lets the final model be written as full 16-bit weights.

## Ray

`USE_RAY=1 llamafactory-cli train examples/train_lora/qwen3_lora_sft_ray.yaml` runs the example on 4 GPUs through Ray instead of torchrun. Ray cluster setup is outside this skill.

## FSDP

`examples/extras/fsdp_qlora/train.sh` shows FSDP+QLoRA with Accelerate; read the script in your checkout for the exact launcher and config, as it is not a `llamafactory-cli` path.

## Verify

- Log shows `Initializing N distributed tasks at: addr:port`.
- `nvidia-smi` shows all selected GPUs busy.
- Effective batch = `per_device_train_batch_size x gradient_accumulation_steps x world_size`; adjust learning rate if you changed world size.
