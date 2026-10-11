# GPT-QModel

Agent skill for GPT-QModel (`gptqmodel`, ModelCloud): quantize LLMs and VLMs with GPTQ or AWQ (plus ParoQuant, QQQ, GGUF, FP8 and EXL3) from one Python API, choose formats and Marlin/Machete/Exllama kernels, handle MoE routing, dynamic per-module overrides, checkpoint and resume, evaluate with Evalution, recover accuracy with EoRA, and hand the result to vLLM, SGLang or Transformers.

Verified against GPT-QModel v7.5.0 and `main` (7.6.0-dev) on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill gptqmodel
```

## Rules

- **Ask before changing the system.** Installs, JIT kernel builds, long jobs and uploads need approval.
- **Secrets never touch output.** `HF_TOKEN` stays in the environment or a `0600` file.
- **Quantize from the original BF16/FP16 weights** and keep config, version and calibration set for the model card.
- **Bind `serve()` to loopback**; the default host is `0.0.0.0`.

## References

- [`references/install.md`](references/install.md): pip, extras, environment variables, JIT cache.
- [`references/methods-and-formats.md`](references/methods-and-formats.md): methods, formats, backends.
- [`references/quantize.md`](references/quantize.md): config fields, calibration, MoE, dynamic, checkpointing.
- [`references/load-and-serve.md`](references/load-and-serve.md): load, serve, hand-off, publishing.
- [`references/evaluate-and-adapters.md`](references/evaluate-and-adapters.md): Evalution and EoRA.
- [`references/models-and-hardware.md`](references/models-and-hardware.md): supported models and platforms.
- [`references/updating-and-migration.md`](references/updating-and-migration.md): releases and AutoGPTQ/AutoAWQ migration.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/combos/quantize-then-serve-vllm.md`](references/combos/quantize-then-serve-vllm.md): GPTQ then vLLM.
- [`scripts/discover.sh`](scripts/discover.sh): read-only environment report.

## Companion skills

- `vllm`: serve the checkpoints.
- `llm-compressor`: the vLLM-project quantizer.
- `model-quantization`: choose a format.
- `gguf-quantization`, `exl3-quantization`: dedicated pipelines.
- `choosing-hardware`: size VRAM.

## License

MIT
