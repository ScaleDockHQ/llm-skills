# gpt-oss

An agent skill for serving OpenAI's gpt-oss-120b and gpt-oss-20b open-weight models (plus gpt-oss-safeguard and NVIDIA's gpt-oss-puzzle-88B). It covers the harmony response format, the `reasoning_effort` levels, the official MXFP4 weights and their GGUF and MLX conversions, reasoning and tool-call parser flags for vLLM, SGLang, llama.cpp, Ollama and TensorRT-LLM, sampling settings, per-platform guidance (DGX Spark, consumer RTX, Apple Silicon, H100/B200, AMD), context limits, the license, and known bugs with their fixes. It was verified against upstream pages on 2026-10-11, when gpt-oss (released 2025-08-05) had no general-purpose successor.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill gpt-oss
```

## Rules

- **harmony only.** Use the engine's chat endpoint with the model's own template; never a generic wrapper.
- **No raw chain of thought for end users.** Keep `reasoning` for developers.
- **Official MXFP4 weights first.** The MoE weights are already 4-bit; quantize further only behind an eval gate.
- **Sampling:** `temperature=1.0`, `top_p=1.0`, no repetition penalty.
- **Ask before changing the system**, and never print secrets.
- **TensorFold has no gpt-oss qualification** in v1.0.7; the skill says so rather than guessing.

## References

- [`references/models.md`](references/models.md): sizes, active params, safeguard and derivative models, context, license.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): harmony format, reasoning toggles and parsers per engine, sampling.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): formats, memory and per-platform recommendations.
- [`references/known-issues.md`](references/known-issues.md): symptoms, causes and fixes.

## Companion skills

- `self-hosted-llms`: serve it on a DGX Spark or GPU server behind one endpoint.
- `local-llms`: laptop and desktop runtimes.
- `cloud-llms`: hosted and rented options.
- `model-quantization`: produce and check quants.
- `fine-tuning-llms`: fine-tune and merge adapters.

## License

MIT
