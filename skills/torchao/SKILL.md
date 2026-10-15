---
name: torchao
description: Quantize, fine-tune and train PyTorch models with torchao (PyTorch AO, pytorch/ao) using quantize_() with Float8, Int8 and Int4 configs, QAT, float8 training and 8-bit or 4-bit optimizers. Use for TorchAoConfig in Transformers or Diffusers, pytorch/*-FP8 or INT4 checkpoints in vLLM, quantization-aware training, torch.compile speedups, and torch or torchao version mismatch, Fatal Python error on import torchao. Not for bitsandbytes NF4, GPTQ, AWQ or GGUF (see bitsandbytes, model-quantization, gguf-quantization).
license: MIT
compatibility: Linux with an NVIDIA GPU (H100, B200 and A100 best supported), AMD, Intel XPU or CPU; Python and a matching PyTorch build (torchao 0.18.0 needs PyTorch 2.11 or newer). Needs curl and jq only for discovery. Installs, GPU runs and Hub uploads need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# torchao

Quantize a PyTorch or Hugging Face model with native torchao configs, keep accuracy with QAT when low-bit PTQ is not enough, speed up training with float8, and serve the result in vLLM.

**Scope:** this one library: install and version pairing, `quantize_()` and `TorchAoConfig`, per-module configs, QAT, quantized training and optimizers, saving and serving, troubleshooting, updating. Picking between quantization formats and quality gates belongs to `model-quantization`.

torchao is a Python API, not a CLI. Write snippets to a script file in the user's work dir, never into this skill. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
python3 --version
python3 -m pip show torchao torch transformers accelerate vllm mslk 2>/dev/null | grep -E '^(Name|Version):'
python3 -c "import torch;print(torch.__version__, torch.version.cuda, torch.cuda.is_available())"
nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv 2>/dev/null
python3 -c "import torchao;print(torchao.__version__)" 2>&1 | tail -2
gh api repos/pytorch/ao/releases/latest --jq '.tag_name' 2>/dev/null
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
```

Ask only what cannot be discovered: base model, serving engine, GPU, whether the goal is inference memory, speed, training speed or accuracy recovery.

## Decision flow

1. The torchao and PyTorch versions are unpaired: fix that first (`references/install.md`). torchao ships compiled kernels built against one torch version.
2. Serving on vLLM and a `pytorch/*` torchao checkpoint exists for the model: use it (`references/serving-and-export.md`).
3. Inference quantization: pick the config from the GPU (`references/inference-quantization.md`): H100 or B200 float8 dynamic, A100 int8 or int4 weight-only, CPU int8 or int4, edge intx.
4. 4-bit accuracy is not good enough: QAT, then convert (`references/qat.md`).
5. Training speed: float8 training (stable, Linear layers); mxfp8 and NVFP4 are prototype (`references/training-and-optimizers.md`).
6. Optimizer memory: `torchao.optim` 8-bit, 4-bit or FP8 AdamW, or CPU offload (`references/training-and-optimizers.md`); bitsandbytes is the alternative (`bitsandbytes`).
7. GGUF, EXL3, AWQ or GPTQ targets: not torchao; use `model-quantization`.

## Rules

- **Pair torchao with the right PyTorch.** Version 0.18.0 dropped PyTorch older than 2.11; a mismatch can abort on `import torchao`. Check the compatibility table (`references/install.md`).
- **Use config objects, not strings.** Transformers needs torchao 0.15.0 or newer and `TorchAoConfig(quant_type=SomeConfig())`; the string API was removed.
- **Pick the dtype from the hardware.** Float8 dynamic needs CUDA compute capability 8.9+ (or AMD MI350+ or Intel XPU); int4 and int8 suit A100; mxfp8 and NVFP4 need Blackwell (SM100+) and are prototype.
- **Prototype means the API can change.** Anything under `torchao.prototype` needs a version pin and a note in the output.
- **Speed needs `torch.compile`.** Without compile, quantized layers can be slower than bf16; Transformers compiles on first `generate` with `cache_implementation="static"`, and recompiles when batch size or `max_new_tokens` changes.
- **Measure before claiming a speed-up.** Upstream benchmarks show weight-only int8 slower than bf16 on H100 decode; quantization saves memory first.
- **Skip fragile layers** with `FqnToConfig` (for example `lm_head`, first-layer attention) and compare to bf16 (`references/inference-quantization.md`).
- **Save with the checkpoint** the script, `pip freeze` of torchao, torch, transformers, and the exact config.
- **Secrets never touch output.** `HF_TOKEN` stays in the environment or a `0600` file; Hub uploads need approval.

## Workflows

### Quantize a model for inference

- [ ] Run discovery; confirm GPU compute capability, torch and torchao versions.
- [ ] Install in a fresh venv (`references/install.md`).
- [ ] Choose a config and write the script (`references/inference-quantization.md`); print memory and one sample generation.
- [ ] Compare to bf16 on real prompts and hand quality gates to `llm-evals`.
- [ ] Save, then serve with vLLM or Transformers (`references/serving-and-export.md`).

### Recover accuracy with QAT

- [ ] Choose a base PTQ config that QAT supports (`references/qat.md`).
- [ ] `quantize_(model, QATConfig(base, step="prepare"))`, fine-tune as usual, then `step="convert"`.
- [ ] Re-evaluate the converted model against plain PTQ.

### Speed up training

- [ ] Confirm H100, B200 or AMD GPU, `torch.compile` and bf16 weights (`references/training-and-optimizers.md`).
- [ ] Convert Linear layers with float8 training or use torchtitan's integration; benchmark against bf16 at the real shapes.

### Debug a failure

- [ ] Match the symptom in `references/troubleshooting.md`; compare versions with the table in `references/install.md`.

### Update

- [ ] Follow `references/updating.md`: read release notes for removed APIs, upgrade torch and torchao together in a fresh venv, rerun a small model.

## Verify before done

- [ ] `import torchao` works and versions match the compatibility table.
- [ ] Quantized model generates coherent text and memory dropped as expected.
- [ ] Timing was measured with compile on, against bf16, at the real batch size.
- [ ] Config, versions and script are saved with the output; nothing secret was printed.

## Reference index

- `references/install.md`: pip and index URLs, optional kernels (MSLK), torch pairing, source build.
- `references/inference-quantization.md`: configs by hardware, `TorchAoConfig`, `quantize_`, per-module configs, autoquant, benchmarks.
- `references/qat.md`: prepare and convert, supported base configs.
- `references/training-and-optimizers.md`: float8 and mx training, low-bit optimizers, CPU offload.
- `references/serving-and-export.md`: saving, Hub checkpoints, vLLM, ExecuTorch, Diffusers.
- `references/troubleshooting.md`: errors and fixes.
- `references/updating.md`: release sources and safe upgrade.

## Companion skills

- `model-quantization`: pick a format and gate quality. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `bitsandbytes`: NF4 QLoRA and 8-bit optimizers when torchao is not the right tool. Install: `npx skills add ScaleDockHQ/llm-skills --skill bitsandbytes`.
- `vllm`: serve torchao checkpoints. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `llm-compressor`: calibrated FP8 and W4A16 for vLLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-compressor`.
- `fine-tuning-llms`: pick a training stack and data. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `llm-evals`: quality gates. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
