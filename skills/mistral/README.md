# Mistral

Helps an agent serve Mistral AI open-weight models (Small 4, Medium 3.5, Large 3, Ministral 3, Devstral 2, legacy
Magistral) on vLLM, SGLang, llama.cpp, Ollama and TensorRT-LLM: the right tokenizer mode, tool and reasoning
parsers, the `reasoning_effort` toggle, recommended quants for DGX Spark, RTX, Apple Silicon and datacenter GPUs,
context limits, licenses and known bugs. Verified on 2026-10-11. Mistral Large 4 weights were not public yet.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill mistral
```

## Rules

- **Ask before changing the system.** Installs, downloads, services and exposure need approval.
- **Native tokenizer mode first** on vLLM, with `--tool-call-parser mistral` and, for reasoning models, `--reasoning-parser mistral`.
- **`reasoning_effort` is `none` or `high` only** on Small 4 and Medium 3.5.
- **Re-pull Medium 3.5 conversions made before 2026-05-01**: they carry a YaRN bug.
- **Secrets never touch output.** Tokens live in environment variables or `0600` files.

## References

- [`references/models.md`](references/models.md): current generations, sizes, context, licenses, legacy models.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): tokenizer modes, template tokens, reasoning toggle, per-engine flags, sampling.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): quants and recommendations per platform and engine.
- [`references/known-issues.md`](references/known-issues.md): symptoms, causes, fixes and open gaps.

## Companion skills

- `self-hosted-llms`: the serving stack around the engine.
- `local-llms`: laptop setups.
- `model-quantization`: GGUF, FP8 and NVFP4 quants.
- `fine-tuning-llms`: finetuning.
- `cloud-llms`: hosted APIs.

## License

MIT
