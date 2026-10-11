# Troubleshooting MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

| Symptom                                             | Cause and fix                                                                                                                                               |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `command not found: mlc_llm`                        | Env not active or only module installed: `python -m mlc_llm --help`                                                                                         |
| First start takes minutes, GPU busy, nothing served | JIT compiling the model library (`MLC_JIT_POLICY=ON`); wait, then it is cached under `$MLC_LLM_HOME/model_lib`                                              |
| `JIT is disabled by MLC_JIT_POLICY=OFF`             | No `--model-lib` and JIT off: pass a compiled lib or set the policy to `ON`/`READONLY` with a warm cache                                                    |
| Vulkan not found on Linux                           | `conda install -c conda-forge gcc libvulkan-loader`; check `vulkaninfo --summary`                                                                           |
| `GLIBC`/`libstdc++` not found                       | `conda install -c conda-forge libstdcxx-ng`                                                                                                                 |
| Windows `tvm.dll` or its dependencies missing       | `conda install zstd` (docs)                                                                                                                                 |
| Git LFS errors cloning a model                      | Install git-lfs: `conda install -c conda-forge git-lfs`; `git lfs install`                                                                                  |
| OOM at start or in long requests                    | Lower `gpu_memory_utilization`, `max_total_seq_length`, `context_window_size`, `prefill_chunk_size`; use `--mode local`; use a smaller quant or more shards |
| 401 `Invalid API Key`                               | `--api-key` is set; send `Authorization: Bearer <key>`                                                                                                      |
| Wrong model id / 404 in requests                    | Use the id from `/v1/models` exactly                                                                                                                        |
| Doc example fails on port 8080                      | Default port is 8000; some doc snippets use 8080                                                                                                            |
| Repetitive or wrong-format output                   | Wrong `conv_template` in `mlc-chat-config.json`; regenerate with the right `--conv-template`                                                                |
| Quality drop after conversion                       | `q3f16_1`/`q4f16_awq` weak; use `q4f16_1` or `q0f16`                                                                                                        |
| Unsupported model type in convert or compile        | Architecture missing from `model/model.py` on your build; update or add the model definition                                                                |
| `ImportError`/TVM mismatch after pip                | Mismatched `mlc-llm-nightly` and `mlc-ai-nightly` or different suffixes; reinstall both together                                                            |
| Python script hangs at exit                         | Missing `engine.terminate()`                                                                                                                                |
| `/debug/*` or extra debug fields appear             | `--enable-debug` is on; remove it                                                                                                                           |
| Multi-GPU run fails                                 | Check `tensor_parallel_shards` divides the model heads, GPUs visible (`CUDA_VISIBLE_DEVICES`), same backend build                                           |

Collect for an upstream issue: `pip list | grep -iE 'mlc|tvm'`, device and driver versions, the exact command, and the first 50 log lines. Do not post API keys or HF tokens.
