# Qwen models

> Verified against Hugging Face Qwen org listing and model cards (Qwen3.8-27B, Qwen3.8-Flash-Next, Qwen3.8-2.4T-A95B, Qwen3.6-35B-A3B, Qwen3.5-397B-A17B and 9B, Qwen3-Coder-Next, Qwen3-32B, Qwen3-Omni-30B-A3B), QwenLM/Qwen3.8 and Qwen3.8-Flash-Next READMEs, 2026-10-11

Qwen3.5, 3.6 and 3.8 share one architecture family (hybrid Gated DeltaNet plus attention, vision-language, `Qwen3_5ForConditionalGeneration` or `Qwen3_5MoeForCausalLM` in config). The GitHub repo `QwenLM/Qwen3.8` covers all three. Flash-Next is a newer architecture (`qwen4_exp`).

## Current generation (open weights)

| Model (HF id)                        | Type                   | Params (active)                                             | Context                            | License                                           | Released            | Notes                                                                                                            |
| ------------------------------------ | ---------------------- | ----------------------------------------------------------- | ---------------------------------- | ------------------------------------------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `Qwen/Qwen3.8-27B` (+ `-FP8`)        | dense, vision-language | 27B                                                         | 262,144 native, 1M with YaRN       | Apache-2.0                                        | 2026-08-14          | Thinking on by default, `reasoning_effort`, `preserve_thinking`, MTP head                                        |
| `Qwen/Qwen3.8-Flash-Next` (+ `-FP8`) | MoE, vision-language   | 125B total, 6B active, plus 51B n-gram embedding and 4B MTP | 262,144 native, 1M with YaRN       | Qwen Community License 1.0 (`qwen-community-1.0`) | 2026-08-24 to 08-26 | Qwen4 architecture preview: GDN + Qwen Sparse Attention (QSA), gated residual. 512 experts, 10 routed + 1 shared |
| `Qwen/Qwen3.8-2.4T-A95B` (+ `-FP8`)  | MoE, text only         | 2.4T total, 95B active                                      | 262,144 native, 1,010,000 extended | Qwen3.8-Max License (`qwen3.8-max`)               | 2026-08-12          | Thinking cannot be disabled. 92 layers, 512 experts, 10 routed + 1 shared                                        |

Hosted-only names that have no open weights: Qwen3.8-Max (hosted version based on the 2.4T, adds vision input, non-thinking mode, 1M default context, built-in tools), Qwen3.8-Flash (hosted version of Flash-Next), Qwen3.7-Plus. Use `cloud-llms` for those.

## Previous generations still in use

| Model                                                    | Type                   | Params (active)     | Context                            | License                                            | Notes                                                                          |
| -------------------------------------------------------- | ---------------------- | ------------------- | ---------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------ |
| `Qwen/Qwen3.6-35B-A3B` (+ `-FP8`)                        | MoE, vision-language   | 35B (3B)            | 262,144 native, 1,010,000 extended | Apache-2.0                                         | 2026-04-16. 256 experts, 8 routed + 1 shared. Adds `preserve_thinking`         |
| `Qwen/Qwen3.6-27B` (+ `-FP8`)                            | dense, vision-language | 27B                 | 262,144 native                     | Apache-2.0                                         | 2026-04-22                                                                     |
| `Qwen/Qwen3.5-397B-A17B` (+ `-FP8`, `-GPTQ-Int4`)        | MoE, vision-language   | 397B (17B)          | 262,144 native, 1,010,000 extended | Apache-2.0                                         | 2026-02-16. Hosted twin: Qwen3.5-Plus                                          |
| `Qwen/Qwen3.5-122B-A10B` (+ `-FP8`, `-GPTQ-Int4`)        | MoE                    | 122B (10B)          | 262,144                            | not checked (sibling Qwen3.5 cards are Apache-2.0) | 2026-02-24                                                                     |
| `Qwen/Qwen3.5-35B-A3B` (+ `-FP8`, `-GPTQ-Int4`, `-Base`) | MoE                    | 35B (3B)            | 262,144                            | not checked (sibling Qwen3.5 cards are Apache-2.0) | 2026-02-24                                                                     |
| `Qwen/Qwen3.5-27B` (+ `-FP8`, `-GPTQ-Int4`)              | dense                  | 27B                 | 262,144                            | Apache-2.0                                         | 2026-02-24                                                                     |
| `Qwen/Qwen3.5-9B`, `-4B`, `-2B`, `-0.8B` (+ `-Base`)     | dense, vision-language | 9B / 4B / 2B / 0.8B | 262,144 native (9B card)           | Apache-2.0 (9B)                                    | 2026-02-27 to 03-02                                                            |
| `Qwen/Qwen3-Coder-Next` (+ `-FP8`, `-GGUF`, `-Base`)     | MoE, text              | 80B (3B)            | 262,144                            | Apache-2.0                                         | 2026-02-03. Non-thinking only, no `<think>` blocks. 512 experts, 10 + 1 shared |

Qwen3.5 cards call 262,144 the default context and advise keeping at least 128K so the thinking capability is preserved (same advice on the 3.6 card).

## Older Qwen3 line (2025, still downloaded)

| Model                                                                                      | Notes                                                                                                                                                                                     |
| ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Qwen/Qwen3-0.6B` to `Qwen3-32B`, `Qwen3-30B-A3B`, `Qwen3-235B-A22B`                       | Hybrid thinking, `enable_thinking` and `/think` `/no_think` soft switches. 32B card: 32,768 native, 131,072 with YaRN. Sizes beyond the card read: not individually verified              |
| `Qwen3-*-2507` (4B, 30B-A3B, 235B-A22B Instruct and Thinking, with FP8)                    | Split instruct and thinking checkpoints. Cards not read                                                                                                                                   |
| `Qwen/Qwen3-Next-80B-A3B-Instruct` and `-Thinking` (+ FP8, GGUF)                           | First hybrid GDN model (2025-09-11), Apache-2.0 tag on Instruct                                                                                                                           |
| `Qwen/Qwen3-Coder-480B-A35B-Instruct` and `Qwen3-Coder-30B-A3B-Instruct` (+ FP8)           | Apache-2.0 tag on 480B                                                                                                                                                                    |
| `Qwen/Qwen3-VL-*` (2B to 235B-A22B, Instruct and Thinking, FP8 and GGUF)                   | Vision-language, superseded by the native VL in 3.5 and later                                                                                                                             |
| `Qwen/Qwen3-Omni-30B-A3B-Instruct`, `-Thinking`, `-Captioner`                              | Audio, image, video and text in, speech and text out (Instruct). `license: other` tag with `license_name: apache-2.0` in the card metadata. No newer Omni model exists in the org listing |
| `Qwen/Qwen3Guard-*`, `Qwen3-Embedding-*`, `Qwen3-Reranker-*`, `Qwen3-ASR-*`, `Qwen3-TTS-*` | Safety, retrieval, speech. Not covered here                                                                                                                                               |

## Other 2026 releases (listed, cards not read)

`Qwen/Qwen-AgentWorld-35B-A3B` (Apache-2.0 tag), `Qwen/Qwen-Drive-1.0-4B` (Apache-2.0 tag), `Qwen/WebWorld-8B|14B|32B`, `Qwen/Qwen-Image-2.1*` (images; see `self-hosted-genmedia`). Check the cards before using them.

## Architecture facts that affect serving

- **Linear attention dominates.** 27B: 48 of 64 layers are Gated DeltaNet, so KV cache is small and a recurrent state pool matters instead (SGLang: `--mamba-*` flags, TensorRT-LLM: `kv_cache_config.mamba_ssm_cache_dtype`).
- **Vision tower is bundled** in 27B, Flash-Next and the 3.5 to 3.6 checkpoints. Skip it for text-only serving with vLLM `--language-model-only`.
- **MTP head ships in the checkpoint** (3.5 and later) for speculative decoding. See `platforms-and-quants.md`.
- **Flash-Next n-gram embedding** is a 51B lookup table that can be offloaded to host RAM (vLLM `VLLM_PLE_CPU_OFFLOAD=1`, NVIDIA only); it needs at least 51 GB of host RAM plus headroom.
- **Token embedding 248,320 (padded)** on 3.8 models.

## License notes (not legal advice)

- Apache-2.0: 3.8-27B, 3.6, 3.5 (cards read), Coder-Next, Next-80B (tag). Free for commercial use and hosting.
- Qwen Community License 1.0 (Flash-Next): MIT-style grant, but products with more than 100M monthly active users or US$20M monthly revenue must show the model name in the UI, and a Model-as-a-Service or AI Work Assistant business (API/hosted endpoint offered to third parties, or independent coding/office assistant products) must obtain a separate license from Qwen before commercial use. Internal use is exempt.
- Qwen3.8-Max License (2.4T): same attribution rule; the separate-license requirement applies only to MaaS or AI Work Assistant licensees whose (with affiliates) revenue exceeds US$50M over any 12 months. Contact address is in the LICENSE file.
- Third-party quants (Unsloth, NVIDIA, Inferact, RadixArk, MLX community) inherit the base license; NVIDIA's 27B NVFP4 states Apache-2.0.

## Sources

- https://github.com/QwenLM/Qwen3.8
- https://github.com/QwenLM/Qwen3.8-Flash-Next
- https://huggingface.co/Qwen/Qwen3.8-27B
- https://huggingface.co/Qwen/Qwen3.8-27B-FP8
- https://huggingface.co/Qwen/Qwen3.8-Flash-Next
- https://huggingface.co/Qwen/Qwen3.8-2.4T-A95B
- https://huggingface.co/Qwen/Qwen3.8-2.4T-A95B/blob/main/LICENSE
- https://huggingface.co/Qwen/Qwen3.8-Flash-Next/blob/main/LICENSE
- https://huggingface.co/Qwen/Qwen3.6-35B-A3B
- https://huggingface.co/Qwen/Qwen3.5-397B-A17B
- https://huggingface.co/Qwen/Qwen3.5-9B
- https://huggingface.co/Qwen/Qwen3-Coder-Next
- https://huggingface.co/Qwen/Qwen3-32B
- https://huggingface.co/Qwen/Qwen3-Omni-30B-A3B-Instruct
- https://www.alibabacloud.com/blog/alibaba-unveils-qwen3-8-27b-and-releases-weights-of-qwen3-8-flagship-model_603463
- https://huggingface.co/api/models?author=Qwen&sort=createdAt&direction=-1
