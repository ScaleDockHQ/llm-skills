# bitsandbytes

Helps an agent load LLMs in 8-bit (LLM.int8()) or 4-bit (NF4/FP4) with bitsandbytes, run QLoRA and FSDP-QLoRA fine-tuning, use 8-bit and paged optimizers, serve bnb checkpoints in vLLM, and fix install and backend errors. It covers the `bitsandbytes` library through Transformers, PEFT, TRL and Accelerate.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill bitsandbytes
```

## Rules

- **Run `python3 -m bitsandbytes` first.** It shows whether the native library loads for this PyTorch build.
- **NF4 with bf16 compute** for training and most inference; the float32 default is slow.
- **Only adapters train** in a quantized model; merge into a bf16 base before serving.
- **Memory, not speed.** Use `model-quantization` for serving-grade formats.
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): requirements, backends, source build, preview wheels.
- [`references/quantize-and-load.md`](references/quantize-and-load.md): `BitsAndBytesConfig` for 8-bit and 4-bit.
- [`references/qlora-training.md`](references/qlora-training.md): QLoRA and FSDP-QLoRA.
- [`references/optimizers.md`](references/optimizers.md): 8-bit and paged optimizers.
- [`references/serving-and-export.md`](references/serving-and-export.md): save, merge, vLLM.
- [`references/troubleshooting.md`](references/troubleshooting.md): errors and fixes.
- [`references/updating.md`](references/updating.md): releases and safe upgrades.

## Companion skills

- `model-quantization`: choose a format and gate quality.
- `trl`, `unsloth`, `fine-tuning-llms`: training stacks that use bnb.
- `vllm`: serving.
- `llm-evals`: quality checks.

## License

MIT
