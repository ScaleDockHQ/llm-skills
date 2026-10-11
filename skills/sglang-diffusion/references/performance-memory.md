# SGLang Diffusion: performance and memory

> Verified against SGLang Diffusion v0.5.21, 2026-10-11

Start with `--performance-mode auto` (the default), then change one lever at a time against a fixed prompt, seed and size. The docs split levers into **output-preserving** (residency, parallelism, kernels, scheduling) and **quality-tradeoff** (caches, quantization, lossy tiers). `sglang generate --help` and `sglang serve --help` are the source of truth for flags.

## Performance mode

`--performance-mode {manual|auto|speed|memory}` (alias `--mode`). `auto` dispatches residency from the selected GPUs' free memory (image DiTs stay resident above a 45 GiB threshold; video DiT placement is model-specific). `speed` keeps `torch.compile` off unless a model's deployment config opts in (`--enable-torch-compile true` to force); `memory` favors lower VRAM; `manual` leaves performance args to you. Explicit offload, FSDP and parallel flags always win. The least-free selected GPU is the bottleneck: a busy 80 GiB card behaves like a smaller one.

## Fitting in memory

| Need                           | Option                                                                                                                                                                                                                                                                                       |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Offload text encoder, DiT, VAE | `--text-encoder-cpu-offload`, `--dit-cpu-offload`, `--image-encoder-cpu-offload`, `--vae-cpu-offload`, `--pin-cpu-memory` (pinned memory is the default)                                                                                                                                     |
| Per-component residency        | `--component-residency all=resident text_encoder=layerwise-offload vae=component-offload` (modes `resident`, `component-offload`, `snapshot-offload`, `layerwise-offload`; keys from `model_index.json`)                                                                                     |
| Stream layers of a big DiT     | `--dit-layerwise-offload` or `--layerwise-offload-components transformer,text_encoder`; tune `--layerwise-prefetch-size`, `--layerwise-resident-layers`, `--layerwise-residency-policy`, `--layerwise-residency-lifetime` (names must be loaded component keys; `dit=4` is silently ignored) |
| Tiled VAE                      | `vae_tiling: true` in a config file; HunyuanVideo uses tiled decode by default                                                                                                                                                                                                               |
| Smaller weights                | quantization below                                                                                                                                                                                                                                                                           |

Component offload moves whole modules and costs transfers each use; layerwise streams blocks and costs a transfer of the component's weights every time it runs, so choose the smallest component set that fits. Snapshot offload keeps a host copy and needs the whole component on the GPU; it is unsupported with FSDP, shared-memory GPUs and breakable CUDA graphs. FSDP shards across multiple GPUs; it does not keep a single-GPU deployment on one GPU (use offload).

## Parallelism

`num_gpus = cfg_parallel_degree x tp_size x sp_degree`, and `sp_degree = ulysses_degree x ring_degree`.

| Flag                                                   | Splits                                                                                   |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `--num-gpus N`                                         | GPUs used                                                                                |
| `--enable-cfg-parallel` / `--cfg-parallel-size`        | guidance branches (Qwen and Wan CFG generation; pairs with FSDP)                         |
| `--tp-size N`                                          | weights and heads; for compatibility or encoder-heavy paths, not a default latency lever |
| `--ulysses-degree U`, `--ring-degree R`, `--sp-degree` | sequence for long videos or large images                                                 |
| `--kv-gather-degree`                                   | K/V all-gather alternative (non-causal; not with Ulysses or Ring)                        |
| `--dp-size N`                                          | N full replicas, requests round-robin (realtime sessions stick)                          |
| `--encoder-parallel auto/fold/dp/replicate`            | text and image encoders across idle GPUs                                                 |

Example from the docs: `--num-gpus 4 --ulysses-degree 2 --ring-degree 2`. SP needs head counts and sequence lengths that divide; use the parallelism page's constraints. Use `nccl-rdma-networking` for multi-node concerns.

## Attention

`--attention-backend` (lowercase enum names; `fa3`/`fa4` alias `fa`): CUDA prefers FlashAttention (FA3 or FA4) then PyTorch SDPA; ROCm and XPU have their own FA paths; MPS always uses SDPA. `--component-attention-backends text_encoder=torch_sdpa,transformer=fa` overrides per component; `SGLANG_DIFFUSION_ATTENTION_BACKEND` sets a default. `--attention-backend` is strict for native pipelines: an unsupported choice fails rather than falling back.

## Caches (approximate, except conditioning reuse)

- **Conditioning cache** (default on, exact): reuses text, image and VAE-posterior work across requests. `--disable-conditioning-cache`, `--conditioning-cache-max-size-mb` (default 512, 0 disables).
- **Cache-DiT** (lossy): per-request switch; `SGLANG_CACHE_DIT_ENABLED=true` makes it the server default (`SGLANG_CACHE_DIT_*` for settings); runs with layerwise offload but not FSDP. Diffusers backend: `--backend diffusers --cache-dit-config file`.
- **TeaCache** and **Spectrum**: other approximate step-skipping methods, per their pages.
- `--quality {lossless,extra-high,high}`: request tier; `high` may use audited Cache-DiT policies or lower-precision VAE decode.

## Quantization (lossy)

Component-scoped options: `--component-weights-paths.transformer REPO` (pre-quantized weights over a base model, such as `black-forest-labs/FLUX.2-dev-NVFP4`), `--component-paths.<component>`, `--component-quantizations.<component> METHOD` (online), `--component-quantization-ignored-layers.<component>`, `--component-precisions.<component> DTYPE`. Primary-DiT aliases: `--transformer-path`, `--transformer-weights-path`, `--quantization`. `--kv-cache-quant {off,int4,int2}` compresses realtime causal-video KV chunks. Support is capability-based per loader; read the quantization page and the model's cookbook for validated combinations.

## Throughput

- `--batching-mode dynamic --batching-max-size 8 --batching-delay-ms 5 --enable-batching-metrics`: merge compatible queued T2I or T2V requests (default `--batching-max-size 1`); rules in a JSON `--batching-config`. Check the compatibility grid; GLM-Image batches only the AR call.
- `--warmup-mode {off,request,server}`; `--enable-torch-compile` (enables server warmup); `--enable-breakable-cuda-graph` with `--warmup-resolutions 1024x1024` listing every served size.
- Profile before stacking levers (`SGLANG_DIFFUSION_TORCH_PROFILER_DIR`, the profiling page).
