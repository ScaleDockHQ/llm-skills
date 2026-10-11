# Llama

An agent skill for serving Meta's open models: **Muse Glimmer 30B** (August 2026, Apache 2.0, dense reasoning and vision model), **Llama 4 Scout and Maverick** (the newest models named Llama) and older Llama 3.x. It tells an AI coding agent which Meta model to pick, which chat template, tool-call parser and reasoning parser each engine needs (vLLM, SGLang, llama.cpp, Ollama, TensorRT-LLM, TensorRT Edge-LLM, MLX), which quant fits DGX Spark, RTX, Apple Silicon or H100/B200, the sampling and context limits, the licenses, and the known bugs. Discovery commands are read-only and never print secrets.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill llama
```

## Rules

- **Pick the model first.** Muse Glimmer is Meta's newest open model; Llama 4 is the newest "Llama". Say which one you serve.
- **Muse Glimmer: sample, do not greedy.** `temperature 1.0, top_p 0.95, top_k 64`, never stop on `<|eom|>`, parser names are `muse_glimmer` (vLLM) and `muse` (SGLang).
- **Llama 4: pythonic tools.** `llama4_pythonic` with the matching template.
- **Check upstream docs against the engine.** Meta's and SGLang's Muse pages still say the support is unmerged; it is released.
- **Quality gate every quant.** Run `llm-evals` after a quant, KV dtype or speculative-decoding change.
- **Secrets never touch output.** Hugging Face tokens for gated Llama repos stay in `0600` files or environment variables.

## References

- [`references/models.md`](references/models.md): current Meta generations, sizes, context, licenses and official quants.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): chat formats, parser flags per engine, reasoning toggles and sampling.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): per-platform quant and engine recommendations.
- [`references/known-issues.md`](references/known-issues.md): symptom table, open bugs, stale upstream docs and gaps.

## Companion skills

- `vllm`, `sglang`, `llama-cpp`, `ollama`, `tensorrt-llm`, `mlx`: install and tune the engines.
- `self-hosted-llms`: the full serving stack, gateway and exposure.
- `model-quantization`: quantize or compare formats.
- `llm-evals`: quality gates after a quant or engine change.

## License

MIT
