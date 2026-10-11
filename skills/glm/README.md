# GLM

Serve Z.ai (Zhipu) GLM open-weight models with the right engine flags. It covers GLM-5.3, GLM-5.3-Flash, GLM-5.2, GLM-4.7 and GLM-4.7-Flash: which model fits which hardware (DGX Spark, RTX, Apple Silicon, H100 to B200), the `glm47` and `glm45` tool and reasoning parsers for vLLM and SGLang, TensorRT-LLM and llama.cpp notes, `reasoning_effort` and `clear_thinking`, official and community FP8, NVFP4, GGUF and MLX quants, licences and known bugs. For agents that must launch and debug a GLM endpoint. Verified against upstream docs on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill glm
```

## Rules

- **Ask before changing the system.** Installs, container pulls and 100 GB+ downloads need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Parsers are mandatory.** Use `--tool-call-parser glm47` and a reasoning parser on GLM-4.7 and GLM-5.x, or tool calls come back as raw text.
- **GLM-5.3 cannot turn thinking off.** Lower `reasoning_effort` and set `clear_thinking=true` for chat.
- **Check the licence.** GLM-5.3 uses a custom licence; GLM-5.3-Flash, 5.2 and 4.7 are MIT.

## References

- [`references/models.md`](references/models.md): generations, sizes, context, licences, architecture names.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): parsers per engine, thinking and effort toggles, sampling, launch commands.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): per-platform recommendations, quant availability, engine support, TensorFold status.
- [`references/known-issues.md`](references/known-issues.md): reported bugs, causes and fixes, open gaps.

## Companion skills

- `self-hosted-llms`: gateway, exposure and benchmarking around the engine.
- `local-llms`: laptop and desktop runs.
- `cloud-llms`: hosted GLM through providers.
- `model-quantization`: choosing or making GGUF, FP8, NVFP4 and MLX quants.
- `fine-tuning-llms`: SFT and RL on GLM weights.

## License

MIT
