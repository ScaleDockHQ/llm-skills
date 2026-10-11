# MiniMax models

> Verified against MiniMaxAI Hugging Face org listing (API), MiniMax-M3 and MiniMax-M2.7 model cards and LICENSE files, vLLM recipe for MiniMax-M3, SGLang cookbook, TensorRT-LLM supported-models page, Unsloth guides, Ollama library, 2026-10-11

## Current generations

| Model            | Hugging Face id              | Type                                                 | Total / active                      | Context                   | Input              | Format shipped                | Released (HF `createdAt`) |
| ---------------- | ---------------------------- | ---------------------------------------------------- | ----------------------------------- | ------------------------- | ------------------ | ----------------------------- | ------------------------- |
| MiniMax-M3       | `MiniMaxAI/MiniMax-M3`       | MoE, MiniMax Sparse Attention (MSA), `minimax_m3_vl` | ~428B / ~23B (card)                 | 1M (see notes)            | text, image, video | BF16                          | 2026-06-02                |
| MiniMax-M3 MXFP8 | `MiniMaxAI/MiniMax-M3-MXFP8` | same, MXFP8 weights                                  | same                                | same                      | same               | MXFP8                         | 2026-06-02                |
| MiniMax-M2.7     | `MiniMaxAI/MiniMax-M2.7`     | MoE, `minimax_m2`                                    | ~230B / ~10B                        | 196,608                   | text               | FP8 (card tag `fp8`, ~230 GB) | 2026-04-09                |
| MiniMax-M2.5     | `MiniMaxAI/MiniMax-M2.5`     | MoE, `minimax_m2`                                    | same architecture as M2.7 (Unsloth) | 196K per the deploy guide | text               | FP8                           | 2026-02-12                |
| MiniMax-M2.1     | `MiniMaxAI/MiniMax-M2.1`     | MoE, `minimax_m2`                                    | not re-verified                     | 196K per the deploy guide | text               | FP8                           | 2025-12-20                |
| MiniMax-M2       | `MiniMaxAI/MiniMax-M2`       | MoE, `minimax_m2`                                    | 230B / 10B (card)                   | 196K per the deploy guide | text               | FP8                           | 2025-10-22                |

Rules of thumb:

- **M3 is the flagship**: coding, agents, long context, multimodal. It is 4 to 5x the memory of the M2 line.
- **M2.7 is the practical self-host pick** for one or two 128 GB machines and 4 to 8 GPU servers. M2.5, M2.1 and
  M2 share the engine path with M2.7 (the official vLLM and SGLang guides say "change the model name only").
- Parameter counts differ slightly by source: the M3 card says ~428B / ~23B, the vLLM recipe says 427B / 26B
  active, SGLang says ~428B / 23B (128 experts, 4 active, 60 layers). Use the card, size memory from file sizes.

### M3 architecture facts (SGLang cookbook, TensorRT-LLM guide)

- 60 layers: 3 dense layers, 57 sparse-attention MoE layers; 128 routed experts, top-4, plus 1 shared expert.
- MSA: block-sparse attention with a top-k indexer over 128-token key blocks. This forces `--block-size 128`
  on vLLM and page size 128 on SGLang with the `fa4` backend.
- MiniMax reports ~9x prefill and ~15x decode speedup over M2 at 1M context. No MTP heads in the released weights (llama.cpp PR).
- Context: the card and NVIDIA say 1M. The vLLM recipe uses `context_length: 1048576`, notes native 512K on AMD
  and needs YaRN above that there. Ollama cloud advertises "guaranteed 512K, up to 1M". TensorRT-LLM documents
  `max_position_embeddings` of 512K for the BF16 checkpoint and 1M for MXFP8. Treat 512K as the safe length.

## Weight sizes (use for planning)

| Checkpoint                                   | Size                                                                    | Source                                     |
| -------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------ |
| M3 BF16                                      | ~855 GB weights (Unsloth), 1025 GB (vLLM recipe sizing)                 | Unsloth, vLLM recipe                       |
| M3 MXFP8 (`MiniMaxAI/MiniMax-M3-MXFP8`)      | ~440 GB (SGLang), 513 GB (vLLM recipe sizing)                           | SGLang, vLLM recipe                        |
| M3 NVFP4 (`nvidia/MiniMax-M3-NVFP4`)         | 257 GB (vLLM recipe sizing)                                             | vLLM recipe                                |
| M3 MXFP4 (`amd/MiniMax-M3-MXFP4`)            | 257 GB (vLLM recipe sizing), AMD MI355X                                 | vLLM recipe                                |
| M3 GGUF (`unsloth/MiniMax-M3-GGUF`)          | UD-IQ1_M 128 GB, UD-IQ3_XXS 159 GB, UD-IQ4_XS 208 GB, UD-Q4_K_XL 265 GB | Unsloth                                    |
| M2.7 FP8                                     | ~230 GB                                                                 | community card citing the official release |
| M2.7 NVFP4 (`nvidia/MiniMax-M2.7-NVFP4`)     | ~130 to 140 GB                                                          | community cards, NVIDIA forum              |
| M2.7 GGUF (`unsloth/MiniMax-M2.7-GGUF`)      | UD-IQ4_XS 108 GB, Q8_0 243 GB                                           | Unsloth                                    |
| M2.7 MLX (`mlx-community/MiniMax-M2.7-4bit`) | 128.67 GB, ~157 GB unified memory needed                                | MLX Community catalog                      |

Memory beyond weights (M2 line, official guide): about 240 GB of KV cache per 1M context tokens; 4x96 GB gives
~400K total KV tokens, 8x144 GB gives up to 3M. Per-sequence maximum stays 196K.

## Licenses

All of the current checkpoints use `license: other` on Hugging Face. Read the file for the model you serve.

| Model    | License (from the LICENSE file)             | What matters                                                                                                                                                                                                                                                                                                                                                                                                  |
| -------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| M3       | MiniMax Community License                   | Non-commercial MIT-style grant. Commercial use: show "Built with MiniMax M3"; send a one-time notice to `api@minimax.io` (subject "M3 licensing — notice") if the product earns under USD 20M a year, or get prior written authorization above that. "Commercial use" includes paid services, commercial APIs and any commercially deployed fine-tune. Prohibited-use appendix includes any military purpose. |
| M2.7     | "Non-commercial license" in the GitHub repo | Free for personal use (including self-hosted coding and agents), non-profit and academic research. Any commercial use needs prior written authorization from `api@minimax.io` ("M2.7 licensing") plus the "Built with MiniMax M2.7" credit. Fine-tuned commercial deployments count as commercial.                                                                                                            |
| M2.5, M2 | Modified-MIT per the model cards            | Re-read the repo LICENSE before commercial use. M2.1 license not re-verified.                                                                                                                                                                                                                                                                                                                                 |

Some mirrors (MLX Community catalog) label M2.7 `modified-mit`. The official LICENSE file above wins.
NVIDIA's NVFP4 checkpoints carry their own NVIDIA license on top for M2.7 (`nvidia-software-and-model-evaluation-license`)
and the MiniMax Community License for M3.
Ollama states its cloud is officially licensed with MiniMax for commercial use (`minimax-m3:cloud`, `minimax-m2.7:cloud`).

## Official and vendor quants

| Format             | M3                                                                                                       | M2.7                                                            |
| ------------------ | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| BF16 / FP8         | BF16 (`MiniMaxAI/MiniMax-M3`)                                                                            | FP8 (`MiniMaxAI/MiniMax-M2.7`)                                  |
| MXFP8              | `MiniMaxAI/MiniMax-M3-MXFP8` (quantized by NVIDIA per vLLM recipe)                                       | none found                                                      |
| NVFP4              | `nvidia/MiniMax-M3-NVFP4` (ModelOpt 0.44.0, 2026-06-23); vLLM needs a build containing PR #46380 support | `nvidia/MiniMax-M2.7-NVFP4` (ModelOpt 0.43.0)                   |
| MXFP4              | `amd/MiniMax-M3-MXFP4` (AMD Quark, MI355X)                                                               | none found                                                      |
| GGUF               | `unsloth/MiniMax-M3-GGUF`, `bartowski/MiniMax-M3-GGUF` (community)                                       | `unsloth/MiniMax-M2.7-GGUF` (community)                         |
| MLX                | not checked                                                                                              | `mlx-community/MiniMax-M2.7-4bit`, `...-4bit-mxfp4` (community) |
| EAGLE3 draft heads | `Inferact/MiniMax-M3-EAGLE3`, `Inferact/MiniMax-M3-EAGLE3-GQA` (vLLM recipe)                             | none found                                                      |

## Not open weights

- **MiniMax-M3.1-Flash-Preview**: API model id only (Token Plan and MiniMax Code), announced 2026-09-27, no
  checkpoint found. Always-on thinking with effort levels low to max. Do not plan a self-host around it.
- **MiniMax-M2.7-highspeed**, **M2.5-highspeed**, **M2.1-highspeed**: API model ids listed in the MiniMax API docs.
- Other MiniMax weights on Hugging Face are not LLMs: `MiniMaxAI/MiniMax-H3` (audio-video generation),
  `MiniMax-Music3`, `VTP-*` vision encoders, `SynLogic-*` (Qwen2 fine-tunes, MIT).

## Legacy

`MiniMaxAI/MiniMax-Text-01` / `MiniMax-VL-01` (Jan 2025) and `MiniMax-M1-40k` / `M1-80k` (Jun 2025, Apache-2.0
tag) remain on Hugging Face with `-hf` Transformers variants. They use a different architecture (`minimax`,
`minimax_m1`), predate the M2 chat format and parsers, and are not covered further here (sizes unverified).

## Hosted access (for comparison)

Hosted MiniMax API ids: `MiniMax-M3`, `MiniMax-M2.7`, `MiniMax-M2.5`, `MiniMax-M2.1`, `MiniMax-M2`. Ollama
cloud tags: `minimax-m3:cloud` (512K context), `minimax-m2.7:cloud` (200K, 229B). No local Ollama weights found.
Use the `cloud-llms` skill for hosted use.

## Sources

- https://huggingface.co/api/models?author=MiniMaxAI
- https://huggingface.co/MiniMaxAI/MiniMax-M3 and its LICENSE
- https://huggingface.co/MiniMaxAI/MiniMax-M2.7 and https://github.com/MiniMax-AI/MiniMax-M2.7/blob/main/LICENSE
- https://huggingface.co/MiniMaxAI/MiniMax-M2.5 and https://huggingface.co/MiniMaxAI/MiniMax-M2
- https://recipes.vllm.ai/MiniMaxAI/MiniMax-M3
- https://docs.sglang.io/cookbook/autoregressive/MiniMax/MiniMax-M3
- https://nvidia.github.io/TensorRT-LLM/latest/deployment-guide/deployment-guide-for-minimax-m3-on-trtllm.html
- https://unsloth.ai/docs/models/minimax-m3 and https://unsloth.ai/docs/models/minimax-m27
- https://huggingface.co/nvidia/MiniMax-M3-NVFP4 and https://huggingface.co/nvidia/MiniMax-M2.7-NVFP4
- https://ollama.com/library/minimax-m3 and https://ollama.com/library/minimax-m2.7
- https://platform.minimax.io/docs/api-reference/text-openai-api
