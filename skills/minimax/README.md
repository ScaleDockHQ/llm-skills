# MiniMax

Helps an agent choose, size and serve MiniMax open-weight models: MiniMax-M3 (428B MoE, 23B active, multimodal, 1M context) and the text-only M2 line (M2.7, M2.5, M2.1, M2; 230B MoE, 10B active). It covers the two chat and tool-call formats, the exact `minimax_m2` and `minimax_m3` parser names for vLLM, SGLang and TensorRT-LLM, llama.cpp and MLX paths, thinking toggles, recommended quants per platform (DGX Spark, RTX, Apple Silicon, H200, Blackwell), licenses and known bugs.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill minimax
```

## Rules

- **Match the parser to the generation.** M2 line: `minimax_m2` plus `minimax_m2_append_think`. M3: `minimax_m3` for both.
- **Keep the thinking in history.** MiniMax models are interleaved-thinking models; stripping it degrades agents.
- **M3 on vLLM needs `--block-size 128`.** Cap `--max-model-len` instead of serving the full 1M window blindly.
- **Check the license before commercial use.** M3 uses the MiniMax Community License; M2.7 is non-commercial without written authorization.
- **Ask before changing the system,** and never print secrets.

## References

- [`references/models.md`](references/models.md): generations, sizes, context, licenses, official quants, API-only models.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): template tokens, thinking toggles, parsers and launch commands per engine.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): DGX Spark, RTX, Apple Silicon, Hopper and Blackwell recommendations.
- [`references/known-issues.md`](references/known-issues.md): symptom-to-fix table and unverified gaps.

## Companion skills

- `self-hosted-llms`: the serving stack around the engine.
- `local-llms`: laptop and desktop runtimes.
- `cloud-llms`: hosted MiniMax APIs.
- `model-quantization`: GGUF, AWQ and NVFP4 choices.
- `fine-tuning-llms`: adapting weights.

## License

MIT
