# Hardware and Memory Planning for Fine-Tuning

> Verified against Axolotl v0.20.0 docs/choosing_method.qmd (hardware mapping), Unsloth DGX Spark guide, systemd.resource-control(5) / systemd-run(1), huggingface_hub v2.2.0 environment variables, and xet-core v1.7.0 (config, system_memory.rs), 2026-10-11

## Rules of thumb for memory

Assumptions: dense decoder model with P billion parameters, AdamW, bf16 compute, short context (512-2048 tokens), micro-batch 1-2, gradient checkpointing on. Long context and larger batches add activation memory on top; MoE models need memory for *all* experts' weights.

| Method | Weights | Gradients + optimizer | Rough total |
|---|---|---|---|
| Full FT (bf16 + AdamW) | 2 bytes x P | ~2 bytes grads + 8-12 bytes optimizer states x P | ~12-16 bytes x P (8B model: ~100 GB+, needs multi-GPU or offload) |
| LoRA (bf16 base) | 2 bytes x P | tiny (adapter only) | ~2 bytes x P + a few GB |
| QLoRA (4-bit base) | ~0.5-0.6 bytes x P | tiny | ~0.6 bytes x P + a few GB |

Axolotl's own approximate table (same short-context assumptions):

| Model size | QLoRA (4-bit) | LoRA (bf16) | Full (bf16 + AdamW) |
|---|---|---|---|
| 1-3B | 6-8 GB | 8-12 GB | 24-32 GB |
| 7-8B | 10-14 GB | 16-24 GB | 60-80 GB |
| 13-14B | 16-20 GB | 28-40 GB | 120+ GB |
| 30-34B | 24-32 GB | 64-80 GB | 2-4x 80 GB |
| 70-72B | 40-48 GB | 2x 80 GB | 4-8x 80 GB |

GRPO additionally needs memory for a vLLM generation engine (Axolotl recommends separate GPU(s); single GPU uses `vllm_mode: colocate` with sleep mode, practical only for small models).

Levers when you don't fit, in order: shorter `sequence_len` -> micro-batch 1 + more accumulation -> gradient checkpointing (or offload) -> 8-bit optimizer -> QLoRA -> smaller model -> more GPUs / cloud.

## DGX Spark (GB10, unified memory)

- CPU and GPU share one LPDDR5x pool (128 GB on DGX Spark per Unsloth's guide). `nvidia-smi` may not report a separate dedicated VRAM figure; watch `free -h` and per-process RSS too.
- Big headroom for QLoRA/LoRA on large models (Unsloth reports gpt-oss-120b QLoRA at roughly 68 GB unified memory), but bandwidth is lower than datacenter HBM, so steps are slower than on an H100-class GPU.
- **Everything competes for the same memory:** a model server (vLLM, llama.cpp) on the same box, dataset tokenization workers, merges, GGUF conversion, Docker builds, and HF downloads. Stop serving before training, or budget explicitly (vLLM `--gpu-memory-utilization`, smaller context).
- arm64: use vendor arm64 containers (NVIDIA PyTorch NGC base, Unsloth's DGX Spark Dockerfile, multi-arch `axolotlai/axolotl` / `unsloth/unsloth` images). Many pip extras (flash-attn, deepspeed, bitsandbytes) may lack aarch64 wheels and compile from source (slow, memory-hungry).

## Consumer GPUs

- 8-12 GB: QLoRA on ~1-8B models with short context.
- 16-24 GB: QLoRA up to ~14B-30B (short context), LoRA bf16 on ~7-8B.
- 2+ GPUs: Axolotl with FSDP/DeepSpeed (`axolotl fetch deepspeed_configs`); Unsloth targets single GPU.
- Ampere or newer for bf16 and Flash Attention; older cards fall back to fp16 and `sdpa`.
- Apple Silicon: CUDA-based stacks here (Axolotl, Unsloth, bitsandbytes) are not the native path; MLX-based tools are out of scope for this reference.

## Cloud GPUs

Rent when the model or method (full FT, 70B LoRA, GRPO) exceeds local memory, or to parallelize sweeps. Axolotl has `--cloud` launchers (Modal, Baseten, Nebius) and cloud images (`axolotlai/axolotl-cloud`). Provider choice, pricing, and setup belong to the `cloud-llms` skill.

## Memory-capped runs (Linux, systemd)

Run heavy jobs (training, merges, GGUF conversion, source builds) in a transient scope so an OOM kills the job, not the node:

```bash
systemd-run --user --scope -p MemoryMax=96G -p MemorySwapMax=0 -p MemoryHigh=88G -- \
  axolotl train my-run.yaml
```

- `MemoryMax=` hard limit (OOM-kill above), `MemoryHigh=` throttling threshold below it, `MemorySwapMax=0` prevents swapping instead of failing (systemd.resource-control). `-p` is short for `--property=`.
- Requires cgroup v2 with the memory controller delegated to your user manager; check: `cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers` should include `memory`.
- Size the cap to leave room for the OS and anything else that must stay up. On unified memory, whether CUDA allocations are fully charged to the cgroup is (unverified); treat the cap as a guard for host-side memory (tokenization, merges, conversion) and also bound the trainer itself (batch size, sequence length, Axolotl `gpu_memory_limit`).
- For Docker runs, use `docker run --memory=96g --memory-swap=96g ...` instead.
- Run inside `tmux` (or `systemd-run --user --unit=ft-run ...` as a service) so SSH disconnects don't kill training.

## Downloads: hf-xet and memory

`huggingface_hub` downloads through `hf-xet`, which can use a lot of memory/CPU in parallel and has been seen to OOM inside tight caps. Relevant variables (huggingface_hub environment variable docs):

- `HF_HUB_DISABLE_XET=1` — don't use `hf-xet` even if installed (fallback path).
- `HF_XET_HIGH_PERFORMANCE` — leave unset on shared/capped boxes (it saturates network and all CPU cores).
- `HF_XET_RECONSTRUCT_WRITE_SEQUENTIALLY=1` — sequential disk writes (for HDDs).
- `HF_XET_CACHE`, `HF_HOME`, `HF_HUB_CACHE` — move caches to a big disk.
- `HF_XET_NUM_CONCURRENT_RANGE_GETS` is no longer used (concurrency is adaptive since hf_xet 1.3.0) and `HF_XET_CHUNK_CACHE_SIZE_BYTES` has no effect; `HF_HUB_ENABLE_HF_TRANSFER` is deprecated.
- hf_xet sizes its download buffers from the tightest cgroup limit, so a `systemd-run` `MemoryMax` already shrinks them. xet-core (v1.7.0) also reads `HF_XET_FIXED_DOWNLOAD_CONCURRENCY` and `HF_XET_RECONSTRUCTION_DOWNLOAD_BUFFER_LIMIT`; these are source-level settings, not in the huggingface_hub docs.

Pre-download outside the training job so the trainer doesn't fetch mid-run:

```bash
HF_HUB_DISABLE_XET=1 systemd-run --user --scope -p MemoryMax=8G -- hf download <org>/<model>
hf cache ls
```

## Checkpointing

- Save every N steps or several times per epoch (`saves_per_epoch` / `save_steps`), keep the last few (`save_total_limit`), and resume with `axolotl train cfg.yaml --resume-from-checkpoint <dir>` or TRL `trainer.train(resume_from_checkpoint=True)`.
- Check free disk first: full-FT checkpoints include optimizer state (several x model size each).

## Official links

- Axolotl hardware mapping: https://docs.axolotl.ai/docs/choosing_method.html
- Axolotl multi-GPU: https://docs.axolotl.ai/docs/multi-gpu.html
- systemd.resource-control: https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
- systemd-run: https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html
- huggingface_hub env vars: https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables
- Unsloth DGX Spark: https://unsloth.ai/docs/blog/fine-tuning-llms-with-nvidia-dgx-spark-and-unsloth
- NVIDIA DGX Spark: https://www.nvidia.com/en-us/products/workstations/dgx-spark/
