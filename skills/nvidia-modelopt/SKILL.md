---
name: nvidia-modelopt
description: Quantize LLMs with NVIDIA Model Optimizer (ModelOpt, nvidia-modelopt, NVIDIA/Model-Optimizer, formerly TensorRT-Model-Optimizer). Covers hf_ptq.py post-training quantization to NVFP4, FP8, INT4 AWQ and MXFP8, recipes, AutoQuantize, KV cache formats, and export to a unified Hugging Face checkpoint with hf_quant_config.json for TensorRT-LLM, vLLM and SGLang on Blackwell, Hopper, Ada and DGX Spark. Use to make nvidia/*-NVFP4 style checkpoints, pick a qformat or recipe, deploy a ModelOpt checkpoint, or fix errors like "No module named modelopt", "examples/llm_ptq not found", unknown qformat. Not for GGUF, EXL3, MLX or compressed-tensors (see model-quantization, llm-compressor).
license: MIT
compatibility: Linux (x86_64 or aarch64) with an NVIDIA GPU, Python 3.10 to 3.14, CUDA 12.x or 13.x and PyTorch 2.8 or newer. NVFP4 inference needs Blackwell. Needs git, and curl and jq for the helper script. Installs, long calibration runs and Hub uploads need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA Model Optimizer

Quantize a Hugging Face model with ModelOpt's `hf_ptq.py` and export a unified Hugging Face checkpoint that TensorRT-LLM, vLLM and SGLang load, then verify it in the engine you will serve with.

**Scope:** this one library: install, PTQ with `hf_ptq.py`, recipes, KV cache, export, deployment checks, troubleshooting, updating. ModelOpt also does QAT, pruning, distillation, speculative decoding, sparsity, ONNX and diffusers; those are out of scope here (see upstream). Cross-tool choices, quality gates and publishing belong to `model-quantization`.

Package and repo names: the PyPI package is `nvidia-modelopt` (import `modelopt`), the repo is `NVIDIA/Model-Optimizer`. The old `NVIDIA/TensorRT-Model-Optimizer` name redirects; upstream rebranded to "NVIDIA Model Optimizer" on 2025-12-08. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
nvidia-smi --query-gpu=name,compute_cap,memory.total,memory.used --format=csv 2>/dev/null
uname -m; python3 --version; free -h 2>/dev/null; df -h . ~/.cache/huggingface 2>/dev/null
python3 -m pip show nvidia-modelopt torch transformers 2>/dev/null | grep -E '^(Name|Version):'
command -v vllm trtllm-serve; python3 -c "import tensorrt_llm" 2>/dev/null && echo "found tensorrt_llm"
ls ~/src/Model-Optimizer/examples/hf_ptq/hf_ptq.py 2>/dev/null
docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
scripts/inspect-checkpoint.sh <dir-or-hub-id>    # is a model already ModelOpt-quantized, and with which algo?
```

Ask only what cannot be discovered: base model and revision, the engine and GPU that will serve it (NVFP4 needs Blackwell to be fast), the quality or size target, and whether the user's workload data exists for calibration.

## Decision flow

1. An official `nvidia/*-FP8` or `*-NVFP4` checkpoint for the model exists (NVIDIA's ModelOpt collection on the Hub): use it (`self-hosted-llms`), skip quantizing.
2. Target is vLLM or SGLang only and compressed-tensors is fine: `llm-compressor` is the vLLM project's own tool. Target is TensorRT-LLM, NVIDIA recipes, or NVIDIA parity: stay here.
3. Blackwell (compute capability 10.0+/12.x): `nvfp4` family or `fp8`. Hopper or Ada: `fp8`. Ampere: `int4_awq` (`references/ptq-recipes.md`, Choosing a format).
4. Accuracy first for NVFP4: `nvfp4_mlp_only`, `nvfp4_experts_only` or `nvfp4_omlp_only` rather than plain `nvfp4`.
5. Mixed precision to a bit budget: an AutoQuantize recipe (`references/ptq-recipes.md`).
6. Model too big for the GPU: `--low_memory_mode`, `--use_seq_device_map`, disk offload flags, or multi-node `--use_fsdp2` (`references/ptq-recipes.md`, Memory).

## Rules

- **Run `hf_ptq.py` directly, not as a black box.** `scripts/huggingface_example.sh` also runs a TensorRT-LLM smoke test by default and writes `saved_models_*` into the repo clone; use it only when TensorRT-LLM is installed.
- **Pin the clone to the release tag you installed** (`git checkout 0.47.0`): scripts, recipes and flags change between releases and old qformat aliases were removed.
- **Use current names.** `examples/hf_ptq` (not `llm_ptq`), preset basenames such as `nvfp4_awq_lite`, `--recipe` for AutoQuantize (not `--auto_quantize_bits`), and no `--export_fmt` (deprecated).
- **NVFP4 needs Blackwell for speed.** On other GPUs vLLM and SGLang run it weight-only (Marlin fallback); read the engine log.
- **Calibrate on workload-like data** and record the dataset, `--calib_size`, `--calib_seq`, qformat or recipe, KV cache format and the ModelOpt version.
- **Test in the exact engine you will serve with.** Support is per model architecture and per engine version; ModelOpt's support matrix is a load-and-generate smoke test, not an accuracy guarantee.
- **Cap memory and stop serving first.** Calibration loads the full BF16 model; on unified-memory machines like DGX Spark use a capped scope (`model-quantization`, memory-safety).
- **Install into a venv or NGC container,** and read third-party license notices upstream warns about.
- **Secrets never touch output.** `HF_TOKEN` stays in the environment or a `0600` file.

## Workflows

### Quantize with hf_ptq.py

- [ ] Run discovery; confirm GPU, free RAM, VRAM and disk (the export is a full checkpoint).
- [ ] Install ModelOpt and check out the matching tag (`references/install.md`).
- [ ] Choose qformat or recipe and the KV cache format (`references/ptq-recipes.md`).
- [ ] Choose calibration data (`references/ptq-recipes.md`, Calibration).
- [ ] Run `python hf_ptq.py --pyt_ckpt_path <model> --qformat <q> --export_path <dir>` in a capped scope; add `--trust_remote_code` only for models that need it.
- [ ] Check the export with `scripts/inspect-checkpoint.sh <dir>` (`quant_algo`, excluded modules, KV cache).

### Deploy and verify

- [ ] Pick the engine and flags (`references/export-and-deploy.md`).
- [ ] Start it, check `/health` and `/v1/models`, read the startup log for the quantization method and GEMM backend used.
- [ ] Run smoke prompts and compare with the base (`model-quantization`, `llm-evals`).

### Debug a failed run

- [ ] Match the symptom in `references/troubleshooting.md` (renamed paths, removed flags, OOM, empty weight-quantizer match, engine load errors).

### Update

- [ ] Follow `references/updating.md`: read the changelog, move to a fresh venv and tag, re-run one small model first.

## Reference index

- `references/install.md`: requirements, pip extras, containers, clone and tag, DGX Spark notes.
- `references/ptq-recipes.md`: `hf_ptq.py` arguments, qformat presets, recipes, KV cache, AutoQuantize, MoE, VLM, MXFP4 to NVFP4, memory options, calibration data.
- `references/export-and-deploy.md`: unified HF checkpoint, `hf_quant_config.json`, vLLM, SGLang, TensorRT-LLM, minimum versions, legacy TRT-LLM checkpoints.
- `references/troubleshooting.md`: errors and fixes.
- `references/updating.md`: upgrading and release tracking.
- `scripts/inspect-checkpoint.sh`: summarize a checkpoint's quantization config (bash, curl, jq).

## Companion skills

- `model-quantization`: pick a format for an engine, memory caps, quality checks and Hub publishing. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `llm-compressor`: the vLLM project's quantizer producing compressed-tensors checkpoints. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-compressor`.
- `tensorrt-llm`: serve and tune TensorRT-LLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`.
- `vllm`: serve and tune vLLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `sglang`: serve and tune SGLang. Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.
- `kv-cache-quantization`: KV cache dtype choices at serve time. Install: `npx skills add ScaleDockHQ/llm-skills --skill kv-cache-quantization`.
- `llm-evals`: task evals and quality gates. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
