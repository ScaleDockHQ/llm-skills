# Meta models: generations, sizes, licenses

> Verified against Muse Glimmer model card (Hugging Face, August 2026), Llama 4 and Llama 3.3 model cards, Meta AI blog posts, Ollama library pages, vLLM recipes, 2026-10-11

## What is current on 2026-10-11

| Family                      | Status                                                                           | Open weights                                     | Source                                                                                                                                                                       |
| --------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Muse Glimmer** (30B)      | Newest open Meta model, released 2026-08-10                                      | Yes, Apache 2.0                                  | [Meta blog](https://research.meta.ai/blog/introducing-muse-glimmer-open-agentic-model), [model card](https://huggingface.co/meta-models/Muse-Glimmer-30B)                    |
| **Muse Spark** / Spark 1.1  | Meta's frontier models (2026-04-08 and 2026-07-09)                               | No. App and Meta Model API (public preview) only | [Spark](https://about.fb.com/news/2026/04/introducing-muse-spark-meta-superintelligence-labs/), [Spark 1.1](https://ai.meta.com/blog/introducing-muse-spark-meta-model-api/) |
| **Llama 4** Scout, Maverick | Newest models named "Llama" (2025-04-05); Behemoth was previewed, never released | Yes, Llama 4 Community License                   | [Meta blog](https://ai.meta.com/blog/Llama-4-multimodal-intelligence/), [HF org](https://huggingface.co/meta-llama)                                                          |
| Llama 3.3 70B, 3.2, 3.1     | Previous generation, still on the Hugging Face org                               | Yes, version-specific community licenses         | [HF org](https://huggingface.co/meta-llama)                                                                                                                                  |

No newer "Llama" release than Llama 4 was found. Meta's HF org page still lists Llama 4 as "Current". Muse Glimmer lives in a different HF org, `meta-models`. Treat "Llama" requests as a family request: ask what the user needs (agent, vision, long context, fine-tune) and map to a row below.

## Muse Glimmer 30B

| Item              | Value                                                                                                                             |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Repo              | `meta-models/Muse-Glimmer-30B` (BF16, about 60 GB)                                                                                |
| Architecture      | Dense causal transformer, ~29.6B parameters including a ~1.8B ViT-G/14 perception encoder (`MuseGlimmerForCausalLM` in vLLM docs) |
| Layers, attention | 52 layers; 3 local (window 2048) + 1 global layer repeating; GQA 32 query / 2 KV heads, head dim 128                              |
| Context           | 131,072+ (128K trained); knowledge cutoff 2026-01-04                                                                              |
| Modalities        | Text and images in, text out. Up to 4,096 visual tokens per image. Video is processed as frames. No audio                         |
| Tools             | Native ATEM format, one tool call per turn, no parallel calls                                                                     |
| Reasoning         | Always on. Strength via system prompt line `Reasoning strength: low\|medium\|high\|xhigh` (template default `high`)               |
| Sampling          | `temperature=1.0, top_p=0.95, top_k=64`. Do not run greedy                                                                        |
| License           | Apache 2.0                                                                                                                        |
| Languages         | 100+ in training data                                                                                                             |

Official and partner artifacts (all verified on the pages linked in `metadata.json`):

| Artifact                                  | Repo                                                                                            | Size       | Use                                                                     |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------- |
| GGUF K-quant 17GB (`Q4_K_M`)              | `meta-models/Muse-Glimmer-30B-GGUF`                                                             | ~17 GB     | llama.cpp on 24 GB VRAM                                                 |
| GGUF K-quant dynamic (`Q4_K_XL`)          | same repo                                                                                       | ~20 GB     | llama.cpp on 32 GB VRAM, higher quality                                 |
| Vision projector `mmproj-...-Q4_K_M.gguf` | same repo                                                                                       | ~1.4 GB    | image input in llama.cpp                                                |
| DFlash GGUF draft                         | same repo                                                                                       | ~1.6 GB    | speculative decoding in llama.cpp                                       |
| DFlash draft head (safetensors)           | `meta-models/Muse-Glimmer-30B-assistant`                                                        | 5.11 GB    | vLLM / SGLang / Edge-LLM speculative decoding                           |
| ExecuTorch exports                        | `meta-models/Muse-Glimmer-30B-ExecuTorch-PTE`                                                   | 16 exports | on-device                                                               |
| FP8 block-scaled                          | `RedHatAI/Muse-Glimmer-30B-FP8-block`                                                           | 32.78 GB   | vLLM on Hopper/Blackwell (partner)                                      |
| NVFP4 W4A4 (ModelOpt)                     | `Inferact/Muse-Glimmer-30B-NVFP4-W4A4`                                                          | 25.42 GB   | vLLM on Blackwell (partner; Blackwell-only kernels)                     |
| NVFP4 + MXFP8                             | `RadixArk/Muse-Glimmer-NVFP4`                                                                   | not stated | SGLang and TensorRT Edge-LLM (partner, text only)                       |
| MLX Q4 variants                           | `RadixArk/Muse-Glimmer-q4-MLX`, `...-q4km-gs128-MLX`, `...-q4k-dynamic-MLX`                     | not stated | SGLang MLX backend, text only (partner)                                 |
| MLX 4-bit, oQ6                            | `TensorFold/Muse-Glimmer-30B-MLX-4bit` (19.41 GB), `TensorFold/Muse-Glimmer-30B-oQ6` (27.22 GB) |            | MLX-VLM, text and images (partner HF repos, not the TensorFold runtime) |
| Ollama                                    | `muse-glimmer`, `muse-glimmer:30b`, `muse-glimmer:30b-mlx`                                      |            | Ollama                                                                  |

Meta's own degradation figures vs full precision (average over 15 benchmarks): K-Quant-Dynamic 0.2% (32 GB VRAM), K-Quant-17GB 1.0% (24 GB VRAM). Full precision targets 64 GB VRAM.

## Llama 4

From the [Scout card](https://huggingface.co/meta-llama/Llama-4-Scout-17B-16E-Instruct) and [Ollama page](https://ollama.com/library/llama4).

| Model            | Total / active | Experts | Context (card) | Input                                 | Pretraining | Cutoff      |
| ---------------- | -------------- | ------- | -------------- | ------------------------------------- | ----------- | ----------- |
| Llama 4 Scout    | 109B / 17B     | 16      | 10M            | Text + images (tested up to 5 images) | ~40T tokens | August 2024 |
| Llama 4 Maverick | ~400B / 17B    | 128     | 1M             | Text + images                         | ~22T tokens | August 2024 |

- Official repos (gated, accept the license first): `meta-llama/Llama-4-Scout-17B-16E-Instruct`, `meta-llama/Llama-4-Scout-17B-16E` (base), `meta-llama/Llama-4-Maverick-17B-128E-Instruct`, `meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8`. There is no official Maverick base repo listed on the org page and no official Scout FP8 from Meta.
- Meta states Scout fits one H100 with on-the-fly int4; Maverick FP8 fits one H100 DGX host.
- Languages: Arabic, English, French, German, Hindi, Indonesian, Italian, Portuguese, Spanish, Tagalog, Thai, Vietnamese (12; pretraining covered 200).
- No thinking mode or reasoning toggle is documented on the card. Llama 4 is a non-reasoning instruct model.
- Quantized artifacts found: NVIDIA `nvidia/Llama-4-Scout-17B-16E-Instruct-FP4` (ModelOpt, TensorRT-LLM, licensed under the NVIDIA Open Model License plus the Llama 4 license; FP8 variants `nvidia/Llama-4-Scout-17B-16E-Instruct-FP8` and `nvidia/Llama-4-Maverick-17B-128E-Instruct-FP8` are referenced by TensorRT-LLM docs), RedHat AI FP8 and NVFP4 variants (listed on the vLLM recipe), Unsloth GGUFs (`unsloth/Llama-4-Scout-17B-16E-Instruct-GGUF`, UD and Q4_K_M files), Ollama `llama4:16x17b` (67 GB, 10M) and `llama4:128x17b` (245 GB, 1M).

## Llama 3.x (older, text mostly)

| Model        | Sizes                        | Context         | Notes                                                                |
| ------------ | ---------------------------- | --------------- | -------------------------------------------------------------------- |
| Llama 3.3    | 70B instruct                 | 128K            | Text only, cutoff December 2023, license Llama 3.3 Community License |
| Llama 3.2    | 1B, 3B text; 11B, 90B vision | not re-verified | HF org collection                                                    |
| Llama 3.1    | 8B to 405B                   | not re-verified | HF org collection                                                    |
| Guard models | Llama Guard 3, Prompt Guard  |                 | safeguard classifiers on the HF org                                  |

## Licenses

| Model              | License                                                                                                 | Practical effects                                                                                                                                                                                                                |
| ------------------ | ------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Muse Glimmer       | Apache 2.0                                                                                              | Commercial use, no attribution prefix, no MAU clause. Model card forbids use by under-18 individuals in its limitations section; read it for your deployment                                                                     |
| Llama 4            | [Llama 4 Community License](https://github.com/meta-llama/llama-models/blob/main/models/llama4/LICENSE) | "Built with Llama" notice, ship the license and NOTICE text, derived AI models must start with "Llama", licence from Meta if over 700M MAU on the release date, acceptable-use policy applies, litigation clause. Gated download |
| Llama 3.3          | Llama 3.3 Community License                                                                             | Same shape as Llama 4 (700M MAU clause, "Built with Llama")                                                                                                                                                                      |
| NVIDIA Llama 4 FP4 | NVIDIA Open Model License plus Llama 4 license                                                          | Card says "Deployment Geography: Global, except in European Union"                                                                                                                                                               |

The Llama 3.3 acceptable-use policy contains an EU restriction for multimodal models included in that release. Whether Llama 4's acceptable-use policy carries an EU restriction for its multimodal weights was not re-read: check <https://www.llama.com/llama4/use-policy> before an EU deployment.
