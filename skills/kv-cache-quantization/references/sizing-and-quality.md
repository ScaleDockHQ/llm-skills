# KV Cache Quantization: Sizing, Quality Evidence and Troubleshooting

> Verified against SGLang v0.5.21 (quantized KV cache docs), vLLM v0.31.0 (quantized_kvcache docs), Ollama docs FAQ, llama.cpp issue #24485, 2026-10-11

Flags are in `engine-matrix.md`. This page covers the arithmetic, upstream accuracy evidence, calibration and what to do when the gate fails.

## Size the cache

KV bytes per token = `2 x layers x kv_heads x head_dim x bytes_per_element`. `2` is for K and V. Read `num_hidden_layers`, `num_key_value_heads` (or `num_attention_heads` when absent) and `head_dim` from the model's `config.json`.

Hybrid models (sliding-window, Mamba or linear-attention layers) store less than this formula says, and MLA models (DeepSeek) store a compressed latent instead of full K and V. Trust the engine's reported capacity over the formula.

Bytes per element, with block-scale overhead where it applies:

| Format         | Bytes per element                           | Capacity versus BF16    |
| -------------- | ------------------------------------------- | ----------------------- |
| BF16 or FP16   | 2                                           | 1.0x                    |
| FP8            | 1 (scale overhead small; per-tensor scales) | about 2x                |
| `q8_0`         | about 1.06 (block scales)                   | about 1.9x              |
| `q4_0`         | about 0.56 (block scales)                   | about 3.5x              |
| NVFP4 (SGLang) | 0.5 + 1/16 = 0.5625                         | 3.56x (upstream figure) |

Ollama's FAQ gives `q8_0` about 1/2 and `q4_0` about 1/4 of `f16` memory. The capacity gain is the KV cache only: weights, activations and CUDA graphs are unchanged, so total VRAM drops less than these ratios.

Example (illustrative): 32 layers, 8 KV heads, head_dim 128 gives `2 x 32 x 8 x 128 x 2 = 131072` bytes (128 KiB) per token in BF16, so a 128k-token context needs about 16 GiB per sequence in BF16 and about 8 GiB in FP8.

## Accuracy evidence from upstream

SGLang documents FP8 E4M3 as typically minimal degradation and FP4 as experimental. Its published results (PR #10078 for MLA, PR #12612 for MHA):

| Model            | Dataset      | KV16   | KV8 (FP8 E4M3) | KV4 (FP4 E2M1) |
| ---------------- | ------------ | ------ | -------------- | -------------- |
| Qwen3-235B-A22B  | gsm8k        | 0.9168 | 0.9181         | 0.9186         |
| Qwen3-235B-A22B  | aime25       | 0.7733 | 0.7333         | 0.6000         |
| DeepSeek-R1-0528 | aime25       | 0.5067 | 0.4934         | 0.4000         |
| GPT-OSS-120B     | gsm8k        | 0.9161 | 0.9163         | 0.9152         |
| GPT-OSS-120B     | aime25       | 0.7533 | 0.7667         | 0.3533         |
| GPT-OSS-120B     | gpqa_diamond | 0.5081 | 0.5434         | 0.3202         |

Lessons upstream draws, which your gate should test:

- Easy tasks (gsm8k) barely move; hard reasoning tasks (aime25, gpqa) can fall sharply at 4 bits.
- Smaller models tolerate low-bit KV worse than 200B+ models.
- Long-context error accumulates, so measure at your longest served context.
- Ollama notes high-GQA models (for example Qwen2) can be more sensitive to KV quantization.
- Treat these as examples from other setups, not predictions for yours.

## Calibration

- vLLM: per-tensor or per-attention-head FP8 scales from `llm-compressor` `oneshot` with `kv_cache_scheme` (the upstream example uses 512 calibration samples of `HuggingFaceH4/ultrachat_200k`, sequence length 2048). Use calibration text that resembles production traffic. Per-attention-head needs the Flash Attention backend.
- SGLang: use a pre-quantized checkpoint that ships `k_scale`/`v_scale`, or a JSON given with `--quantization-param-path`.
- TensorRT-LLM: ModelOpt export (`--kv_cache_quant nvfp4` with `--quant fp8`). See the `model-quantization` skill for producing checkpoints.
- llama.cpp, Ollama and ExLlamaV3 use block or group quantization with no calibration step.

## Troubleshooting

| Symptom                                                          | Likely cause                                                                       | Action                                                                                                                                   |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Quality drops, mostly at long context or in reasoning            | Low-bit format, default scale `1.0`, or sensitive layers                           | Go up one level (`q4_0` to `q8_0`, FP4 to FP8, `fp8_e5m2` to `fp8_e4m3`); calibrate; vLLM `--kv-cache-dtype-skip-layers sliding_window`. |
| Throughput lower than baseline                                   | Backend dequantizes outside the attention kernel                                   | Pick an attention backend with fused quantized support (SGLang), rebuild llama.cpp with `-DGGML_CUDA_FA_ALL_QUANTS=ON`, or revert.       |
| llama.cpp prefill 25x slower, GPU idle                           | CPU attention fallback for quantized KV (issue #24485)                             | See `engine-matrix.md`; confirm GPU use during prefill.                                                                                  |
| "V cache quantization requires flash_attn"                       | Flash attention is off or unsupported for the model                                | `-fa on`, or use `f16` V.                                                                                                                |
| Ollama ignores the KV type                                       | Flash attention not active, or env var not set on the service                      | Set `OLLAMA_FLASH_ATTENTION=1` and `OLLAMA_KV_CACHE_TYPE` in the service environment; restart; check logs.                               |
| No capacity gain                                                 | Another limit, such as `--max-num-seqs`, context cap or weights                    | Read the engine's reported KV tokens before and after.                                                                                   |
| SGLang NVFP4 path rejects speculative or disaggregation settings | The SM100 native NVFP4 path supports only top-k-1 EAGLE family and breadth-1 NGRAM | See the SGLang section of the matrix.                                                                                                    |

## Sources

- https://docs.sglang.ai/advanced_features/quantized_kv_cache.html
- https://github.com/vllm-project/vllm/blob/v0.31.0/docs/features/quantization/quantized_kvcache.md
- https://docs.ollama.com/faq
- https://github.com/ggml-org/llama.cpp/issues/24485
