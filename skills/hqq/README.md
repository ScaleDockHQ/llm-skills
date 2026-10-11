# HQQ

Helps an agent quantize models with HQQ (Half-Quadratic Quantization) at 8, 4, 3, 2 or 1 bit without calibration data, choose `group_size` and `axis`, speed up inference with GemLite or torchao backends, train HQQ+ adapters, and run HQQ in vLLM.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill hqq
```

## Rules

- **Start at `nbits=4, group_size=64, axis=1`.**
- **Fused kernels need `axis=1`;** unsupported settings fall back silently.
- **Save before patching** with `prepare_for_inference`.
- **Evaluate low-bit models** before shipping.
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): pip, git, CUDA kernel build.
- [`references/quantize.md`](references/quantize.md): parameters, Transformers and hqq paths.
- [`references/backends-and-inference.md`](references/backends-and-inference.md): backends and fused kernels.
- [`references/serving-and-training.md`](references/serving-and-training.md): saving, vLLM, PEFT, HQQ+.
- [`references/troubleshooting.md`](references/troubleshooting.md): errors and fixes.
- [`references/updating.md`](references/updating.md): releases and upgrades.

## Companion skills

- `model-quantization`, `torchao`, `bitsandbytes`, `llm-compressor`: other quantization routes.
- `vllm`: serving.
- `llm-evals`: quality gates.

## License

MIT
