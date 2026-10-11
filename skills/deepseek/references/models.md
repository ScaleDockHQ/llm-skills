# DeepSeek models

> Verified against deepseek-ai Hugging Face cards (V4.1-Flash, V4-Flash-0731, V4-Pro-0813, V4-Flash-Vision-Exp, V3.2, R1), vLLM recipes, SGLang cookbook, 2026-10-11

## Current generations

| Repo                                                                                                          | Type                                             | Total / active                                                                           | Context                                         | Notes                                                                                                                                                                                    |
| ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`deepseek-ai/DeepSeek-V4.1-Flash`](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash)                   | Multimodal (image+text in, text out) MoE         | 552B backbone plus 196B Engram memory; 8B active per prefill token, 16B per decode token | 1,048,576 (YaRN factor 16 over a 65,536 window) | `DeepseekV41ForCausalLM`. 384 routed experts, top-6, plus 1 shared. Experts MXFP4, dense MXFP8. About 476 GiB on disk. Continuous reasoning effort 1-100. DSpark draft attached, no MTP. |
| [`deepseek-ai/DeepSeek-V4-Flash-0731`](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731)             | Text MoE, official release of Flash (2026-07-31) | 284B / 13B                                                                               | 1M                                              | Supersedes the preview. DSpark attached, no MTP head. Efforts `low`, `high`, `max`.                                                                                                      |
| [`deepseek-ai/DeepSeek-V4-Pro-0813`](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro-0813)                 | Text MoE, official release of Pro (2026-08-13)   | 1.6T / 49B                                                                               | 1M                                              | Supersedes the preview. DSpark attached. Efforts `low`, `high`, `max`.                                                                                                                   |
| [`deepseek-ai/DeepSeek-V4-Flash-Vision-Exp`](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-Vision-Exp) | Experimental multimodal                          | 0731 base plus vision encoder                                                            | 1M                                              | First V4 multimodal checkpoint, before V4.1. Needs preview builds on SGLang.                                                                                                             |

Sizes come from the cards. The Hugging Face tensor counts (V4.1-Flash 763B, V4-Flash-0731 304B) include the Engram tables or the DSpark module and are larger than the headline backbone numbers.

## Preview and companion checkpoints

| Repo                                                                            | What it is                                                                                                        |
| ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `deepseek-ai/DeepSeek-V4-Flash`, `DeepSeek-V4-Pro`                              | April 2026 previews (2026-04-24). FP4 experts plus FP8 elsewhere. MTP head. Kept for reproducing earlier results. |
| `deepseek-ai/DeepSeek-V4-Flash-DSpark`, `DeepSeek-V4-Pro-DSpark`                | Preview weights with a fused DSpark module. Not new weights.                                                      |
| `deepseek-ai/DeepSeek-V4-Flash-Base`, `DeepSeek-V4-Pro-Base`                    | Base models, pure FP8. For further pre-training, not chat or tools.                                               |
| `deepseek-ai/dspark_*`, `dflash_*`, `eagle3_*` (Qwen3 4B, 8B, 14B, Gemma 4 12B) | DeepSpec draft models for other families, not DeepSeek chat models.                                               |

## Older generations (still served)

| Repo                                                                    | Total / active | Context                                                | Parser and sampling notes                                                                                                       |
| ----------------------------------------------------------------------- | -------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| `deepseek-ai/DeepSeek-V3.2` (2025-12-01)                                | 685B           | 163,840 (YaRN factor 40)                               | Own encoding folder (`encoding_dsv32`). `temperature=1.0`, `top_p=0.95`. vLLM tool parser `deepseek_v32`, SGLang `deepseekv32`. |
| `deepseek-ai/DeepSeek-V3.2-Speciale`                                    | Same           | Same                                                   | Deep reasoning only. The card says it does not support tool calling.                                                            |
| `deepseek-ai/DeepSeek-V3.2-Exp`                                         | Same           |                                                        | Introduced the sparse indexer.                                                                                                  |
| `deepseek-ai/DeepSeek-V3.1`, `V3.1-Terminus`                            | 685B           |                                                        | vLLM `deepseek_v31` tool parser with its example template; reasoning off by default, enable with `thinking=True`.               |
| `deepseek-ai/DeepSeek-R1-0528`                                          | 671B / 37B     | 128K per the R1 card; 64K max generation in benchmarks | System prompt supported. `temperature=0.6`, `top_p=0.95`.                                                                       |
| `deepseek-ai/DeepSeek-R1-0528-Qwen3-8B`                                 | 8B dense       |                                                        | Distilled onto Qwen3 8B.                                                                                                        |
| `deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B/7B/14B/32B`, `-Llama-8B/70B` | Dense          |                                                        | Avoid a system prompt, `temperature=0.6`, start the response with `<think>\n`.                                                  |

## Licenses

All DeepSeek cards read here state the MIT License for code and weights (V4.1, V4-0731, V4-0813, V3.2, R1, distills). R1 distills inherit their base licence: Qwen2.5 distills Apache 2.0, `Llama-8B` the Llama 3.1 licence, `Llama-70B` the Llama 3.3 licence. Third-party quants (Unsloth, NVIDIA, MLX community) repeat MIT in their cards.

## Official and well-known quants

| Source          | Repos                                                                                                                                                     | Notes                                                                                                             |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| DeepSeek native | all V4.x instruct repos                                                                                                                                   | Experts already FP4 (V4) or MXFP4 (V4.1) plus FP8/MXFP8. There is no larger BF16 release to quantize from for V4. |
| NVIDIA ModelOpt | `nvidia/DeepSeek-V4.1-Flash-NVFP4`, `nvidia/DeepSeek-V4-Flash-0731-NVFP4`, `nvidia/DeepSeek-V4-Pro-0813-NVFP4` (plus preview NVFP4 repos)                 | NVFP4 experts, attention in FP8. Blackwell only. The V4.1 card lists vLLM and SGLang, tested on GB300.            |
| SGLang project  | `sgl-project/DeepSeek-V4-Flash-FP8`, `sgl-project/DeepSeek-V4-Pro-FP8`                                                                                    | FP8 repack for H100 and H200, per the SGLang cookbook.                                                            |
| Unsloth         | `unsloth/DeepSeek-V4-Flash-0731-GGUF`, `unsloth/DeepSeek-V4-Pro-0813-GGUF`, `unsloth/DeepSeek-V4-Flash-Vision-Exp-GGUF`, `unsloth/DeepSeek-V4-Flash-GGUF` | `UD-Q8_K_XL` (162 GB) is bit-identical to the official weights per Unsloth's check. No Unsloth V4.1 GGUF found.   |
| MLX community   | `mlx-community/DeepSeek-V4.1-Flash-MLX-4bit`, `-MLX-2bit`, `DeepSeek-V4.1-Flash-DSpark-drafter`, and V4-Flash/Pro bit-width repos                         | Community conversions, not DeepSeek releases.                                                                     |

## Sources

- <https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash>
- <https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731>
- <https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro-0813>
- <https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-Vision-Exp>
- <https://huggingface.co/blog/deepseekv4>
- <https://huggingface.co/deepseek-ai/DeepSeek-V3.2>
- <https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-32B>
- <https://huggingface.co/deepseek-ai/DeepSeek-R1-0528>
- <https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4-Flash>
- <https://docs.sglang.io/cookbook/autoregressive/DeepSeek/DeepSeek-V4>
- <https://unsloth.ai/docs/models/deepseek-v4>
