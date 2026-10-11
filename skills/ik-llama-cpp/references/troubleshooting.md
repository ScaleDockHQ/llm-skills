# Troubleshooting ik_llama.cpp

> Verified against ik_llama.cpp main (89bba35c), README and docs/parameters.md, 2026-10-11

| Symptom                                                 | Cause and fix                                                                                                 |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Slow prompt processing on a hybrid MoE setup            | `-rtr` is set: remove it (README warning). Also check `-ub`, `-ngl 999` and that attention tensors are on GPU |
| Gibberish with `-sm graph` and `--cpu-moe`/`-ot`        | Add `-cuda graphs=0` (README note); confirm the architecture supports graph mode                              |
| Model fails to load or garbage output with Unsloth file | Files with `_XL` containing f16 tensors are likely unsupported; use another quant                             |
| Unknown tensor or quant type                            | Mainline-only type or architecture; check the README model list, or use mainline `llama-cpp`                  |
| CUDA out of memory on load with `--fit`                 | Raise `--fit-margin` (default 1024 MiB) or `--gpu-fit-margin`; reduce `-c`, KV types, `-ub`                   |
| CUDA OOM at long prompts                                | Compute buffers: lower `-ub`, `-amb`, `-wgt`; quantize KV                                                     |
| Slow on Zen4 / Sapphire Rapids                          | Built without AVX-512 options; rebuild with `-DGGML_AVX512*` (`references/install.md`)                        |
| Slow on ROCm, Vulkan, Metal, old NVIDIA                 | Unsupported backends per README; use mainline `llama-cpp` there                                               |
| High RAM use / swapping with experts on CPU             | `GGML_CUDA_NO_PINNED_WEIGHTS=1`, `-cram 0`, `--no-mmap` off, fewer slots; `--mlock` only with headroom        |
| Very slow first request after start                     | mmap page-in of experts: `-dexp`/`-prexp`, or warm with one request                                           |
| Tool calls are plain text                               | Missing `--jinja`, or template without tool format; use `--chat-template-file` and `--reasoning-format`       |
| Unknown flag error after update                         | Legacy speculative flags (`--draft-*`, `-mtp`, `--spec-stage`) are rejected; use `--spec-type`                |
| `/health` 503                                           | Model still loading (large models take minutes); 500 means load failed, read the log                          |
| Container cannot see GPU                                | Missing NVIDIA Container Toolkit or `--runtime nvidia`; Podman needs CDI flags                                |
| Reasoning text in `content`                             | Set `--reasoning-format deepseek`                                                                             |
| Build error: CUDA arch                                  | Set `-DCMAKE_CUDA_ARCHITECTURES=<cc>` for your GPU                                                            |

Collect for an upstream issue: commit SHA, full command line, `nvidia-smi` output, the model quant name, and the first 50 log lines. Do not post API keys or prompts. Issues about unsupported backends will not be handled.
