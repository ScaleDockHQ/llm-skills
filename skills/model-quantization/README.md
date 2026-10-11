# Model Quantization Skill

An agent skill for producing quantized LLMs: picking the right format for the serving engine and hardware, converting and calibrating, checking quality against the base model, and publishing to Hugging Face with the full recipe in the model card. It covers GGUF with [llama.cpp](https://github.com/ggml-org/llama.cpp), EXL3 with [ExLlamaV3](https://github.com/turboderp-org/exllamav3) and [TabbyAPI](https://github.com/theroyallab/tabbyAPI), AWQ / GPTQ / FP8 / NVFP4 with [LLM Compressor](https://github.com/vllm-project/llm-compressor) for [vLLM](https://github.com/vllm-project/vllm) and [SGLang](https://github.com/sgl-project/sglang), NVFP4 / FP8 with [NVIDIA Model Optimizer](https://github.com/NVIDIA/Model-Optimizer) for [TensorRT-LLM](https://github.com/NVIDIA/TensorRT-LLM), and MLX with [mlx-lm](https://github.com/ml-explore/mlx-lm). Publishing uses the [huggingface_hub](https://github.com/huggingface/huggingface_hub) `hf` CLI. It treats NVIDIA DGX Spark (GB10, unified memory) and Apple Silicon as first-class targets.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill model-quantization
```

## Rules

- **Pick the format for the engine, not the other way round.** Decide engine and hardware first, then produce the format it runs best.
- **Quality-check against the base model.** Compare each quant with its unquantized parent on the same text, context and tool.
- **Cap memory for every conversion.** Use memory-capped scopes and stop serving on unified-memory nodes before heavy jobs.
- **Keep the recipe with the artifact.** Commands, versions and calibration data go in the model card.
- **Respect the base model's license.** Inherit it, copy notices, link the base, and do not publish what it forbids.
- **Quantize from 16-bit weights, never from another quant.** Keep the BF16 source until every variant passes.
- **Publish private first.** Verify files, card and a fresh download before making the repo public.

## References

- [`references/formats.md`](references/formats.md) — formats, format-to-engine matrix, hardware notes.
- [`references/gguf.md`](references/gguf.md) — llama.cpp build, `convert_hf_to_gguf.py`, `llama-quantize`, `llama-imatrix`.
- [`references/exl3.md`](references/exl3.md) — ExLlamaV3 `convert.py` and TabbyAPI.
- [`references/llm-compressor.md`](references/llm-compressor.md) — how LLM Compressor plugs into this stack (depth: `llm-compressor` skill).
- [`references/modelopt-nvfp4.md`](references/modelopt-nvfp4.md) — how NVIDIA Model Optimizer plugs into this stack (depth: `nvidia-modelopt` skill).
- [`references/mlx.md`](references/mlx.md) — how MLX quantization plugs into this stack (depth: `mlx` skill).
- [`references/quality-checks.md`](references/quality-checks.md) — smoke prompts, KL divergence, perplexity.
- [`references/memory-safety.md`](references/memory-safety.md) — memory caps, disk planning, hf-xet settings.
- [`references/publishing.md`](references/publishing.md) — `hf upload`, model card metadata, licenses, naming.
- [`assets/model-card.md`](assets/model-card.md) — model card skeleton.

## Companion skills

- `llm-compressor` — AWQ, GPTQ, FP8, NVFP4 with LLM Compressor in depth (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-compressor`)
- `nvidia-modelopt` — NVIDIA Model Optimizer PTQ and export in depth (install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-modelopt`)
- `mlx` — mlx-lm conversion and serving in depth (install: `npx skills add ScaleDockHQ/llms-skills --skill mlx`)
- `self-hosted-llms` — choose/download existing quants and run the serving stack (install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`)
- `local-llms` — Ollama, LM Studio, llama.cpp on a laptop or desktop (install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`)
- `llm-evals` — task evals and quality gates (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`)
- `fine-tuning-llms` — train or merge before quantizing (install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`)
- `llm-gateway` — expose the model through LiteLLM (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`)

## License

MIT
