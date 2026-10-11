# stable-diffusion.cpp: performance and memory

> Verified against stable-diffusion.cpp master-956-1b0ba10 (docs/performance.md, docs/backend.md, docs/caching.md, `sd-server --help`), 2026-10-11

Start with `-v`, then read the peak buffers in the log. Change one thing at a time and compare a fixed-seed image.

## Ordered fixes for out of memory

1. `--diffusion-fa` (flash attention in the diffusion model). Saves memory (about 600 MB for FLUX at 768x768, about 1.4 GB for SD2 at 768x768 per upstream) and usually speeds up CUDA; it can slow other backends and works only for some models and backends (CPU, CUDA/ROCm, Metal). The log shows `Using flash attention in the diffusion model`.
2. `--vae-tiling` (default tile `256x256` image pixels, overlap 0.5; tune with `--vae-tile-size WxH`, `--vae-tile-overlap`, `--vae-relative-tile-size`). Costs time and can affect quality, especially when encoding. Even without the flag, VAE decode retries failed allocations with smaller tiles; encoding does not retry.
3. A smaller quant or GGUF (`models-and-weights.md`).
4. `--offload-to-cpu`: keeps weights in RAM and loads them to VRAM when needed; upstream says it saves VRAM "without reducing generation speed" on discrete GPUs. It is shorthand for prepending `*=cpu` to `--params-backend`.
5. `--params-backend disk` (or per module: `diffusion=disk,te=cpu,vae=cpu`): lowest RAM and VRAM, slower because evicted weights are re-read. Never chosen implicitly.
6. `--max-vram GiB` (per-device budget, or `cuda0=6,vulkan0=2`; `0` = current free memory; negative = reserve that many GiB). Models whose weights exceed the budget run in automatic segments, with next-segment prefetch (`--disable-prefetch`) and forced monolithic mode (`--disable-segmented-compute`) as diagnostics. It is not a hard physical cap: driver contexts are outside it.
7. Lower resolution or batch.

Also on by default: `--auto-fit on` (weights placed on the compute GPU, then RAM, another GPU or disk by available memory; an explicit `--params-backend` disables it) and `--batched-cfg on` (UNet conditional and unconditional passes in one batch).

## Backend placement

```bash
sd-server --list-devices                                       # names for --backend
sd-cli ... --backend cuda0 --params-backend te=cpu,vae=cpu      # text encoder and VAE weights in RAM
sd-cli ... --backend "te=cpu,vae=cuda0,diffusion=vulkan0"        # module-level runtime backends
sd-cli ... --backend "diffusion=cuda0&cuda1" --split-mode layer # layer split across two GPUs
```

Modules: `diffusion`, `te`, `vae`, `controlnet`, `clip_vision`, and others (names ignore case, hyphens and underscores). Layer split applies to `diffusion` and `te`; `--split-mode row` is CUDA only. `--clip-on-cpu`, `--vae-on-cpu` and `--control-net-cpu` are deprecated in favour of `--backend te=cpu` and so on. `--rpc-servers host:port,...` offloads to RPC servers (`docs/rpc.md`).

## Unified memory (DGX Spark, Apple silicon)

CPU and GPU share one pool, so offload and CPU-placement flags save nothing and cost speed. Size the model so weights, compute buffers and any LLM fit together (`nvidia-dgx-spark`, `apple-silicon` skills).

## Speed

- Fewer steps with distilled or turbo models and matching `--cfg-scale` (Z-Image Turbo uses 1.0 and 8 steps in upstream's example).
- Step caching: `--cache-mode ucache` (UNet), `easycache`, `dbcache`, `taylorseer`, `cache-dit` (DiT block level), `spectrum` (both), tuned with `--cache-option "threshold=0.3"`. Quality drops as thresholds rise; compare outputs. `ucache` with `euler_a` is more conservative with `reset=0`.
- `--conditioning-cache-size N`: LRU of text-conditioning results; default 4 for `sd-server`, 0 for `sd-cli`.
- `--sage-attn` on CUDA with the patched GGML (see `docs/sage_attention.md` for GPU requirements); `--diffusion-conv-direct` and `--vae-conv-direct` change convolution kernels for some backends.
- `-t/--threads` matters on CPU (default: physical cores).
- `--taesd FILE` decodes with a tiny autoencoder: faster, lower quality.
