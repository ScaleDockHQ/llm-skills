# LLM Compressor Skill

An agent skill for quantizing Hugging Face models with [LLM Compressor](https://github.com/vllm-project/llm-compressor) (`llmcompressor`, from the vLLM project and Red Hat AI): FP8, INT8, W4A16 with GPTQ or AWQ, NVFP4, MXFP4, KV cache and MoE or multimodal models, saved as [compressed-tensors](https://github.com/vllm-project/compressed-tensors) checkpoints that [vLLM](https://github.com/vllm-project/vllm) loads directly. It covers choosing a scheme for a GPU, calibration data, big-model memory tricks (sequential onloading, disk offload, DDP, `model_free_ptq`), serving and smoke-testing in vLLM, troubleshooting and updating. Facts were checked against llm-compressor 0.14.0, compressed-tensors 0.19.0 and vLLM v0.31.0 on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill llm-compressor
```

## Rules

- **Pick the scheme from the GPU.** FP8 W8A8 needs compute capability 8.9+, NVFP4 acceleration needs Blackwell; elsewhere vLLM runs them weight-only.
- **Keep `lm_head` and MoE routers unquantized.**
- **Separate venv from vLLM.** `llmcompressor` pins `torch`, `transformers` and `compressed-tensors` exactly.
- **Calibrate on workload-like, chat-formatted data** and record dataset, split, sample count and sequence length.
- **Test in vLLM, not plain transformers.**
- **Cap memory and stop serving first;** keep the script and package versions with the checkpoint.

## References

- [`references/install.md`](references/install.md): pinned dependencies, venv, platform notes.
- [`references/recipes.md`](references/recipes.md): scheme names, GPU matrix, algorithms, copy-paste recipes.
- [`references/calibration-data.md`](references/calibration-data.md): built-in datasets, custom data, sample counts.
- [`references/big-models.md`](references/big-models.md): memory math, offload, DDP, `model_free_ptq`, MoE, REAP.
- [`references/vllm-integration.md`](references/vllm-integration.md): `vllm serve`, kernels, KV cache, SGLang status.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): safe upgrades.
- [`scripts/inspect-checkpoint.sh`](scripts/inspect-checkpoint.sh): summarize a checkpoint's quantization config (bash, curl, jq).

## Companion skills

- `model-quantization`: format choice, memory caps, quality checks, publishing. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `vllm`: serve and tune the engine. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `nvidia-modelopt`: NVIDIA's PTQ path. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-modelopt`.
- `kv-cache-quantization`: KV cache dtype choices. Install: `npx skills add ScaleDockHQ/llm-skills --skill kv-cache-quantization`.
- `llm-evals`: task evals and gates. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `sglang`: SGLang serving. Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.

## License

MIT
