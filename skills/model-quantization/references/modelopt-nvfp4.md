# NVFP4 and FP8 with NVIDIA Model Optimizer

> Verified against NVIDIA/Model-Optimizer 0.47.0 (README.md, examples/hf_ptq/README.md), vLLM v0.31.0 (docs/features/quantization/modelopt.md), 2026-10-11

## How it plugs into this stack

- Use ModelOpt when the target is TensorRT-LLM, or you want NVIDIA's NVFP4 or FP8 recipes for Blackwell (B200, RTX PRO and 50-series, DGX Spark GB10) or FP8 for Hopper and Ada (`formats.md`). For vLLM-first workflows LLM Compressor produces equivalent schemes in compressed-tensors.
- In: HF checkpoint. Out: a unified HF checkpoint directory with `hf_quant_config.json` that TensorRT-LLM, vLLM and SGLang load. The PTQ entry point is `examples/hf_ptq/hf_ptq.py` in the `NVIDIA/Model-Optimizer` repo (PyPI `nvidia-modelopt`); the old `examples/llm_ptq` path no longer exists in 0.47.0.
- Calibration loads the full BF16 model: stop serving first and cap memory on unified-memory nodes such as DGX Spark (`memory-safety.md`).
- NVFP4 needs Blackwell for speed; elsewhere engines run it weight-only. Read the engine's startup log for the kernel actually used (`formats.md`, Hardware notes), then smoke-test and compare with the base (`quality-checks.md`) and record ModelOpt version, qformat or recipe, KV format and calibration data in the card (`publishing.md`).

Depth: install the nvidia-modelopt skill (npx skills add ScaleDockHQ/llm-skills --skill nvidia-modelopt)
