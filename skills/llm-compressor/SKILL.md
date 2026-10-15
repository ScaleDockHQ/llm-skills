---
name: llm-compressor
description: Quantize LLMs for vLLM with LLM Compressor (llmcompressor, vllm-project/llm-compressor). Covers oneshot() recipes for FP8, INT8, W4A16 (GPTQ, AWQ), NVFP4, MXFP4, KV cache, MoE and multimodal models, saved as compressed-tensors checkpoints. Use to quantize a Hugging Face model, pick a scheme for a GPU, choose calibration data, fit a huge model with disk offload or DDP, serve with vllm serve, or fix OOM during calibration, transformers version errors and FP8 not supported on this GPU. Not for GGUF, EXL3, MLX or ModelOpt (see model-quantization, nvidia-modelopt).
license: MIT
compatibility: Linux with an NVIDIA GPU (calibration) and Python 3.10 or newer; pip installs llmcompressor. Serving needs vLLM in a separate venv. Needs curl and jq for the helper script. Installs, long calibration runs and Hub uploads need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LLM Compressor

Turn a Hugging Face model into a compressed-tensors checkpoint (FP8, INT8, W4A16, NVFP4, MXFP4, ...) that `vllm serve` loads directly, then prove it still works.

**Scope:** this one library: install, scheme and algorithm choice, calibration, big-model memory tricks, saving, vLLM serving, troubleshooting, updating. Choosing between quantization tools, GGUF/EXL3/MLX, quality gates and publishing belong to `model-quantization`.

There is no CLI: every run is a short Python script around `oneshot()` (or `model_free_ptq()`). Python snippets live in the references; write them to a script file in the user's work dir, never into this skill. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv 2>/dev/null
free -h 2>/dev/null; df -h . ~/.cache/huggingface 2>/dev/null
python3 --version
python3 -m pip show llmcompressor compressed-tensors transformers torch vllm 2>/dev/null | grep -E '^(Name|Version):'
command -v vllm uv conda
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
scripts/inspect-checkpoint.sh <dir-or-hub-id>   # is a model already compressed-tensors, and which scheme?
```

Ask only what cannot be discovered: the base model and revision, the GPU/engine that will serve it, the size or quality target, and whether calibration data from the real workload exists.

## Decision flow

1. A compressed-tensors checkpoint for this model and scheme already exists and is trusted: use it (`self-hosted-llms`), skip quantizing.
2. Pick the scheme from the GPU's compute capability (`references/recipes.md`, Choosing a scheme): 8.9+ FP8, 10.0+ NVFP4/MXFP4, older GPUs W4A16 (or INT8 W8A8).
3. No calibration data needed (FP8_DYNAMIC, FP8_BLOCK, MXFP4 with RTN, weight-only data-free): run `oneshot(model=..., recipe=QuantizationModifier(...))`. Needs data (GPTQ, AWQ, SmoothQuant, NVFP4, static activation scales): add `dataset=`, `num_calibration_samples=`, `max_seq_length=` (`references/calibration-data.md`).
4. The model has no transformers definition, `oneshot` fails on it, or the scheme is data-free and the model is huge: `model_free_ptq()` (`references/big-models.md`).
5. The model does not fit in RAM or VRAM: sequential onloading, `auto_offload` disk offload, DDP (`references/big-models.md`).
6. The target is TensorRT-LLM, or you want NVIDIA's own recipes: use `nvidia-modelopt` instead.

## Rules

- **Pick the scheme from the GPU, not the other way round.** FP8 W8A8 needs compute capability 8.9+, NVFP4 acceleration needs Blackwell (10.0+); on other GPUs vLLM runs these weight-only. Check `references/recipes.md` first.
- **Keep `lm_head` out of quantization,** and for MoE models also the router/gate (`ignore=["lm_head", "re:.*mlp.gate$"]`); multimodal vision towers are not quantized.
- **Use a separate venv from vLLM.** Upstream says they can have dependency mismatches; `llmcompressor` pins `torch`, `transformers` and `compressed-tensors` exactly (`references/install.md`).
- **Calibrate on workload-like data,** chat-formatted for chat models, 128 to 512 samples to start; record dataset, split, sample count and sequence length.
- **Save with `save_pretrained(dir, save_compressed=True)`** (or `output_dir=` in `oneshot`) and save the tokenizer next to it.
- **Test in vLLM, not transformers.** A compressed-tensors model run through plain transformers decompresses and gains nothing.
- **Cap memory and stop serving first.** Calibration loads the full model; on unified-memory machines use a memory-capped scope (`model-quantization`, memory-safety).
- **Keep the script with the checkpoint** and the output of `pip freeze` for `llmcompressor`, `compressed-tensors`, `transformers`, `torch`.
- **Secrets never touch output.** `HF_TOKEN` stays in the environment or a `0600` file.

## Workflows

### Quantize a model

- [ ] Run the discovery block; confirm GPU compute capability and free RAM, VRAM, disk (about 2 bytes per parameter for the BF16 source, plus the output).
- [ ] Create a venv and install (`references/install.md`).
- [ ] Choose scheme and algorithm (`references/recipes.md`).
- [ ] Choose calibration data if the recipe needs it (`references/calibration-data.md`).
- [ ] Write the script, run it inside a memory-capped scope, read the sample generation it prints.
- [ ] Inspect the output with `scripts/inspect-checkpoint.sh` (scheme, ignore list, format).
- [ ] Serve and smoke-test in vLLM (`references/vllm-integration.md`); hand quality gates to `model-quantization` and `llm-evals`.

### Fit a huge or MoE model

- [ ] Estimate CPU and GPU memory per algorithm (`references/big-models.md`, Memory).
- [ ] Load with `load_context()` and `device_map="auto_offload"` and a disk `offload_folder`.
- [ ] MoE: keep `moe_calibrate_all_experts=True` (default) and ignore the router (`references/big-models.md`, MoE).
- [ ] Several GPUs: run the same script under `torchrun` with `init_dist()`.

### Debug a failed run

- [ ] Match the symptom in `references/troubleshooting.md` (OOM, `transformers` version, saving errors, accuracy drop, vLLM load errors).
- [ ] Compare versions with `pip freeze` and the pins in `references/install.md`.

### Update

- [ ] Follow `references/updating.md`: read the release notes, bump in a fresh venv, re-run one small model before a big one.

## Reference index

- `references/install.md`: pinned dependencies, venv, DGX Spark and containers, import check.
- `references/recipes.md`: scheme names, GPU matrix, algorithms, copy-paste recipes for FP8, INT8, W4A16, AWQ, NVFP4, KV cache, W4AFP8.
- `references/calibration-data.md`: built-in dataset names, custom datasets, sample counts, chat templates.
- `references/big-models.md`: memory math, sequential onloading, disk offload, DDP, `model_free_ptq`, MoE, REAP.
- `references/vllm-integration.md`: `vllm serve` flags, kernel selection, KV cache, SGLang status, verifying the load.
- `references/troubleshooting.md`: errors and fixes.
- `references/updating.md`: upgrading llmcompressor, compressed-tensors, vLLM.
- `scripts/inspect-checkpoint.sh`: prints the `quantization_config` summary of a local dir or Hub repo (bash, curl, jq).

## Companion skills

- `model-quantization`: pick a format for an engine, memory caps, quality checks and Hub publishing. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `vllm`: serve the checkpoint and tune the engine. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `nvidia-modelopt`: NVIDIA's PTQ path for TensorRT-LLM, vLLM and SGLang. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-modelopt`.
- `kv-cache-quantization`: KV cache dtype choices at serve time. Install: `npx skills add ScaleDockHQ/llm-skills --skill kv-cache-quantization`.
- `llm-evals`: task evals and quality gates for the quant. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `sglang`: serve compressed-tensors checkpoints on SGLang (partial support). Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.
