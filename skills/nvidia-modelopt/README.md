# NVIDIA Model Optimizer Skill

An agent skill for quantizing Hugging Face LLMs with [NVIDIA Model Optimizer](https://github.com/NVIDIA/Model-Optimizer) (ModelOpt, PyPI `nvidia-modelopt`, formerly `NVIDIA/TensorRT-Model-Optimizer`): post-training quantization with `hf_ptq.py` to NVFP4, FP8, INT4 AWQ and MXFP8, recipes, AutoQuantize, KV cache formats, and export to a unified Hugging Face checkpoint (`hf_quant_config.json`) that [TensorRT-LLM](https://github.com/NVIDIA/TensorRT-LLM), [vLLM](https://github.com/vllm-project/vllm) and [SGLang](https://github.com/sgl-project/sglang) load. It targets Blackwell, Hopper, Ada, Ampere and DGX Spark, and covers install, memory options, deployment checks, troubleshooting and updating. Facts were checked against ModelOpt 0.47.0, vLLM v0.31.0, SGLang v0.5.21 and TensorRT-LLM v1.2.1 on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill nvidia-modelopt
```

## Rules

- **Run `hf_ptq.py` directly,** from a clone checked out at the installed tag; the wrapper script also runs a TensorRT-LLM smoke test.
- **Use current names:** `examples/hf_ptq`, preset basenames, `--recipe` for AutoQuantize.
- **NVFP4 needs Blackwell for speed;** elsewhere engines run it weight-only.
- **Calibrate on workload-like data** and record the full recipe next to the checkpoint.
- **Test in the exact engine you will serve with** and read its startup log.
- **Cap memory and stop serving first.**

## References

- [`references/install.md`](references/install.md): requirements, pip extras, containers, clone and tag, DGX Spark.
- [`references/ptq-recipes.md`](references/ptq-recipes.md): `hf_ptq.py` arguments, qformats, recipes, KV cache, AutoQuantize, memory, calibration.
- [`references/export-and-deploy.md`](references/export-and-deploy.md): unified checkpoint, vLLM, SGLang, TensorRT-LLM, minimum versions.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): safe upgrades and release tracking.
- [`scripts/inspect-checkpoint.sh`](scripts/inspect-checkpoint.sh): summarize a checkpoint's quantization config (bash, curl, jq).

## Companion skills

- `model-quantization`: format choice, memory caps, quality checks, publishing. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `llm-compressor`: the vLLM project's quantizer (compressed-tensors). Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-compressor`.
- `tensorrt-llm`: TensorRT-LLM serving. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`.
- `vllm`: vLLM serving. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `sglang`: SGLang serving. Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.
- `kv-cache-quantization`: KV cache dtype choices. Install: `npx skills add ScaleDockHQ/llm-skills --skill kv-cache-quantization`.
- `llm-evals`: task evals and gates. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.

## License

MIT
