# Phi

Helps an agent serve Microsoft's Phi small models (Phi-4, Phi-4-reasoning and reasoning-plus, Phi-4-mini, mini-reasoning,
mini-flash-reasoning, Phi-4-multimodal and Phi-4-reasoning-vision-15B): which checkpoint to pick, the chat template and
reasoning toggles, tool and reasoning parser flags for vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama and TensorFold,
official and vendor quants, context limits, licenses and known bugs. Facts were verified against upstream on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill phi
```

## Rules

- **Ask before changing the system.** Installs, services and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Re-check engine flags with the engine's own help; model cards pin 2025-era versions.
- **Reasoning models drop system messages.** Put instructions in the user turn.
- **No invented models.** The newest Phi is Phi-4-reasoning-vision-15B; there is no Phi-5.

## References

- [`references/models.md`](references/models.md): generations, sizes, context, release dates, licenses, official packaging.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): templates, reasoning toggles, sampling, per-engine parser flags.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): FP8, NVFP4, GGUF, MLX, ONNX and platform picks.
- [`references/known-issues.md`](references/known-issues.md): symptoms, causes and fixes with upstream issue links.

## Companion skills

- `self-hosted-llms`: serve on owned NVIDIA GPUs or DGX Spark.
- `local-llms`: run on a laptop.
- `model-quantization`: create or evaluate quants.
- `fine-tuning-llms`: adapt Phi to a task.
- `cloud-llms`: hosted Phi on Azure AI Foundry and other clouds.

## License

MIT
