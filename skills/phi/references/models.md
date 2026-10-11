# Phi models: generations, sizes, context, licenses

> Verified against Hugging Face `microsoft/*` Phi model cards and Hub listing, Ollama library pages, vLLM supported-models doc (vLLM v0.31.0), 2026-10-11

Every Phi checkpoint below is dense unless marked MoE, text-in/text-out unless marked, and **MIT**-licensed on the
Microsoft repo (each card's `license: mit`). Microsoft has published no Phi generation newer than Phi-4 as of
2026-10-11: the newest repo on the Hub is `Phi-4-reasoning-vision-15B` (created 2026-01-23, card release date March 4, 2026).
No "Phi-5" repo exists under `microsoft/` (Hub search `author=microsoft&search=phi`, 2026-10-11).

## Current generation (Phi-4 family)

| Model                                                                                                 | Params                                                | Context (card)            | Modality                | Released   | Notes                                              |
| ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------- | ----------------------- | ---------- | -------------------------------------------------- |
| [`microsoft/phi-4`](https://huggingface.co/microsoft/phi-4)                                           | 14B dense                                             | 16K                       | text                    | 2024-12-12 | ChatML-style template, no tool format              |
| [`microsoft/Phi-4-reasoning`](https://huggingface.co/microsoft/Phi-4-reasoning)                       | 14B dense                                             | 32K                       | text                    | 2025-04-30 | SFT on CoT traces; `<think>` block then solution   |
| [`microsoft/Phi-4-reasoning-plus`](https://huggingface.co/microsoft/Phi-4-reasoning-plus)             | 14B dense                                             | 32K (card: tested to 64K) | text                    | 2025-04    | Phi-4-reasoning plus RL                            |
| [`microsoft/Phi-4-mini-instruct`](https://huggingface.co/microsoft/Phi-4-mini-instruct)               | 3.8B dense                                            | 128K                      | text                    | 2025-02    | Function calling; 200064 vocab; 23 languages       |
| [`microsoft/Phi-4-mini-reasoning`](https://huggingface.co/microsoft/Phi-4-mini-reasoning)             | 3.8B dense                                            | 128K                      | text                    | 2025-04    | Math-only reasoning, English                       |
| [`microsoft/Phi-4-mini-flash-reasoning`](https://huggingface.co/microsoft/Phi-4-mini-flash-reasoning) | 3.8B hybrid (SSM + attention, `Phi4FlashForCausalLM`) | 64K (card)                | text                    | 2025-06    | Math-only; needs `mamba-ssm`; see known-issues.md  |
| [`microsoft/Phi-4-multimodal-instruct`](https://huggingface.co/microsoft/Phi-4-multimodal-instruct)   | 5.6B                                                  | 128K                      | text + image + audio in | 2025-02    | Mini backbone plus speech and vision LoRAs         |
| [`microsoft/Phi-4-reasoning-vision-15B`](https://huggingface.co/microsoft/Phi-4-reasoning-vision-15B) | 15B (Phi-4-reasoning + SigLIP-2)                      | 16,384                    | text + image in         | 2026-03-04 | Hybrid think/nothink; GUI grounding; English-first |

Smaller or older, still on the Hub: `Phi-tiny-MoE-instruct` (3.8B total, 1.1B active, 4K context) and
`Phi-mini-MoE-instruct` (7.6B total, 2.4B active, 4K context), both released 2025-06 and distilled from Phi-3.5-MoE.
Phi-3 / Phi-3.5 (mini, small, medium, vision, MoE) and phi-1/1.5/2 are legacy; use them only for compatibility.

### Per-model facts worth knowing

- **Phi-4-mini family** config: `max_position_embeddings` 131072 with `longrope` scaling, `original_max_position_embeddings` 4096
  (`config.json`). Knowledge cutoff June 2024 (instruct); Phi-4-mini-reasoning cutoff February 2025.
- **Phi-4-reasoning / plus / vision** config: `max_position_embeddings` 32768 (text) with no rope scaling. The vision card
  caps `tokenizer_model_max_length` at 16384 and says context is 16,384 tokens.
- **Phi-4-mini-flash-reasoning**: `max_position_embeddings` 262144 and sliding window 512 in `config.json`, but the card
  states 64K context. Trust the card unless you test.
- **Phi-4-reasoning-vision-15B**: SigLIP-2 encoder (`google/siglip2-so400m-patch16-naflex`), dynamic resolution up to 3,600
  visual tokens (`max_num_patches` 3600, `min_num_patches` 256), `Phi4ForCausalLMV` architecture, `custom_code` on the Hub.
  Card benchmark highlights: ScreenSpot-V2 88.2, ChartQA 83.3, MathVista (mini) 75.2.
- **Phi-4-multimodal-instruct languages**: text in 23 languages; vision English; audio English, Chinese, German, French,
  Italian, Japanese, Spanish, Portuguese.
- Phi models are English-first. Cards say non-English performance degrades and that Python is the main code language.

## Official packaging

| Artifact            | Repos (all `microsoft/`)                                                                                                                                     | Notes                                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| ONNX (ONNX Runtime) | `phi-4-onnx`, `Phi-4-mini-instruct-onnx`, `Phi-4-mini-reasoning-onnx`, `Phi-4-reasoning-onnx`, `Phi-4-reasoning-plus-onnx`, `Phi-4-multimodal-instruct-onnx` | Updated 2026-02-11; int4 CPU/GPU variants  |
| GGUF                | `phi-4-gguf` (Q2_K to Q8_0, bf16, IQ and TQ variants)                                                                                                        | Only plain Phi-4 has an official GGUF repo |
| NVIDIA ModelOpt     | see platforms-and-quants.md                                                                                                                                  | `nvidia/` org, not Microsoft               |

## Other Phi-branded repos (not general chat models)

`microsoft/Phi-Ground` and `Phi-Ground-Any` (GUI grounding, 2025-08 and 2026-05) and `paza-Phi-4-multimodal-instruct`
(speech fine-tune) exist. Their cards were not read for this skill; treat their details as **unverified**.

## Hosted

Azure AI Foundry hosts the Phi-4 family (the vision card links a Foundry deployment). Ollama library tags: `phi4` (9.1GB,
16K), `phi4-mini` (2.5GB, 128K, tools), `phi4-reasoning` (11GB, 32K; reasoning and reasoning-plus), `phi4-mini-reasoning`
(3.2GB, 128K). There is no Ollama library page for Phi-4-reasoning-vision (HTTP 404 on `phi4-reasoning-vision`) or for
Phi-4-multimodal.

## Sources

- https://huggingface.co/microsoft/phi-4
- https://huggingface.co/microsoft/Phi-4-reasoning
- https://huggingface.co/microsoft/Phi-4-reasoning-plus
- https://huggingface.co/microsoft/Phi-4-mini-instruct
- https://huggingface.co/microsoft/Phi-4-mini-reasoning
- https://huggingface.co/microsoft/Phi-4-mini-flash-reasoning
- https://huggingface.co/microsoft/Phi-4-multimodal-instruct
- https://huggingface.co/microsoft/Phi-4-reasoning-vision-15B
- https://huggingface.co/microsoft/Phi-tiny-MoE-instruct
- https://huggingface.co/microsoft/Phi-mini-MoE-instruct
- https://ollama.com/library/phi4-mini
