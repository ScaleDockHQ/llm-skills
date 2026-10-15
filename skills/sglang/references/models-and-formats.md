# SGLang: models and formats

> Verified against SGLang v0.5.21 (docs: advanced_features/quantization, model_loading, supported-models/*; NVIDIA dgx-spark-playbooks/nvidia/sglang README), 2026-10-11

Choosing a quantization format for a hardware target is a cross-engine decision: skill `model-quantization` (install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`). This page is what SGLang itself accepts.

## Where models come from

- Hugging Face repo ID (default), cached under `~/.cache/huggingface` (mount it into containers). Pre-download with `hf download <repo> --revision <sha>`, then run with `HF_HUB_OFFLINE=1`.
- Local directory with safetensors weights (`--model-path /models/foo`). `--download-dir` changes the HF download target.
- ModelScope: `SGLANG_USE_MODELSCOPE=true`.
- Object storage (`s3://`, `gs://`, `az://`) auto-uses `runai_streamer`; `.gguf` paths auto-use `gguf`; Mistral-native checkpoints auto-use `mistral`.
- `--load-format`: `auto` (safetensors, fallback to `.bin`), `pt`, `safetensors`, `npcache`, `dummy`, `sharded_state`, `gguf`, `bitsandbytes`, `mistral`, `layered`, `flash_rl`, `remote`, `remote_instance`, `fastsafetensors`, `private`, `runai_streamer`. Weight loading knobs: `--weight-loader-prefetch-checkpoints`, `--weight-loader-disable-mmap`, `--model-loader-extra-config`.
- Architecture support: search `python/sglang/srt/models/` for the HF `architectures` class name (the docs recommend a GitHub search such as `repo:sgl-project/sglang path:/^python\/sglang\/srt\/models\// Qwen3ForCausalLM`). If missing, `--model-impl transformers` uses the Transformers fallback (see upstream `transformers_fallback`); expect lower performance.
- Per-model recommended commands (GPU count, parallelism, parsers, quantization): the upstream cookbook at `https://docs.sglang.io/cookbook` (printed in the `sglang --help` epilog).

## Quantization methods

Rule from upstream: if a checkpoint is already quantized, do not add `--quantization` (that would request online quantization on top). Prefer offline (pre-quantized) checkpoints over online.

| Method / flag                                                         | NVIDIA                              | AMD                                | Notes                                                                                         |
| --------------------------------------------------------------------- | ----------------------------------- | ---------------------------------- | --------------------------------------------------------------------------------------------- |
| BF16/FP16 (`--dtype`)                                                 | yes                                 | yes                                | Baseline.                                                                                     |
| `fp8`                                                                 | yes                                 | yes                                | Online FP8 on a BF16 checkpoint, or load an FP8 checkpoint with no flag. Aiter/Triton on AMD. |
| `modelopt_fp8`                                                        | yes                                 | no                                 | NVIDIA ModelOpt FP8 checkpoints (`nvidia/*-FP8`).                                             |
| `modelopt_fp4` (NVFP4)                                                | SM80-SM90 via Marlin, SM100+ native | no                                 | `nvidia/*-FP4` / `-NVFP4` checkpoints. Required for NVFP4 on DGX Spark per NVIDIA's playbook. |
| `nvfp4_online`                                                        | Blackwell (SM100/SM103)             | no                                 | Converts MoE expert weights at load; uses `flashinfer_trtllm` MoE runner.                     |
| `mxfp4`                                                               | yes                                 | CDNA3/CDNA4 + `SGLANG_USE_AITER=1` | gpt-oss ships MXFP4.                                                                          |
| `awq`, `awq_marlin`                                                   | yes (`awq_marlin` NVIDIA only)      | `awq` only (Triton dequant)        | Use `--dtype half` for AWQ.                                                                   |
| `gptq_marlin`, `marlin`                                               | yes                                 | no                                 | Plain `gptq` is listed "No" on NVIDIA in the matrix; use the Marlin path.                     |
| `compressed-tensors`                                                  | yes                                 | yes                                | LLM Compressor outputs; see `llm-compressor` skill.                                           |
| `w8a8_int8`, `w8a8_fp8`, `blockwise_int8`                             | yes                                 | yes                                |                                                                                               |
| `gguf`                                                                | yes                                 | no                                 | Loads GGUF; not the fast path. For GGUF prefer llama.cpp.                                     |
| `bitsandbytes`                                                        | yes                                 | experimental                       |                                                                                               |
| `auto-round`, `quark`, `petit_nvfp4` (AMD), `quark_int4fp8_moe` (AMD) | varies                              | varies                             | See the matrix upstream.                                                                      |
| `mlx_q4`, `mlx_q8`                                                    | Apple MLX backend only              |                                    | Quantizes at load.                                                                            |

KV cache: `--kv-cache-dtype fp8_e4m3|fp8_e5m2|bf16|nvfp4|fp4_mx_block16` (the FP4 forms need CUDA 12.8+ and PyTorch 2.8+). For FP8 KV supply scales with `--quantization-param-path` when available; otherwise scales default to 1.0 and accuracy can suffer.

ModelOpt in-engine flow: `--modelopt-quant fp8|int4_awq|w4a8_awq|nvfp4|nvfp4_awq`, with `--modelopt-checkpoint-save-path`, `--modelopt-export-path`, `--quantize-and-serve` for prototyping (needs `pip install nvidia-modelopt`). For production, quantize and export separately (skill `nvidia-modelopt`).

GEMM runner selection: `--fp8-gemm-backend`, `--fp4-gemm-backend`, `--bf16-gemm-backend` (all default `auto`).

## NVIDIA DGX Spark support matrix (from the NVIDIA playbook, updated 2026-04-28)

| Model                                           | Quant       | HF handle                                                                                    |
| ----------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------- |
| gpt-oss-20b / 120b                              | MXFP4       | `openai/gpt-oss-20b`, `openai/gpt-oss-120b`                                                  |
| Llama-3.1-8B-Instruct                           | FP8 / NVFP4 | `nvidia/Llama-3.1-8B-Instruct-FP8`, `nvidia/Llama-3.1-8B-Instruct-FP4`                       |
| Llama-3.3-70B-Instruct                          | NVFP4       | `nvidia/Llama-3.3-70B-Instruct-FP4`                                                          |
| Qwen3-8B / 14B                                  | FP8 / NVFP4 | `nvidia/Qwen3-8B-FP8`, `nvidia/Qwen3-8B-FP4`, `nvidia/Qwen3-14B-FP8`, `nvidia/Qwen3-14B-FP4` |
| Qwen3-32B                                       | NVFP4       | `nvidia/Qwen3-32B-FP4`                                                                       |
| Phi-4-multimodal-instruct, Phi-4-reasoning-plus | FP8 / NVFP4 | `nvidia/Phi-4-*-FP8`, `nvidia/Phi-4-*-FP4`                                                   |
| Nemotron-3-Nano-Omni-30B-A3B-Reasoning          | BF16        | `nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16` (follow its model card)                 |

For NVFP4 models add `--quantization modelopt_fp4`.

## Model-family notes

- Embedding/rerank/reward models: `--is-embedding` for decoder-style embedding models; native encoders and `google/embeddinggemma-300m` are auto-detected. See `features.md`.
- Multimodal (VLM): Qwen2.5-VL, Llama 3.2 Vision, LLaVA-OneVision, Gemma 3 and more; send images via the OpenAI vision format. `--language-model-only` skips the vision tower to save memory; `--enable-multimodal` forces it on.
- MoE/MLA (DeepSeek, Kimi K2, MiniMax, GLM, Qwen MoE): see `parallelism-multinode.md` and the model's cookbook page.
- Diffusion models are a separate engine (`sglang-diffusion`, `sglang serve --model-type ...`); out of scope here.
- Parsers per model family (tool calling and reasoning): `features.md`.
