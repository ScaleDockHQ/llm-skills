# vLLM-Omni: performance and memory

> Verified against vLLM-Omni v0.30.0 (vLLM 0.30.0), 2026-10-11

Change one option at a time and compare one fixed prompt, seed and size. Support differs per model, so each option's guide lists validated models; an unsupported combination fails at engine start or is silently unvalidated.

## Offload (fit a model into less VRAM)

Three strategies, mutually exclusive; if several are set the priority is distributed layerwise, then layerwise, then model-level.

```bash
vllm serve Wan-AI/Wan2.2-T2V-A14B-Diffusers --omni --diffusion-offload-config '{"mode":"module","components":["dit","text_encoder"]}'
vllm serve Wan-AI/Wan2.2-T2V-A14B-Diffusers --omni --diffusion-offload-config '{"mode":"layer","components":["dit"]}'
```

- `module`: only the running component group sits on the GPU (DiT and encoders swap; VAE stays). Slower phase transitions.
- `layer`: streams one transformer block at a time with prefetch; suits compute-heavy video DiTs. `layer_options` such as `weight_transfer` and `resident_layers` are rejected in module mode.
- Distributed layerwise: multi-rank, bounded device buffer; validated for Cosmos3 only in the guide's table.
- Model support table (guide): Flux2, Qwen-Image, SDXL, Wan2.2 (module and layer); LongCat, NextStep, Ovis, SD3.5, BAGEL (layer only). Pinned host RAM is used, so check free RAM.

## Parallelism (speed, or models too big for one GPU)

| Flag                                                   | Meaning                                                                                                                                     |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `--tensor-parallel-size N`                             | shard weights across N GPUs (`Qwen/Qwen-Image` and Z-Image examples use 2; Z-Image TP=2 only)                                               |
| `--usp N`                                              | Ulysses sequence parallel for high-resolution or long video on 2-8 GPUs; `--ulysses-mode advanced_uaa` when head counts do not divide       |
| `--ring N`                                             | Ring attention                                                                                                                              |
| CFG parallel, pipeline parallel, HSDP, expert parallel | documented under `user_guide/diffusion/parallelism`; pick by model (CFG-parallel needs `true_cfg_scale > 1`, EP for MoE like HunyuanImage3) |

GPUs must be on one node with fast interconnect for SP and TP (`nccl-rdma-networking` covers multi-node).

## Cache acceleration (lossy, tunable)

`--cache-backend tea_cache` (`--cache-config '{"rel_l1_thresh": 0.2}'`) or `--cache-backend cache_dit` (`--cache-config '{"Fn_compute_blocks": 1, "residual_diff_threshold": 0.12}'`). Raising thresholds speeds up and degrades quality; check output visually.

## Quantization

`vllm serve MODEL --omni --quantization fp8` (also `int8`, `mxfp8`, `mxfp4`, `mxfp4_dualscale`). Online modes quantize at load time and quantize the transformer by default. Validated combinations (overview): FP8 for the Qwen-Image family and other DiTs (Wan2.2 not validated), Int8 for Qwen-Image and Z-Image, BitsAndBytes W4 for Z-Image-Turbo, ModelOpt FP8 checkpoints (Qwen-Image, Z-Image, FLUX.2, HunyuanImage-3.0), AutoRound W4A16 checkpoints (FLUX.1-dev). MXFP8 and MXFP4 are Ascend NPU only. FP8 on Ampere may use a weight-only path. Also exist: quantized KV (FP8, MXFP8, MXFP4 attention), GGUF, TorchAO, SVDQuant guides. Quality and speed vary: measure.

## LoRA

`--lora-path file.safetensors --lora-backend distill` preloads a (for example Lightning 4-step) LoRA at startup; the default backend is `peft`. Per request, video routes accept a JSON `lora` form field. Few-step LoRAs change the sensible `num_inference_steps`.

## Batching, steps and startup

`--max-num-seqs`, `--request-batch-max-wait-ms`, `--step-execution` and `--num-weight-load-threads` are in `serving-and-stages.md`. Other guides: attention backends, regional compilation, VAE fast path, frame interpolation, paged KV cache for HunyuanImage3.

## GPU memory per stage

`gpu_memory_utilization` (fraction of total GPU memory, per stage). Startup fails if free memory is below `total x fraction`, with a message showing the numbers. Typical diffusion stages need 0.1-0.3 when sharing a GPU with an AR stage; stages sharing a GPU must sum to under 1.0 (leave a buffer, 1.0 is discouraged). For diffusion models, smaller image sizes and fewer frames reduce activation memory.

## Sleep mode (share the GPU with other workloads)

Start with `--enable-sleep-mode`; then `POST /v1/omni/sleep` with `{"stage_ids":[0],"level":2}` releases GPU memory without stopping the server (level 1 offloads weights to host RAM, fast to restore; level 2 frees up to 95 percent or more and restores more slowly) and `POST /v1/omni/wakeup` restores it (see the sleep-mode guide for the wake body). System RAM must hold level-1 weights. Sleep mode is disabled with `--api-server-count > 1` and rejected with diffusion prefix caching. Treat these control routes as admin-only and do not expose them; confirm that `--api-key` covers them before relying on it.
