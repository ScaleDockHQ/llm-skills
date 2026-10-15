---
name: hqq
description: Quantize LLMs to 8, 4, 3, 2 or 1 bit in minutes with HQQ (Half-Quadratic Quantization, dropbox/hqq, the hqq package), no calibration data needed. Use for HqqConfig in Transformers, HQQLinear, BaseQuantizeConfig, axis and group_size choices, GemLite or torchao_int4 fused-kernel backends, HQQ plus LoRA training, on-the-fly HQQ in vLLM, and errors from prepare_for_inference or saved-model loading. Not for GPTQ, AWQ, GGUF or NF4 QLoRA (see model-quantization, bitsandbytes, gguf-quantization).
license: MIT
compatibility: Linux with an NVIDIA GPU for fused kernels (CUDA build optional); PyTorch 2 and Python with pip install hqq. Intel XPU runs the pure PyTorch path. Needs curl and jq only for discovery. Installs and Hub uploads need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# HQQ

Quantize a Hugging Face model without a calibration set using Half-Quadratic Quantization, choose group size and axis for the kernel that will run it, and check quality before serving.

**Scope:** this one library: install, `HqqConfig` and `BaseQuantizeConfig`, per-layer configs, inference backends, saving and loading, PEFT training, vLLM on-the-fly use, troubleshooting, updating. Choosing between quantization tools and quality gates belongs to `model-quantization`.

HQQ is a Python library (no CLI). Write snippets to a script in the user's work dir, never into this skill. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
python3 --version
python3 -m pip show hqq torch transformers accelerate gemlite torchao vllm 2>/dev/null | grep -E '^(Name|Version):'
python3 -c "import torch;print(torch.__version__, torch.version.cuda, torch.cuda.is_available())"
nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv 2>/dev/null
gh api repos/dropbox/hqq/releases/latest --jq '.tag_name,.published_at' 2>/dev/null
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
```

Ask only what cannot be discovered: base model, target bit width, GPU, serving engine, and whether the goal is memory, speed or training.

## Decision flow

1. A calibrated 4-bit format (AWQ, GPTQ) or FP8 is acceptable and the engine supports it: prefer it for serving (`model-quantization`, `llm-compressor`). HQQ shines when there is no calibration data, time is short, or you need 3, 2 or 1 bit.
2. Start with `nbits=4, group_size=64, axis=1` (`references/quantize.md`); this is upstream's balance of quality, VRAM and speed and the only setting the fused kernels support.
3. Need better quality at the same VRAM: `axis=0` with the ATEN backend, accepting no fused-kernel inference.
4. Need speed: quantize with `axis=1`, then `prepare_for_inference(model, backend="gemlite")` (fp16 compute) or `"torchao_int4"` (bf16 compute, small batch) (`references/backends-and-inference.md`).
5. Training on a quantized base: PEFT with HQQ, or HQQ+ low-rank adapters (`references/serving-and-training.md`).
6. Serving in vLLM: on-the-fly HQQ through `hqq.utils.vllm` with GemLite installed, or a safetensors export (`references/serving-and-training.md`).

## Rules

- **Default to `nbits=4, group_size=64, axis=1`.** Change one thing at a time and compare perplexity or task evals.
- **Fused kernels need `axis=1`** and extra group-size limits per backend; unsupported settings silently fall back to the native backend, so check speed, not just that it runs.
- **`HQQBackend.ATEN` supports only `axis=0`.**
- **Match compute dtype to the backend:** `float16` for GemLite, `bfloat16` for `torchao_int4`.
- **Save before patching.** `AutoHQQHFModel.save_quantized` must run before `prepare_for_inference`; models saved through the hqq library do not load with `from_pretrained` (use `save_to_safetensors` for that).
- **Low bit costs quality.** 3, 2 and 1 bit need evals; HQQ+ adapters (trainable low-rank) can recover quality at low bits; never ship them untested.
- **Keep `lm_head` and vision towers out** when serving in vLLM (`skip_modules`).
- **Record versions** (`pip freeze` for hqq, torch, transformers, gemlite) and the full config with the checkpoint.
- **Secrets never touch output.** `HF_TOKEN` stays in the environment or a `0600` file; Hub uploads need approval.

## Workflows

### Quantize a model

- [ ] Run discovery; confirm GPU, torch and free VRAM (quantization can run on CPU first, then move).
- [ ] Install in a fresh venv (`references/install.md`).
- [ ] Write the script with `HqqConfig` (Transformers) or `AutoHQQHFModel.quantize_model` (`references/quantize.md`).
- [ ] Print a sample generation and VRAM; compare with the bf16 model on real prompts; hand quality gates to `llm-evals`.
- [ ] Save in the format the consumer needs (`references/serving-and-training.md`).

### Make it fast

- [ ] Confirm `axis=1` and the compute dtype, call `prepare_for_inference` with a backend, benchmark tokens per second against the native backend (`references/backends-and-inference.md`).

### Train on top

- [ ] PEFT LoRA on the HQQ model, or `PeftUtils.add_lora` (`references/serving-and-training.md`).

### Debug a failure

- [ ] Match the symptom in `references/troubleshooting.md`.

### Update

- [ ] Follow `references/updating.md`: check releases, upgrade in a fresh venv, rerun a small model.

## Verify before done

- [ ] A sample generation is coherent and VRAM shows the saving.
- [ ] If speed matters, tokens per second were measured with the backend active.
- [ ] Config, versions and script are saved with the output; the saved checkpoint reloads.
- [ ] Nothing secret was printed.

## Reference index

- `references/install.md`: pip, git install, CUDA kernel build, compatibility.
- `references/quantize.md`: parameters, Transformers and hqq-lib paths, per-layer configs.
- `references/backends-and-inference.md`: native backends, GemLite, torchao_int4, speed expectations.
- `references/serving-and-training.md`: saving, loading, vLLM, PEFT and HQQ+.
- `references/troubleshooting.md`: errors and fixes.
- `references/updating.md`: release sources and safe upgrade.

## Companion skills

- `model-quantization`: pick a format and gate quality. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `torchao`: HQQ is also an int4 qparams algorithm there. Install: `npx skills add ScaleDockHQ/llm-skills --skill torchao`.
- `bitsandbytes`: NF4 QLoRA. Install: `npx skills add ScaleDockHQ/llm-skills --skill bitsandbytes`.
- `vllm`: serve the model. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `llm-compressor`: calibrated FP8 and W4A16. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-compressor`.
- `llm-evals`: quality gates. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
