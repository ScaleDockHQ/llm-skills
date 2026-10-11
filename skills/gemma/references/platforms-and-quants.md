# Gemma 4 platforms and quants

> Verified against Gemma 4 overview (QAT routing table), vLLM recipes Gemma4 page, nvidia/Gemma-4-31B-IT-NVFP4 card, NVIDIA DGX Spark forum threads, Ollama gemma4 library, HF Gemma 4 blog, 2026-10-11

## Official quants

Google publishes quantization-aware-trained (QAT) Q4_0-class checkpoints in two collections: `collections/google/gemma-4-qat-q4-0` and `collections/google/gemma-4-qat-mobile` ([overview](https://ai.google.dev/gemma/docs/core)). Repo names follow `{model-name}-qat-<suffix>`; confirm the exact repo in the collection before pulling.

| Target                                     | Suffix                                                         | Sizes available                        |
| ------------------------------------------ | -------------------------------------------------------------- | -------------------------------------- |
| llama.cpp, LM Studio                       | `-qat-q4_0-gguf`                                               | E2B, E4B, 12B, 26B A4B, 31B            |
| vLLM, SGLang (server)                      | `-qat-w4a16-ct` (compressed-tensors)                           | E2B, E4B, 12B, 31B (not 26B A4B)       |
| Speculative decoding                       | `-qat-q4_0-unquantized` plus `-qat-q4_0-unquantized-assistant` | all five; the target must be quantized |
| Convert to other formats (for example MLX) | `-qat-q4_0-unquantized`                                        | all five                               |
| Mobile (LiteRT-LM, transformers)           | `-qat-mobile-transformers`, `-qat-mobile-ct`                   | E2B, E4B                               |

Other formats found:

| Format                     | Where                                                                                                                    | Notes                                                                                                                     |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| NVFP4                      | `nvidia/Gemma-4-31B-IT-NVFP4` (ModelOpt 0.42.0, Apache 2.0)                                                              | vLLM: `--quantization modelopt`. Card lists vLLM only.                                                                    |
| FP8                        | No official FP8 checkpoint found. vLLM can quantize online (`--quantization fp8`) and the Google table lists SFP8 sizes. | Unverified as a published checkpoint.                                                                                     |
| int8 weight-only (26B A4B) | vLLM online: `--quantization int8_per_channel_weight_only`                                                               | The recipe says 4-bit hurts the 26B because its expert dimension is small (704); int8 saves ~47%.                         |
| GGUF (community)           | `ggml-org/gemma-4-*-it-GGUF` (for example `gemma-4-26b-a4b-it-GGUF:Q4_K_M`), Unsloth and Bartowski quants are in use     | Not Google-official.                                                                                                      |
| MLX                        | `mlx-community/gemma-4-*` (for example `gemma-4-26b-a4b-it-4bit`); Ollama `gemma4:*-mlx`                                 | Name patterns differ from the HF example; the blog's comment thread reports a 404 on a guessed name. List the collection. |

vLLM QAT W4A16 memory (recipe): E2B 9.8 to 7.3 GB, E4B 15.2 to 9.8 GB, 12B 22.8 to 8.3 GB, 31B 59.0 to 19.8 GB.

## By platform

| Platform                                    | Recommendation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Basis                                                                                           |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **NVIDIA DGX Spark (GB10, 128 GB unified)** | 26B A4B BF16 or 31B fits in memory. Run vLLM; 31B NVFP4 (`nvidia/Gemma-4-31B-IT-NVFP4`) with `--quantization modelopt` is the NVIDIA-published option. Forum recipes also use `--kv-cache-dtype fp8`, `--enable-prefix-caching`, `--tool-call-parser gemma4`, `--reasoning-parser gemma4`. Attention backend is forced to `TRITON_ATTN` by Gemma 4's mixed head sizes. Expect single-digit to ~40 tok/s on the 26B depending on the build ("10-12" with `--enforce-eager`, "~40" with a community Docker image). | [forum](https://forums.developer.nvidia.com/t/how-to-run-gemma-4-nvfp4-in-vllm-docker/365513/9) |
| **Consumer RTX (16-24 GB)**                 | E4B or 12B via Ollama or llama.cpp QAT Q4_0 GGUF (12B Q4_0 ~6.7 GB weights; Ollama `12b-it-qat` is 7.2 GB). 26B A4B Q4_0 ~14.4 GB weights needs a 24 GB card with a small context. 31B QAT ~17.5 GB weights.                                                                                                                                                                                                                                                                                                     | overview memory table, Ollama tags                                                              |
| **Apple Silicon**                           | MLX via `mlx-vlm` (HF blog shows `mlx-community/gemma-4-26b-a4b-it-4bit`, TurboQuant option) or Ollama `gemma4:*-mlx` (26B is 18 GB, 31B is 19 GB). GGUF via llama.cpp (Metal) is the alternative.                                                                                                                                                                                                                                                                                                               | HF blog, Ollama                                                                                 |
| **Datacenter H100/H200/B200**               | BF16 with vLLM: 31B on 1x80 GB minimum per the recipe table, TP2 for headroom; 26B A4B on 1x80 GB. Add MTP assistants for latency. TensorRT-LLM PyTorch backend is the other supported path. No B200-specific Gemma 4 guidance was found.                                                                                                                                                                                                                                                                        | vLLM recipe, TensorRT-LLM docs                                                                  |
| **AMD / TPU / Xeon 6**                      | vLLM recipe has ROCm (MI300X-MI355X), Cloud TPU (`vllm/vllm-tpu:gemma4`) and Xeon 6 containers.                                                                                                                                                                                                                                                                                                                                                                                                                  | vLLM recipe                                                                                     |

## Context

- Native: 128K (E2B, E4B), 256K (12B, 26B A4B, 31B). No YaRN or extension scheme is described on the model card.
- vLLM's recipe examples use 8K to 32K `--max-model-len` for memory; raise it deliberately and use `--kv-cache-dtype fp8` on tight GPUs.
- Long-context quality (MRCR v2 8-needle at 128K): 31B 66.4%, 26B A4B 44.1%, 12B 43.4%, E4B 25.4%, E2B 19.1%.
- Vision: 70-1120 token budget per image. Audio max 30 s. Video max 60 s at 1 fps.

## Sources

- [Gemma 4 overview](https://ai.google.dev/gemma/docs/core)
- [vLLM Gemma 4 recipe](https://docs.vllm.ai/projects/recipes/en/latest/Google/Gemma4.html)
- [nvidia/Gemma-4-31B-IT-NVFP4](https://huggingface.co/nvidia/Gemma-4-31B-IT-NVFP4/blob/main/README.md)
- [NVIDIA forum: Gemma 4 on DGX Spark](https://forums.developer.nvidia.com/t/gemma-4-day-1-inference-on-nvidia-dgx-spark-preliminary-benchmarks/365503/16)
- [HF blog: Welcome Gemma 4](https://huggingface.co/blog/gemma4)
