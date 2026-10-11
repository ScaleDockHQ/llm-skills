# Gemma models

> Verified against Gemma 4 model card (ai.google.dev), Gemma 4 overview, Hugging Face Gemma 4 blog, Ollama gemma4 library, MedGemma 1.5 card, 2026-10-11

## Current generation: Gemma 4

Five sizes, each with a base (pre-trained) and an instruction-tuned (`-it`) checkpoint. The licence is Apache 2.0 ([HF blog](https://huggingface.co/blog/gemma4)). Training data cutoff is January 2025. All models are multimodal (image in, text out); the model card lists 140+ pre-training languages and 35+ out-of-the-box.

| Model       | Type                                        | Params                               | Layers | Context | Modalities in      | HF id (instruction-tuned)   |
| ----------- | ------------------------------------------- | ------------------------------------ | ------ | ------- | ------------------ | --------------------------- |
| E2B         | Dense, per-layer embeddings                 | 2.3B effective, 5.1B with embeddings | 35     | 128K    | text, image, audio | `google/gemma-4-E2B-it`     |
| E4B         | Dense, per-layer embeddings                 | 4.5B effective, 8B with embeddings   | 42     | 128K    | text, image, audio | `google/gemma-4-E4B-it`     |
| 12B Unified | Dense, encoder-free                         | 11.95B                               | 48     | 256K    | text, image, audio | `google/gemma-4-12B-it`     |
| 26B A4B     | MoE (8 active of 128 experts plus 1 shared) | 25.2B total, 3.8B active             | 30     | 256K    | text, image        | `google/gemma-4-26B-A4B-it` |
| 31B         | Dense                                       | 30.7B                                | 60     | 256K    | text, image        | `google/gemma-4-31B-it`     |

Facts that change serving decisions:

- **MoE memory.** 26B A4B decodes like a ~4B model but all 25.2B weights must be resident ([overview](https://ai.google.dev/gemma/docs/core)).
- **Hybrid attention.** Sliding-window layers (512 tokens on E2B/E4B, 1024 on the others) interleave with global layers; the last layer is always global. Global layers use unified keys and values and p-RoPE, which keeps the KV cache small at long context.
- **"Unified" 12B** has no vision or audio encoder; raw patches and waveforms are projected straight into the decoder. It needs its own engine support (`Gemma4UnifiedForConditionalGeneration`; vLLM used the `vllm/vllm-openai:gemma4-unified` image in its recipe).
- **Audio** is E2B, E4B and 12B only, capped at 30 seconds. Video is processed as frames, up to 60 seconds at 1 fps.
- **Vision token budget** per image: 70, 140, 280, 560 or 1120. Low for classification and video, high for OCR and documents.
- **Native `system` role**, native function calling, configurable thinking.
- **MTP drafters.** Every size has a matching `-assistant` checkpoint for speculative decoding (for example `google/gemma-4-31B-it-assistant`). Same outputs, reported speed-up up to ~3x depending on hardware and batch.

Weight memory from the overview table (weights only, 20% loading overhead, no KV cache):

| Model   | BF16    | SFP8    | Q4_0    |
| ------- | ------- | ------- | ------- |
| E2B     | 11.4 GB | 5.7 GB  | 2.9 GB  |
| E4B     | 17.9 GB | 8.9 GB  | 4.5 GB  |
| 12B     | 26.7 GB | 13.4 GB | 6.7 GB  |
| 26B A4B | 57.7 GB | 28.8 GB | 14.4 GB |
| 31B     | 69.9 GB | 34.9 GB | 17.5 GB |

## Variants

| Variant                                                     | What it is                                                                              | Licence / access                                        | Notes                                                                                                                                                                                                                                                                     |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `*-qat-*`                                                   | Official quantization-aware-trained checkpoints                                         | Not stated separately                                   | See `references/platforms-and-quants.md`.                                                                                                                                                                                                                                 |
| `*-assistant`                                               | MTP draft model for speculative decoding                                                | Same                                                    | Needs engine support (vLLM, TensorRT-LLM).                                                                                                                                                                                                                                |
| DiffusionGemma 26B A4B (`google/diffusiongemma-26B-A4B-it`) | Block-diffusion text generation on the 26B A4B backbone, 256-token canvas, 256K context | Apache 2.0 ([blog](https://huggingface.co/blog/gemma4)) | Trails the autoregressive 26B A4B on benchmarks (for example MMLU Pro 77.6% vs 82.6%) for much higher throughput. Google recommends the Entropy-Bounded sampler, not the sampling params below. vLLM needs `--max-num-seqs` at or below 4 and `--generation-config vllm`. |
| `nvidia/Gemma-4-31B-IT-NVFP4`                               | NVIDIA ModelOpt NVFP4 of the 31B                                                        | Apache 2.0                                              | For vLLM (`--quantization modelopt`).                                                                                                                                                                                                                                     |

## Previous generations and other Gemma families

- Gemma 3, 2 and 1 remain downloadable ([previous models](https://ai.google.dev/gemma/docs/core)). This skill does not verify their sizes, templates or parsers; read their model cards before serving them. Gemma 3 uses a different chat template from Gemma 4.
- **MedGemma** is official but still built on **Gemma 3**: MedGemma 1.5 is a 4B multimodal model (released 2026-01-13, at least 128K context), and MedGemma 1 has 4B and 27B variants. Weights are gated and licensed under the Health AI Developer Foundations terms, not Apache 2.0 ([MedGemma](https://developers.google.com/health-ai-developer-foundations/medgemma), [HF card](https://huggingface.co/google/medgemma-1.5-4b-it/blob/main/README.md)). No Gemma 4 based MedGemma was found.
- PaliGemma, CodeGemma, RecurrentGemma, ShieldGemma, TxGemma and EmbeddingGemma are listed on the [Google HF org page](https://huggingface.co/google) but not verified here.

## Ollama tags (library page, 2026-10-11)

| Tag                     | Size                     | Context |
| ----------------------- | ------------------------ | ------- |
| `gemma4:e2b`            | 4.6-7.5 GB               | 128K    |
| `gemma4:e4b` (`latest`) | 6.6-9.5 GB               | 128K    |
| `gemma4:12b`            | 7.7-8.0 GB               | 256K    |
| `gemma4:26b`            | 16-19 GB                 | 256K    |
| `gemma4:31b`            | 19-20 GB                 | 256K    |
| `gemma4:*-mlx`          | MLX builds of every size | same    |

Short tags move: a third-party review found `26b` re-pointed to an MTP build. Pin the full tag and record the digest from `/api/tags`.

## Sources

- [Gemma 4 model card](https://ai.google.dev/gemma/docs/core/model_card_4)
- [Gemma 4 overview and memory table](https://ai.google.dev/gemma/docs/core)
- [Hugging Face: Welcome Gemma 4](https://huggingface.co/blog/gemma4)
- [Ollama gemma4 tags](https://ollama.com/library/gemma4/tags)
