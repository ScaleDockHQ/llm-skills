# Diffusers: memory and speed

> Verified against Diffusers v0.41.0 (docs optimization/memory, fp16, speed-memory-optims, cache, mps, attention_backends), 2026-10-11

Measure first: `torch.cuda.max_memory_allocated()/1024**3` after a run, and `nvidia-smi`. Change one thing at a time and compare a fixed-seed image.

## Ordered fixes for out of memory

1. **Right dtype.** `bfloat16` or `float16` instead of float32; per-component dict if needed (`pipelines-and-cli.md`).
2. **VAE.** `pipe.vae.enable_tiling()` for large images (tone variation between tiles is possible; disabled below a size limit, 512x512 for the SD VAE), `pipe.vae.enable_slicing()` for batches. CLI: `--vae-tiling`, `--vae-slicing`.
3. **Model offloading.** `pipe.enable_model_cpu_offload()`: whole components move to the GPU one at a time. Single GPU only. Best default for image models.
4. **Quantize the big components** (`quantization-and-lora.md`). Upstream's Flux table on an RTX 4090 shows quantization plus model offload reaching 12.24 GB at 32.3 s versus 14.95 GB at 32.6 s for quantization alone.
5. **Group offloading** for video or very large models: `pipe.enable_group_offload(onload_device=..., offload_device=..., offload_type="leaf_level", use_stream=True)`; `block_level` takes `num_blocks_per_group` (use 1 with streams). `offload_to_disk_path` offloads to disk. It can clash with models whose forward casts inputs by device. Upstream recommends quantization plus group offload for video and quantization plus model offload for images.
6. **Sequential offload**, last resort: `pipe.enable_sequential_cpu_offload()` is very slow and single GPU; call it before the pipeline is on CUDA.
7. **Layerwise casting:** `transformer.enable_layerwise_casting(storage_dtype=torch.float8_e4m3fn, compute_dtype=torch.bfloat16)` stores weights in fp8, computes in bf16.
8. **Lower resolution, frames or batch size.**

## Multiple GPUs

`device_map="balanced"` with optional `max_memory`; sharded checkpoints (`save_pretrained(..., max_shard_size="5GB")`) load shard by shard to keep peak memory low. `enable_model_cpu_offload` and sequential offload do not combine with a device map: call `reset_device_map()` first. For tensor-parallel loading and multi-GPU inference see the distributed inference docs.

## Apple silicon and unified memory

MPS is sensitive to memory pressure and swaps; use `enable_attention_slicing()` below 64 GB RAM. On unified-memory hosts (DGX Spark, Apple) CPU offload frees the same pool the GPU uses, so it gains little and costs time.

## Speed

- SDPA is on by default on PyTorch 2+. Other attention backends: `diffusers-cli run --attention-backend` offers Hub kernels such as `flash_hub` and `sage_hub` (transformer pipelines only); Hub kernels download and execute code on first use, so list and approve the backend first.
- `torch.compile`: compile the denoiser (and `vae.decode`); first call is slow, each new image size recompiles. Regional compilation reduces compile time. Use the same shapes across calls. `max-autotune` trades compile time for speed.
- Caching: `pipe.transformer.enable_cache(config)` with `PyramidAttentionBroadcastConfig`, `FasterCacheConfig`, `SeaCacheConfig`, and `apply_first_block_cache(transformer, FirstBlockCacheConfig(threshold=0.2))`. Higher skip thresholds are faster and lower quality; compare outputs.
- Fewer steps with distilled or turbo checkpoints and their recommended guidance (for example FLUX.1-schnell uses `guidance_scale=0` and 4 steps in upstream's example).
- Keep encoders on the same device as the denoiser when memory allows; offload hooks add transfers.
