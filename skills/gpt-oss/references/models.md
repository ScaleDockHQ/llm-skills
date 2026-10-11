# gpt-oss models

> Verified against openai/gpt-oss-120b and gpt-oss-20b Hugging Face cards and config.json, openai.com/open-models, OpenAI help center, gpt-oss-safeguard card, nvidia/gpt-oss-puzzle-88B card, 2026-10-11

## Generations on 2026-10-11

One generation. OpenAI released gpt-oss on 2025-08-05; no general-purpose successor was found as of 2026-10-11
([open-models page](https://openai.com/open-models/) lists only gpt-oss and gpt-oss-safeguard). The `openai/gpt-oss-*`
repos were last modified 2025-08-26.

| Model                                                                                   | Total / active params | Layers / experts | Weights                       | Use                          |
| --------------------------------------------------------------------------------------- | --------------------- | ---------------- | ----------------------------- | ---------------------------- |
| [`openai/gpt-oss-120b`](https://huggingface.co/openai/gpt-oss-120b)                     | 117B / 5.1B           | 36 / 128, top-4  | MXFP4 MoE, rest BF16 (~61 GB) | General, high reasoning      |
| [`openai/gpt-oss-20b`](https://huggingface.co/openai/gpt-oss-20b)                       | 21B / 3.6B            | 24 / 32, top-4   | MXFP4 MoE, rest BF16 (~12 GB) | Low latency, local           |
| [`openai/gpt-oss-safeguard-120b`](https://huggingface.co/openai/gpt-oss-safeguard-120b) | 117B / 5.1B           | same             | same                          | Policy-based safety labeling |
| [`openai/gpt-oss-safeguard-20b`](https://huggingface.co/openai/gpt-oss-safeguard-20b)   | 21B / 3.6B            | same             | same                          | Policy-based safety labeling |

Layer and expert counts come from each repo's `config.json` (`num_hidden_layers`, `num_local_experts`,
`num_experts_per_tok`). Sizes in GB come from the llama.cpp guide (model data 61.0 GB and 12.0 GB). Text only,
no vision.

- **Architecture:** MoE decoder, alternating sliding-window (128 tokens) and full attention layers, attention
  sinks (`config.json` `layer_types`, `sliding_window`).
- **Context:** `max_position_embeddings` 131072, reached with YaRN (factor 32 from `original_max_position_embeddings`
  4096). Both cards and the llama.cpp guide state 128k as the maximum.
- **Quantization:** the MoE weights were post-trained in MXFP4 (4.25 bits per parameter per Ollama's page); attention,
  router, embeddings and `lm_head` stay unquantized (`quantization_config.modules_to_not_convert`). All official evals
  used MXFP4. There is no "full precision" checkpoint to prefer; the official weights are the quality baseline.
- **Fits:** 120b on one 80 GB GPU (H100, MI300X); 20b in 16 GB.
- **License:** Apache 2.0 plus OpenAI's gpt-oss usage policy (`USAGE_POLICY` file in the repo). Keep the LICENSE and
  NOTICE files when redistributing. Safeguard models are also Apache 2.0.
- **Chain of thought is raw.** Not safety-trained like the final channel; never show it to end users.

## gpt-oss-safeguard

Research-preview fine-tunes of gpt-oss, same architecture and chat template, for classifying content against a policy
you supply. Put the policy in the developer message and the content in the user message
([help center](https://help.openai.com/en/articles/11870455-openai-open-weight-models-gpt-oss)). OpenAI recommends the core
gpt-oss models for chat and agents. Weights are not served through the OpenAI API or ChatGPT.

## Derivatives that exist (verified on Hugging Face)

| Repo                                                                                                                                                               | What                                                                                                                  | License                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| [`nvidia/gpt-oss-puzzle-88B`](https://huggingface.co/nvidia/gpt-oss-puzzle-88B)                                                                                    | NAS-pruned 120b (~88B, fewer experts per layer, some window-attention layers), 128k, FP8 KV, H100 and B200, vLLM only | NVIDIA Open Model License |
| `nvidia/gpt-oss-120b-Eagle3-v3`, `-long-context`, `-short-context`, `-throughput`                                                                                  | EAGLE3 speculative-decoding drafts for 120b                                                                           | `other` (read each card)  |
| `amd/gpt-oss-120b-w-mxfp4-a-fp8`                                                                                                                                   | Quark MXFP4 weights with FP8 activations for MI355x                                                                   | read the card             |
| [`ggml-org/gpt-oss-120b-GGUF`](https://huggingface.co/ggml-org/gpt-oss-120b-GGUF), [`ggml-org/gpt-oss-20b-GGUF`](https://huggingface.co/ggml-org/gpt-oss-20b-GGUF) | Official llama.cpp conversions (`gpt-oss-120b-MXFP4.gguf`; the 120b repo also has EAGLE3 GGUF drafts)                 | Apache 2.0                |
| [`unsloth/gpt-oss-120b-GGUF`](https://huggingface.co/unsloth/gpt-oss-120b-GGUF) / `-20b-GGUF`                                                                      | Unsloth GGUFs with chat-template fixes                                                                                | Apache 2.0                |
| [`mlx-community/gpt-oss-20b-MXFP4-Q8`](https://huggingface.co/mlx-community/gpt-oss-20b-MXFP4-Q8), `mlx-community/gpt-oss-120b-MXFP4-Q8`, `...-20b-MXFP4-Q4`       | MLX conversions (community, mlx-lm 0.27.0)                                                                            | Apache 2.0                |

The Puzzle model's card gives vLLM v0.17.1 plus a pinned vLLM commit and FlashInfer 0.6.6 as its tested serving recipe;
use that recipe rather than stock settings, and measure it against `gpt-oss-120b` for your workload.

## Reasoning levels and benchmarks

Three effort levels: `low`, `medium` (default), `high`. vLLM's recipe reproduced these without tools: 120b GPQA
65.3 / 72.4 / 79.4 and AIME25 51.2 / 79.6 / 93.0; 20b GPQA 56.8 / 67.5 / 70.9 and AIME25 38.8 / 75.0 / 85.8
(low / medium / high). Higher effort costs more output tokens, so budget `max_tokens` (and timeouts) for `high`.

## Sources

- https://huggingface.co/openai/gpt-oss-120b, https://huggingface.co/openai/gpt-oss-20b
- https://openai.com/index/introducing-gpt-oss/, https://openai.com/open-models/
- https://help.openai.com/en/articles/11870455-openai-open-weight-models-gpt-oss
- https://huggingface.co/openai/gpt-oss-safeguard-20b
- https://huggingface.co/nvidia/gpt-oss-puzzle-88B
- https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html
