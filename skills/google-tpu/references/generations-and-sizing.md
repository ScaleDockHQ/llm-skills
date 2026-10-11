# TPU generations, slices and sizing

> Verified against Google Cloud TPU docs (TPU architecture, TPU v5e, TPU v6e, TPU7x), vLLM TPU docs (Cloud TPU Setup), 2026-10-11

## Which generations to use for serving

vLLM TPU's setup guide marks **TPU7x (Ironwood)**, **v6e (Trillium)** and **v5e** as recommended, and v5p, v4 and v3 as experimental. Re-read it before choosing: https://docs.vllm.ai/projects/tpu/en/latest/getting_started/tpu_setup/

| Generation     | HBM per chip | HBM bandwidth per chip | Peak BF16 per chip | Chips per host | Single-host serving shape                       |
| -------------- | ------------ | ---------------------- | ------------------ | -------------- | ----------------------------------------------- |
| v5e            | 16 GB        | see the v5e page       | see the v5e page   | up to 8        | `v5litepod-8` (machine type `ct5lp-hightpu-8t`) |
| v6e (Trillium) | 32 GB        | 1638 GBps              | 918 TFLOPs         | 8              | `v6e-8`, topology `2x4`, `ct6e-standard-8t`     |
| TPU7x          | 192 GiB      | 7380 GBps              | 2307 TFLOPs        | 4 per VM       | `2x2x1`, 4 chips, `tpu7x-standard-4t`           |

Notes from the docs:

- v6e chips have one TensorCore; each v6e VM has 1, 4 or 8 chips. Slices of 4 chips or fewer are sub-host. The 8-chip VM (`v6e-8`, one VM) is the shape Google optimizes for inference, with all chips in one serving workload. Use a 4-chip VM type (`ct6e-standard-4t`) for multi-host slices.
- A `2x4` v6e slice on two 4-chip VMs is supported only through the GKE API.
- TPU7x chips have two TensorCores and four SparseCores each; every TPU7x topology uses `tpu7x-standard-4t` and slices larger than 64 chips are built from 4x4x4 cubes.
- Topologies: 2D (`AxB`) for v5e and v6e, 3D (`AxBxC`) for v4, v5p and TPU7x.
- Do not infer other numbers from memory. v5e bandwidth and compute are on https://cloud.google.com/tpu/docs/v5e.

## Common topologies

| Generation | Topology | Chips | Hosts | Scope                            |
| ---------- | -------- | ----- | ----- | -------------------------------- |
| v6e        | `1x1`    | 1     | 1/8   | Sub-host, testing                |
| v6e        | `2x2`    | 4     | 1/2   | Sub-host                         |
| v6e        | `2x4`    | 8     | 1     | Single host (`ct6e-standard-8t`) |
| v6e        | `4x4`    | 16    | 2     | Multi-host                       |
| v6e        | `8x8`    | 64    | 8     | Multi-host                       |
| TPU7x      | `2x2x1`  | 4     | 1     | Single host                      |
| TPU7x      | `2x2x2`  | 8     | 2     | Multi-host                       |
| TPU7x      | `2x4x4`  | 32    | 8     | Multi-host                       |

## HBM budget

Tensor parallelism shards weights and KV cache across chips, so the budget is per slice:

```text
weights (checkpoint bytes at the served dtype)
+ KV cache = 2 x layers x kv_heads x head_dim x bytes_per_element x context_tokens x concurrent_seqs
+ activations and compiler scratch (measure; leave a clear margin)
<= HBM per chip x chips in the slice
```

Worked pattern (use the model's own config, not these numbers): a 70B-class BF16 checkpoint is roughly 140 GB, which needs more than a 4-chip v6e (4 x 32 GB) and fits a `v6e-8` (8 x 32 GB = 256 GB) with room for KV cache. An 8B BF16 model (about 16 GB) fits a single v6e chip with a short context.

Check the quantization formats the backend accelerates per generation in the vLLM TPU feature matrix; the table there lists, for example, AWQ INT4 for v5 and v6 and FP8 and MXFP4 for v7: https://docs.vllm.ai/projects/tpu/en/latest/features/. Quantization recipes live in `model-quantization`.

## TPU or GPU

TPUs run JAX or PyTorch (via torchax) models through XLA. vLLM TPU keeps the vLLM interface, but only the models in its matrix are tested. If the model is not listed, expect to debug, or pick GPUs (`choosing-hardware`, `cloud-llms`).
