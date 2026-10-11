# llama.cpp: performance tuning

> Verified against llama.cpp b11556 (master; tools/server/README.md, docs/build.md, tools/llama-bench/README.md) and v0.6.0, 2026-10-11

Order of work: fit the model in memory, get all layers on the right device, size context and slots, then tune batches and backend-specific options. Measure each change with `llama-bench` (engine) and `scripts/bench.sh` (HTTP).

## 1. Fit it in memory

- `--fit on` (default) adjusts unset arguments (such as `-ngl`, `-c`) to fit device memory: `--fit-target MiB[,MiB...]` margin per device (default 1024), `--fit-ctx N` minimum context it may reduce to (default 4096). Pass explicit `-c`/`-ngl` to override it; check the startup log for what it chose.
- Memory = weights + KV cache + compute buffers. KV grows with `-c` (total across slots) and shrinks with a quantized cache: `-ctk q8_0 -ctv q8_0` halves it versus f16 (numerics change slightly; `q4_0` saves more at a quality cost). Allowed types: `f32, f16, bf16, q8_0, q4_0, q4_1, iq4_nl, q5_0, q5_1`. In practice a quantized V cache needs flash attention (not stated in the docs read; if the server refuses, set `-fa on`).
- Lower `-c`, pick a smaller quant (`references/models-and-formats.md`), or offload experts of MoE models to RAM (`-cmoe`, `-ncmoe N`, `references/parallelism-multinode.md`).
- `--swa-full` keeps the full-size sliding-window cache (more memory, better prompt reuse on SWA models); default off.
- `-ngl all` for GPUs with room; partial offload when it does not fit. `--no-kv-offload` keeps KV in RAM (slow, saves VRAM).

## 2. Context and slots

`-c` is total context; with `-np N` slots and the unified KV buffer (`-kvu`, default when slots are auto) the pool is shared, so a single request can use up to `-c`. Without it each slot gets `-c / N`. Use `-np` equal to expected concurrent requests; more slots do not add throughput on one GPU beyond batching gains. Prompt-heavy agent workloads benefit from `--cache-prompt`, `--cache-reuse`, `-cram` (default 8192 MiB host cache) and pinning conversations with `id_slot`.

## 3. Flash attention

`-fa auto` (default) enables it where supported. Force `-fa on` for quantized V cache and for DFlash/DSpark speculation. CUDA FlashAttention kernels exist for the K/V type pairs compiled via `GGML_CUDA_FA_QUANTS` (default `q4_0-q4_0;q8_0-q8_0;f16-f16;bf16-bf16`); other pairs fall back to f16 kernels with a warning.

## 4. Batch sizes

`-b` (logical, default 2048) and `-ub` (physical, default 512). Raising `-ub` (for example 1024 to 2048) often speeds prompt processing at the cost of compute-buffer memory; return to 512 if memory is tight. Benchmark: `llama-bench -m model.gguf -ngl 99 -ub 512,1024,2048 -p 2048 -n 128` (comma lists test several values).

## 5. Threads and CPU

`-t` for generation threads (default auto), `-tb` for prompt processing, `--cpu-mask`/`--cpu-range`/`--cpu-strict` for affinity, `--poll`, `--prio`. On NUMA hosts try `--numa distribute|isolate|numactl` (drop the page cache first). Weights are repacked for CPU kernels (`--no-repack` disables). On arm64 use a build with KleidiAI (`-DGGML_CPU_KLEIDIAI=ON`).

## 6. Loading and memory mapping

`-lm/--load-mode auto|none|mmap|mlock|mmap+mlock|dio` (older builds: `--no-mmap`, `--mlock`). `mmap` gives fast starts and lazy paging; `mlock` pins weights in RAM. On unified-memory GPUs with large models, third-party Strix Halo guides recommend disabling mmap, see `references/combos/strix-halo-vulkan.md`. `-lzm/--lazy-mode` reads huge per-layer-embedding tensors on demand.

## 7. Backend environment variables and CMake options

CUDA (docs/build.md):

| Setting                                                | Effect                                                                                                                |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `CUDA_VISIBLE_DEVICES`                                 | Hide or reorder devices (`-0` hides the first).                                                                       |
| `CUDA_SCALE_LAUNCH_QUEUES=4x`                          | Larger command buffer, helps multi-GPU pipeline prompt throughput.                                                    |
| `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1`                    | Linux: allow swapping to system RAM instead of crashing on VRAM exhaustion (slow). Also used for HIP APUs.            |
| `GGML_CUDA_P2P`                                        | Peer-to-peer GPU copies (driver and board support needed; can corrupt output with some IOMMU settings).               |
| `GGML_CUDA_CUBLAS_COMPUTE_TYPE`                        | `auto, f16, fp16, bf16, f32, fp32`.                                                                                   |
| `GGML_CUDA_MMQ_PREC`                                   | `auto, q8, q4` for NVFP4/MXFP4 matmuls; on Blackwell `q4` keeps the native W4A4 path (faster prefill, less accurate). |
| Build `GGML_CUDA_FORCE_MMQ` / `GGML_CUDA_FORCE_CUBLAS` | Choose custom quantized kernels (lower VRAM) or FP16 cuBLAS (faster prefill on recent datacenter GPUs, more memory).  |

HIP: `HIP_VISIBLE_DEVICES`, `HSA_OVERRIDE_GFX_VERSION`. Vulkan (read from ggml-vulkan.cpp on master; diagnostic or workaround knobs, change by build): `GGML_VK_VISIBLE_DEVICES`, `GGML_VK_PREFER_HOST_MEMORY`, `GGML_VK_DISABLE_COOPMAT`, `GGML_VK_DISABLE_INTEGER_DOT_PRODUCT`, `GGML_VK_FORCE_MAX_ALLOCATION_SIZE`, `GGML_VK_PERF_LOGGER=1` (per-op timings), `GGML_VK_DISABLE_FUSION`. Meaning of each beyond the name is **unverified**; read the source or run with the logger before relying on one.

## 8. Speculative decoding

Often the largest decode speedup for single-user latency; see `references/features.md`. Keep it off for high-concurrency batches where the GPU is already busy.

## 9. Measure

```bash
# Engine only: prefill (pp) and decode (tg), several depths and settings
llama-bench -m model.gguf -ngl 99 -fa on -p 512,2048 -n 128 -d 0,8192 -o md
# Compare KV types
llama-bench -m model.gguf -ngl 99 -fa on -ctk f16,q8_0 -ctv f16,q8_0
# Pull from HF without a local file
llama-bench -hf ggml-org/gemma-3-4b-it-GGUF:Q4_K_M -ngl 99
# End to end through HTTP (with prompt cache, tokenization, templates)
scripts/bench.sh --base-url http://127.0.0.1:9931 --model local-model   # run with --help for all options
```

`llama-bench` options: `-p` prompt tokens (default 512), `-n` generation tokens (128), `-pg pp,tg`, `-d` context depth, `-r` repetitions (5), `-o md|csv|json|jsonl|sql`, `-sm`, `-ts`, `-ncmoe`, `-ot`, `-dev`, `-rpc`, `--list-devices`. Results depend on build, driver and thermal state: record `llama-server --version` and the driver with every number. Never compare numbers from different batch sizes or depths.

## Rules of thumb

- Decode speed is memory-bandwidth-bound: a Q4 model is faster than Q8 of the same model; unified-memory machines (Apple, GB10, Strix Halo) decode at roughly bandwidth divided by active-weight bytes.
- MoE models decode as fast as their active parameters suggest but need all experts resident (or `-cmoe` offload).
- Prompt processing is compute-bound: larger `-ub`, flash attention, and a backend with matrix cores (CUDA tensor cores, Metal tensor API, Vulkan coopmat) matter.
- A server that is slow only on the first request after idle is reloading (`--sleep-idle-seconds`, router unload, or a llama-swap `ttl`).

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- https://github.com/ggml-org/llama.cpp/blob/master/tools/llama-bench/README.md
- https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-vulkan/ggml-vulkan.cpp
