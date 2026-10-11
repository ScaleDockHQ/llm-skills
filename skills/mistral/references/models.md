# Mistral open-weight models

> Verified against the mistralai Hugging Face org, Mistral docs model overview, Mistral Large 4 announcement and the model cards linked below, 2026-10-11

Everything here was read on 2026-10-11. Mistral rotates names fast: the unified Small 4 and Medium 3.5
replaced the separate Magistral (reasoning) and Devstral (coding) lines.

## Current generations

| Family                  | HF repo                                                            | Shape                                                                             | Context                    | License                                                 | Notes                                                                                                                                       |
| ----------------------- | ------------------------------------------------------------------ | --------------------------------------------------------------------------------- | -------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Mistral Large 4         | `mistralai/Mistral-Large-4.0-1T05-A52B`                            | MoE, 1.05T total, 49B active per token (52B with embeddings), 1.6B vision encoder | 1M (API docs)              | unverified                                              | **Weights not released on 2026-10-11.** HF page says "Upcoming release", October 31, 2026. API preview only. Do not plan a download.        |
| Mistral Medium 3.5      | `mistralai/Mistral-Medium-3.5-128B`                                | Dense 128B, vision, hybrid reasoning                                              | 256k (YaRN over a 4K base) | Modified MIT (free except companies with large revenue) | Replaces Medium 3.1, Magistral and Devstral 2 on Mistral's side. Native FP8 (about 130 GB). Companion `-EAGLE` draft head.                  |
| Mistral Small 4         | `mistralai/Mistral-Small-4-119B-2603`                              | MoE, 119B total, 6.5B active, 128 experts (4 active), vision, hybrid reasoning    | 256k                       | Apache 2.0                                              | Unifies Instruct, Reasoning (old Magistral) and Devstral. FP8 weights. Companions `-NVFP4` and `-eagle`.                                    |
| Mistral Large 3         | `mistralai/Mistral-Large-3-675B-Instruct-2512`                     | MoE, 675B total, 41B active, vision                                               | 256k                       | Apache 2.0                                              | Not a dedicated reasoning model (card). FP8 on 8xB200/H200, NVFP4 on 8xH100/A100. Companions `-NVFP4`, `-Eagle`.                            |
| Ministral 3             | `mistralai/Ministral-3-{3B,8B,14B}-{Base,Instruct,Reasoning}-2512` | Dense 3B / 8B / 14B (14B = 13.5B LM + 0.4B vision), vision                        | 256k                       | Apache 2.0                                              | Instruct is FP8, Reasoning and Base are BF16. Also `-Instruct-2512-BF16`, official `-GGUF` repos (Instruct and Reasoning) and `-ONNX` (3B). |
| Devstral 2 (2512)       | `mistralai/Devstral-2-123B-Instruct-2512`                          | Dense 123B, coding agent, FP8                                                     | 256k                       | Modified MIT                                            | Mistral points users to Medium 3.5 instead. API model retired 2026-07-31.                                                                   |
| Devstral Small 2 (2512) | `mistralai/Devstral-Small-2-24B-Instruct-2512`                     | Dense 24B, vision, Ministral 3 architecture, FP8                                  | 256k                       | Apache 2.0                                              | Runs on a single RTX 4090 or a 32 GB Mac per the card.                                                                                      |

Other 2026 repos in the org, not covered further here: `Leanstral-1.5-119B-A6B` and `Leanstral-2603` (Small 4
architecture, per the SGLang cookbook), `Shieldstral-1.0-3B` (moderation, Apache 2.0 per Mistral docs),
Voxtral audio models and OCR. License of Leanstral is unverified.

## Which one to pick

| Need                                                                  | Pick                                                          |
| --------------------------------------------------------------------- | ------------------------------------------------------------- |
| Best general/agentic/coding open model you can host on one 8-GPU node | Medium 3.5 (dense, FP8)                                       |
| Cheap per-token quality, long context, 119B in about 60 GB (NVFP4)    | Small 4                                                       |
| Largest Apache 2.0 weights today                                      | Large 3 (wait for Large 4 weights if you can; due 2026-10-31) |
| Edge, laptop, single consumer GPU                                     | Ministral 3 (8B or 14B), Devstral Small 2 for code            |
| Reasoning on small hardware                                           | Ministral 3 Reasoning (separate checkpoints)                  |

## Legacy (still downloadable, off the API)

| Model                                                                                              | Status                                                                                                                                          |
| -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Magistral Small 2509 (`mistralai/Magistral-Small-2509`)                                            | Apache 2.0, 128k context (card: quality may degrade past 40k). Mistral API retired it 2026-07-31 in favour of Small 4.                          |
| Mistral Small 3.2 24B, Devstral Small 1.x, Pixtral, Mixtral 8x7B / 8x22B, Mistral 7B, Mistral Nemo | Retired from the Mistral API per the docs deprecation table. Weights stay on HF. Cards not re-read for this skill, treat details as unverified. |

## Reasoning model shapes

| Model                                     | How reasoning works                                                                                      |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Small 4, Medium 3.5                       | One checkpoint, per-request `reasoning_effort` of `none` or `high` only. See `parsers-and-templates.md`. |
| Ministral 3 Reasoning                     | Separate checkpoint, always reasons; the reference system prompt contains a `[THINK]...[/THINK]` block.  |
| Large 3, Devstral 2, Ministral 3 Instruct | No reasoning mode.                                                                                       |

## Sources

- https://huggingface.co/mistralai
- https://docs.mistral.ai/getting-started/models/models_overview/
- https://mistral.ai/news/mistral-3/
- https://mistral.ai/news/mistral-large-4/
- https://huggingface.co/mistralai/Mistral-Large-4.0-1T05-A52B
- https://huggingface.co/mistralai/Mistral-Medium-3.5-128B
- https://huggingface.co/mistralai/Mistral-Small-4-119B-2603
- https://huggingface.co/mistralai/Mistral-Large-3-675B-Instruct-2512
- https://huggingface.co/mistralai/Ministral-3-14B-Reasoning-2512
- https://huggingface.co/mistralai/Devstral-2-123B-Instruct-2512
- https://huggingface.co/mistralai/Devstral-Small-2-24B-Instruct-2512
- https://huggingface.co/mistralai/Magistral-Small-2509
- https://docs.sglang.io/cookbook/autoregressive/Mistral/Mistral-Medium-3.5
