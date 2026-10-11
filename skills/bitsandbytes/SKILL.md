---
name: bitsandbytes
description: Load and train LLMs in 8-bit and 4-bit with bitsandbytes (LLM.int8(), NF4/FP4 QLoRA, 8-bit and paged optimizers) through Transformers, PEFT, TRL and Accelerate. Use for BitsAndBytesConfig, load_in_4bit, QLoRA or FSDP-QLoRA setup, Adam8bit and paged_adamw, serving a bnb checkpoint in vLLM, and errors such as no kernel image available, No compatible CUDA library found, libbitsandbytes not found. Not for GPTQ, AWQ, GGUF or FP8 export (see model-quantization, llm-compressor, gguf-quantization).
license: MIT
compatibility: Linux, Windows or macOS with Python 3.10+ and PyTorch 2.4+. NVIDIA, AMD, Intel XPU, Intel Gaudi and CPU backends. Needs curl and jq only for the discovery commands. Installs, source builds and long training runs need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# bitsandbytes

Fit a model into less memory with on-the-fly 8-bit or 4-bit weights, fine-tune it with QLoRA, or cut optimizer memory with 8-bit optimizers, then prove the result still behaves.

**Scope:** this one library: install and backend selection, `BitsAndBytesConfig`, QLoRA and FSDP-QLoRA, 8-bit optimizers, saving and serving bnb checkpoints, troubleshooting, updating. Choosing between quantization formats, quality gates and publishing belong to `model-quantization`.

bitsandbytes is a quantize-at-load library: there is no CLI and no calibration. Every use is a few lines of Python around Transformers; write them to a script in the user's work dir, never into this skill. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
python3 --version
python3 -m pip show bitsandbytes torch transformers peft accelerate trl 2>/dev/null | grep -E '^(Name|Version):'
nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv 2>/dev/null
rocm-smi --showproductname 2>/dev/null | head -5
python3 -m bitsandbytes 2>&1 | tail -25       # upstream diagnostics: backend, library found, sanity check
python3 -c "import torch;print(torch.__version__, torch.version.cuda, torch.version.hip)"
free -h 2>/dev/null; df -h . ~/.cache/huggingface 2>/dev/null
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
```

Ask only what cannot be discovered: the base model, the goal (inference memory, QLoRA training, optimizer memory, or a serving format), the GPU or accelerator, and the quality target.

## Decision flow

1. The goal is a fast serving format on a GPU server: bitsandbytes is usually not it. NF4 and LLM.int8() trade speed for memory; use `model-quantization` to pick FP8, AWQ or GPTQ (`llm-compressor`, `gptqmodel`).
2. The goal is fine-tuning a model that does not fit in bf16: QLoRA (`references/quantize-and-load.md`, then `references/qlora-training.md`). Several GPUs: FSDP-QLoRA in the same file.
3. The goal is inference memory only: NF4 (4-bit) for most memory saved, LLM.int8() (8-bit) for the closest quality; both in `references/quantize-and-load.md`.
4. Optimizer state is the bottleneck while training in full or LoRA: `bnb.optim.*8bit` or `paged_adamw_*` (`references/optimizers.md`).
5. The model must be served: pre-quantized bnb checkpoints load in vLLM through the out-of-tree plugin; in-flight 4-bit is also supported (`references/serving-and-export.md`). Otherwise merge the adapter into bf16 and quantize with a serving format.
6. The install or import fails: `references/install.md`, then `references/troubleshooting.md`.

## Rules

- **Check the backend first.** `python3 -m bitsandbytes` tells you whether the native library loaded for this PyTorch build. Fix that before debugging models.
- **LLM.int8() needs compute capability 7.5+ on NVIDIA** (Turing, T4 and newer); NF4/FP4 and 8-bit optimizers need 6.0+ (`references/install.md`).
- **Use `nf4` with `bnb_4bit_compute_dtype=torch.bfloat16`** for training and normally for inference. The default compute dtype is float32, which is slow, and float16 can be unstable.
- **Training a quantized model trains only extra parameters** (LoRA adapters). Full-weight training of an 8-bit or 4-bit model is not supported.
- **Keep `lm_head` and embeddings out of 8-bit conversion** when output quality drops (`llm_int8_skip_modules`); see `references/quantize-and-load.md`.
- **For FSDP-QLoRA set `bnb_4bit_quant_storage` equal to the model dtype,** otherwise FSDP wraps each `Linear4bit` layer separately.
- **Do not expect a speed-up.** Quantized kernels save memory; throughput is often lower than bf16. Measure with `llm-evals` and the engine's own bench before promising anything.
- **Do not quantize twice.** Loading an already bnb-quantized checkpoint takes no `quantization_config`.
- **Pin versions and record them** (`pip freeze` for bitsandbytes, torch, transformers, peft, trl) with the adapter or checkpoint.
- **Secrets never touch output.** `HF_TOKEN` stays in the environment or a `0600` file. Hub uploads need approval.

## Workflows

### Load a model in 4-bit or 8-bit

- [ ] Run the discovery block; confirm the diagnostics pass and free VRAM (about 0.5 to 0.6 bytes per parameter for NF4, 1 byte for int8, plus activations and KV cache).
- [ ] Create a venv and install (`references/install.md`).
- [ ] Write the `BitsAndBytesConfig` script (`references/quantize-and-load.md`), print `model.get_memory_footprint()` and one sample generation.
- [ ] Compare against the bf16 model on a few real prompts before relying on it; hand quality gates to `llm-evals`.

### QLoRA fine-tune

- [ ] Load the base in NF4 with bf16 compute, `prepare_model_for_kbit_training`, LoRA on `all-linear` (`references/qlora-training.md`).
- [ ] Train with TRL `SFTTrainer` (see `trl` for recipes) or the user's trainer; add `optim="paged_adamw_8bit"` if memory is tight.
- [ ] Save the adapter, and merge into a bf16 copy of the base (not into the 4-bit weights) before serving (`references/serving-and-export.md`).
- [ ] More than one GPU and a model too big for one: FSDP-QLoRA (`references/qlora-training.md`).

### Use 8-bit optimizers

- [ ] Swap `torch.optim.Adam` for `bnb.optim.Adam8bit`, embeddings for `bnb.nn.StableEmbedding` on NLP models (`references/optimizers.md`).
- [ ] Keep unstable tensors in 32-bit with `GlobalOptimManager` if loss diverges.

### Serve a bnb checkpoint

- [ ] Confirm the checkpoint's `quantization_config` has `quant_method: bitsandbytes` (`references/serving-and-export.md`).
- [ ] Install the vLLM plugin and serve; smoke-test with a chat request (`vllm` skill).

### Debug a failure

- [ ] Run `python3 -m bitsandbytes`, match the symptom in `references/troubleshooting.md`.
- [ ] Compare `torch.version.cuda` with the shipped library versions in `references/install.md`.

### Update

- [ ] Follow `references/updating.md`: read release notes, upgrade in a fresh venv, re-run the diagnostics and one small model.

## Verify before done

- [ ] `python3 -m bitsandbytes` reports success on the target machine.
- [ ] A sample generation from the quantized model is coherent and `get_memory_footprint()` shows the expected saving.
- [ ] Training runs log a falling loss and the adapter reloads onto a fresh base.
- [ ] Versions and the script are saved with the output; nothing secret was printed.

## Reference index

- `references/install.md`: requirements, hardware table, per-backend install, source build, preview wheels, environment overrides.
- `references/quantize-and-load.md`: `BitsAndBytesConfig` options for 8-bit and 4-bit, offload, skip modules, dequantize, memory checks.
- `references/qlora-training.md`: QLoRA with PEFT and TRL, FSDP-QLoRA, memory levers.
- `references/optimizers.md`: 8-bit and paged optimizers, `min_8bit_size`, overrides, Trainer strings.
- `references/serving-and-export.md`: saving and pushing, merging adapters, vLLM, other engines.
- `references/troubleshooting.md`: errors and fixes.
- `references/updating.md`: release sources and safe upgrade.

## Companion skills

- `model-quantization`: pick a format for an engine, quality checks, Hub publishing. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `fine-tuning-llms`: choose a fine-tuning stack and data. Install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`.
- `trl`: SFT and preference training that consumes a bnb-quantized base. Install: `npx skills add ScaleDockHQ/llms-skills --skill trl`.
- `unsloth`: faster QLoRA on a single GPU. Install: `npx skills add ScaleDockHQ/llms-skills --skill unsloth`.
- `vllm`: serve the checkpoint. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `llm-compressor`: serving-grade quantization (FP8, W4A16). Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-compressor`.
- `llm-evals`: quality gates for the quantized model. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
