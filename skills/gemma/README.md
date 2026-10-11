# Gemma

Helps an agent choose, quantize-select and serve Google Gemma 4 (E2B, E4B, 12B Unified, 26B A4B MoE, 31B dense, plus QAT, MTP assistant and DiffusionGemma variants) on vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama and MLX. It carries the exact `gemma4` parser flags, thinking and tool-call formats, sampling settings, per-platform quant picks (DGX Spark, consumer RTX, Apple Silicon, datacenter GPUs) and the known upstream bugs, all verified on 2026-10-11. MedGemma and Gemma 3 are noted but not covered in depth.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill gemma
```

## Rules

- **Use the engine's chat template.** Never hand-build Gemma prompts; thinking is a template switch.
- **Verify upstream.** Gemma 4 engine support changes weekly; check versions and issues first.
- **Ask before installing or downloading.** Weights are large and servers bind ports.
- **Secrets never touch output.** Tokens live in `0600` files or environment variables.

## References

- [`references/models.md`](references/models.md): sizes, context, modalities, licences, variants, MedGemma, Ollama tags.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): control tokens, parsers and launch flags per engine, toggles, sampling.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): official quants and per-platform recommendations.
- [`references/known-issues.md`](references/known-issues.md): tool-parser, thinking-toggle and vision bugs with workarounds.

## Companion skills

- `vllm`, `sglang`, `llama-cpp`, `ollama`, `mlx`, `tensorrt-llm`: engine install and tuning.
- `self-hosted-llms`: GPU server and DGX Spark stacks.
- `local-llms`: laptop-first running.
- `model-quantization`: choosing and producing quants.
- `fine-tuning-llms`: tuning Gemma.

## License

MIT
