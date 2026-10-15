# torchao

Helps an agent quantize and train PyTorch and Hugging Face models with torchao (PyTorch AO): Float8, Int8 and Int4 inference configs through `quantize_()` and `TorchAoConfig`, quantization-aware training, float8 and prototype mx/NVFP4 training, low-bit optimizers, and serving the result in vLLM.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill torchao
```

## Rules

- **Pair torchao with the right PyTorch;** 0.18.0 needs 2.11 or newer.
- **Config objects, not strings,** in `TorchAoConfig`.
- **Pick the dtype from the GPU;** float8 dynamic needs compute capability 8.9+.
- **Compile and measure** before claiming a speed-up.
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): pip, indexes, torch pairing, optional kernels.
- [`references/inference-quantization.md`](references/inference-quantization.md): configs by hardware, Transformers, per-module configs.
- [`references/qat.md`](references/qat.md): prepare and convert.
- [`references/training-and-optimizers.md`](references/training-and-optimizers.md): float8 training, low-bit optimizers.
- [`references/serving-and-export.md`](references/serving-and-export.md): saving, vLLM, ExecuTorch.
- [`references/troubleshooting.md`](references/troubleshooting.md): errors and fixes.
- [`references/updating.md`](references/updating.md): releases and upgrades.

## Companion skills

- `model-quantization`, `bitsandbytes`, `llm-compressor`: other quantization routes.
- `vllm`: serving.
- `llm-evals`: quality gates.

## License

MIT
