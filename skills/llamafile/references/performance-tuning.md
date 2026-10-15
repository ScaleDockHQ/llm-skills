# Tune llamafile

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

## GPU backends

| Hardware                | How it works                                                                                                           | Notes                                                                |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| Apple silicon           | Metal, compiled on first run with Xcode Command Line Tools; on by default                                              | Disable with `-ngl 0` or `--gpu disable`                             |
| NVIDIA (Linux, Windows) | Bundled `ggml-cuda` in `llamafile` (not in `-thin`)                                                                    | Needs a driver only; pass `-ngl 999`                                 |
| Vulkan (any vendor)     | Bundled `ggml-vulkan`                                                                                                  | `--gpu vulkan`; used by `--gpu auto` when no vendor backend is found |
| AMD ROCm                | Not bundled; build with `llamafile/rocm.sh` or fetch prebuilt `ggml-rocm` from the `mozilla-ai/llamafile_0.10` HF repo | Experimental; `--gpu amd`; Radeon multi-GPU may break                |
| Intel                   | No oneAPI/SYCL backend; use Vulkan                                                                                     |                                                                      |
| CPU                     | AVX, AVX2, AVX512, FMA, F16C, VNNI selected at runtime on x86; NEON on ARM                                             |                                                                      |

The executable looks for `ggml-(cuda|rocm|vulkan).(so|dll)` in this order: the same directory (so a hand-built library wins), inside the llamafile bundle, `~/.llamafile/v/<version>`, then `$HOME`. If a library loads but finds no device, llamafile moves to the next backend. A missing library prints benign `ggml_backend_load_best: search path does not exist` warnings.

Make failures loud: `--gpu nvidia` or `--gpu amd` turns a silent CPU fallback into an explicit startup error. A `hipcc: Permission denied` message means ROCm was found but cannot run.

Build GPU libraries with `llamafile/cuda.sh`, `rocm.sh` or `vulkan.sh` (each needs its toolchain; `references/building-llamafiles.md`). The released CUDA library is size-optimized and omits IQ-quant kernels, so IQ-quantized layers stay on the CPU.

## Offload and memory

- `-ngl 999` for all layers; reduce when VRAM is short. `--fit` auto-fits layers and context.
- Context costs VRAM: lower `-c` before dropping layers. `-ctk q8_0 -ctv q8_0` shrinks the KV cache (needs flash attention).
- `-fa on` enables flash attention.
- Weight loading: default `--load-mode auto` memory-maps. Use `-lm none` to read into RAM on slow or network disks, `-lm mmap+mlock` to pin the model in RAM.
- Embedded weights are page-aligned in the zip so the GPU can use them directly; do not recompress them.

## CPU

- `-t` threads for decode: use physical cores. `-tb` for prompt processing can be higher.
- `-C`/`--cpu-mask`, `--cpu-range`, `--numa` pin threads on multi-socket hosts.
- A CPU without AVX is refused outright (x86-64).

## Server

- `-np N` sets slots; each slot has its own share of the context, so raise `-c` accordingly.
- `-cb` continuous batching is on by default. `--cache-reuse N`, `--cache-ram`, and `--slot-prompt-similarity` tune prompt caching.
- `--threads-http` for many connections.
- Use the `timings` field in responses to see prompt and generation tokens per second.

## Benchmarking

Source builds can also produce `llama-bench`, `quantize`, `imatrix` and `perplexity` (0.10.6 added their link recipes). For service benchmarking use the bench script shipped with the `self-hosted-llms` skill (`npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`).

## Checklist for slow output

1. Confirm GPU use: the startup log should name the backend and offloaded layers. Force `--gpu nvidia`, `--gpu amd` or `--gpu vulkan` to surface problems.
2. Check `-ngl` (default does not offload on NVIDIA and AMD).
3. Check the file is not an IQ quant on NVIDIA.
4. Check `-t` against physical cores and that nothing else loads the CPU.
5. In combined mode the TUI and server share one process; use `--server` for benchmarks.
