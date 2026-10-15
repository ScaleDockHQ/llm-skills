# DeepSeek

Helps an agent choose and serve DeepSeek models: V4.1-Flash, V4-Flash-0731, V4-Pro-0813, the V4 previews, V3.2, R1 and the R1 distills. It covers prompt encoding and DSML tool calls, the exact parser names per engine, reasoning-effort toggles, sampling, quants per platform, context limits, licenses and known bugs. Engines covered: vLLM, SGLang, llama.cpp, TensorRT-LLM, Ollama, MLX and TensorFold. Platforms: DGX Spark, consumer RTX, Apple Silicon, Hopper and Blackwell. Verified against upstream on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill deepseek
```

## Rules

- **Name the generation first.** V4.1, V4-0731 and V4-0813 need different parsers, and V4 has no small model.
- **Check memory before the engine.** V4.1-Flash is about 476 GiB on disk, so one DGX Spark or one consumer GPU cannot hold the native checkpoints.
- **Use the paired parser.** `deepseek_v4` does not parse V4.1's spaced DSML tags; use `deepseek_v41` or SGLang's `deepseekv41`.
- **Set reasoning explicitly.** Defaults differ per engine, and an empty `content` with `finish_reason=length` usually means a thinking trace ate `max_tokens`.
- **Verify upstream.** Engine support for V4.x changes weekly; re-read the recipe and the issue before trusting a flag.
- **Ask before changing the system.** Installs, downloads and exposure need approval.

## References

- [`references/models.md`](references/models.md): generations, sizes, context, licenses and official quants.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): prompt encoding, DSML format, parser and toggle names per engine, sampling.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): per-platform recommendations, GGUF, NVFP4, FP8 repacks, MLX.
- [`references/known-issues.md`](references/known-issues.md): symptoms, open bugs and version traps with issue links.

## Companion skills

- `vllm`, `sglang`, `llama-cpp`, `tensorrt-llm`, `mlx`: engine install and tuning.
- `speculative-decoding`: DSpark and draft models.
- `self-hosted-llms`: run, expose and benchmark models on your own server.
- `model-quantization`: choosing formats.

## License

MIT
