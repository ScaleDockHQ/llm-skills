---
name: peft
description: PEFT is Hugging Face's parameter-efficient fine-tuning library (LoraConfig, get_peft_model, PeftModel, merge_and_unload) for LoRA, QLoRA, DoRA, rsLoRA, IA3, prompt tuning and many more adapters on Transformers models. Use to add adapters in a Python training script, pick target_modules and rank, train quantized models, save, load, hot-swap, combine or merge adapters, or fix target-module, fp16 unscale, adapter-config and not-improving-after-training problems. Not for CLI trainers (trl, axolotl, llama-factory, unsloth); method choice is fine-tuning-llms.
license: MIT
compatibility: Linux, macOS or Windows with PyTorch (CUDA, ROCm, XPU or CPU), Python 3.10+, pip or uv. Uses peft, transformers, curl and jq via shell. Installs and training runs need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# PEFT

Wrap a Transformers model with small trainable adapters, train it with any trainer or loop, then save, load, combine or merge the adapter.

**Scope:** this one library: install, configure adapters, train, scale out, save/load/merge, update, troubleshoot. Whether to fine-tune, data prep and method choice belong to `fine-tuning-llms`. Full trainers (SFT, DPO, GRPO) belong to `trl`, `axolotl`, `llama-factory` and `unsloth`, which all call PEFT underneath.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
python3 --version; command -v uv accelerate
python3 -c 'import peft, transformers, torch; print("peft", peft.__version__, "transformers", transformers.__version__, "torch", torch.__version__, "cuda", torch.cuda.is_available())' 2>/dev/null
pip list 2>/dev/null | grep -iE '^(peft|transformers|trl|accelerate|bitsandbytes|deepspeed|torchao|vllm) '
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>/dev/null
free -h 2>/dev/null | head -2; df -h . ~/.cache/huggingface 2>/dev/null
find . -maxdepth 3 -name adapter_config.json 2>/dev/null | head
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
```

If you find an `adapter_config.json`, read it: it names the base model, the PEFT type and the `target_modules`.

## Decision flow

1. A script or notebook needs adapters -> `get_peft_model` with a `LoraConfig` (`references/lora-config.md`).
2. Want a CLI, not Python -> use `trl`, `axolotl`, `llama-factory` or `unsloth`.
3. Model does not fit -> quantize the base and train LoRA on top (`references/training.md`).
4. Several GPUs -> Accelerate with DeepSpeed ZeRO or FSDP (`references/training.md`, skill `deepspeed`).
5. Trained already -> save, reload, hot-swap, combine or merge (`references/adapters-and-merging.md`).
6. Another PEFT method than LoRA -> `references/methods.md`.
7. Error text or "no improvement" -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, training runs and merges write large files and need approval.
- **Pin the version.** PEFT adds a method or config field in most releases; record `peft.__version__` with every adapter. An adapter saved by a newer PEFT can fail to load in an older one (`references/troubleshooting.md`).
- **`get_peft_model` modifies the base model in place.** Reload the base for each independent experiment.
- **Check what is trainable.** Run `model.print_trainable_parameters()` after wrapping; a tiny number means `target_modules` missed (`references/troubleshooting.md`).
- **Reloading to continue training needs `is_trainable=True`.** `PeftModel.from_pretrained` defaults to inference.
- **Never merge into a quantized base unless you checked support.** Not every method or quantization allows merging (`references/adapters-and-merging.md`).
- **Prefer `safetensors`.** Adapters save as `adapter_model.safetensors` by default; load untrusted `.bin` files only if you trust the source.
- **Hold out eval data and compare with the base.** Loss curves are not the eval.
- **Secrets never touch output.** `HF_TOKEN` comes from the environment or a `0600` file.

## Workflows

### 1. Install

- [ ] `uv venv && source .venv/bin/activate && uv pip install peft` (+ `bitsandbytes`, `accelerate`) (`references/install.md`).
- [ ] Verify: `python -c 'import peft; print(peft.__version__)'`.

### 2. Add a LoRA adapter

- [ ] Load the base model, build `LoraConfig(r=..., lora_alpha=..., target_modules=..., task_type="CAUSAL_LM")`, call `get_peft_model` (`references/lora-config.md`).
- [ ] Verify: `print_trainable_parameters()` shows a small, non-zero share.

### 3. Train

- [ ] Use Transformers `Trainer`, TRL's `SFTTrainer(peft_config=...)` or your own loop (`references/training.md`).
- [ ] Verify: after a few optimizer steps the adapter weights changed (`references/troubleshooting.md`, "does not improve").

### 4. Quantized base (QLoRA)

- [ ] `BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4", ...)`, `prepare_model_for_kbit_training`, then LoRA (`references/training.md`).

### 5. Save, reload, merge

- [ ] `model.save_pretrained(dir)` writes `adapter_model.safetensors` and `adapter_config.json` (`references/adapters-and-merging.md`).
- [ ] Reload with `PeftModel.from_pretrained(base, dir)`; merge with `merge_and_unload()` and save the result.
- [ ] Verify: same prompts give matching output from adapter and merged model.

### 6. Update

- [ ] Read release notes, new venv, reload an old adapter as a smoke test (`references/updating.md`).

## Reference index

- `references/install.md`: install, Python and dependency floor, extras, verify.
- `references/lora-config.md`: `LoraConfig` fields, `target_modules`, rank, variants and initializations.
- `references/methods.md`: PEFT method families and what each supports.
- `references/training.md`: Trainer/TRL/loop integration, QLoRA, mixed precision, gradient checkpointing, DeepSpeed and FSDP.
- `references/adapters-and-merging.md`: files, load, multi-adapter, hot-swap, weighted merge, `merge_and_unload`.
- `references/troubleshooting.md`: symptoms and fixes.
- `references/updating.md`: versions, cadence, upgrade routine.
- `templates/accelerate-deepspeed-zero3.yaml`: Accelerate config for ZeRO-3 LoRA training.

## Companion skills

Install with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `fine-tuning-llms`: decide, prepare data, choose method and hardware, evaluate.
- `trl`, `axolotl`, `llama-factory`, `unsloth`: trainers built on PEFT.
- `deepspeed`: ZeRO configs and offload. `vllm`: serve adapters or merged models.
- `llm-evals`: compare the tuned model with the base.
