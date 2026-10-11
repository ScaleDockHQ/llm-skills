---
name: unsloth
description: Unsloth is a fast, low-VRAM fine-tuning and RL library (FastLanguageModel, unsloth CLI) with Unsloth Studio and Desktop apps for LoRA, QLoRA, full fine-tuning, SFT, DPO and GRPO, plus one-call export to merged 16-bit, GGUF and Ollama. Use to install it (pip/uv, curl installer, unsloth/unsloth Docker, DGX Spark, Blackwell), write training scripts, run unsloth studio, save_pretrained_merged, save_pretrained_gguf, or fix version-skew, OOM and "poor results after export" problems. Not for Axolotl YAML or plain TRL scripts (axolotl, trl); method choice is fine-tuning-llms.
license: MIT
compatibility: Linux, WSL, macOS or Windows; NVIDIA, AMD or Intel GPU (CPU for GGUF-only Studio), Python 3.9-3.14 for the library, uv or Docker. Installs, Studio exposure beyond localhost, training and GGUF builds need the user's approval; curl and jq via shell.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Unsloth

Fine-tune and run open-weight models with Unsloth's patched loaders and kernels (faster, less VRAM), then export the result as a PEFT adapter, merged 16-bit weights or GGUF.

**Scope:** this one product: install, train, export, Studio, update, troubleshoot. Whether to fine-tune, data prep and method choice belong to `fine-tuning-llms`.

Unsloth ships three things: **Unsloth Core** (the Python library, versioned by date such as `2026.10.3`), **Unsloth Studio** (web UI, `unsloth studio`) and **Unsloth Desktop** (native app). The GitHub "latest release" (`v0.1.x-beta`) is Studio/Desktop, not the library; check PyPI for Core.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
command -v unsloth && unsloth --help 2>&1 | head -15
pip show unsloth 2>/dev/null | head -3; pip show trl transformers 2>/dev/null | grep -E '^(Name|Version)'
python3 --version; command -v uv docker
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>/dev/null
uname -sm; free -h 2>/dev/null | head -2; df -h . ~/.cache/huggingface 2>/dev/null
docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -i unsloth
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
```

## Decision flow

1. Wants a GUI, dataset building from PDFs/CSVs, or to run models -> Studio or Desktop (`references/studio.md`).
2. Wants scripts or notebooks -> Core in its own uv venv (`references/install.md`). Do not upgrade TRL or transformers separately; Unsloth pins a TRL range.
3. DGX Spark -> the Spark Dockerfile route; Blackwell RTX 50, AMD, Intel -> their guides (`references/install.md`).
4. One GPU, memory tight -> QLoRA (`load_in_4bit=True`); enough VRAM -> LoRA 16-bit; full fine-tuning only after LoRA proves the data (`references/finetune.md`).
5. Several GPUs -> `accelerate launch` / `torchrun` with DDP, or `device_map="balanced"` to split one big model (`references/finetune.md`).
6. Result for Ollama, llama.cpp, LM Studio -> GGUF; for vLLM -> merged 16-bit or the adapter (`references/export.md`).
7. Bad output after export, OOM, import errors -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, `curl | sh` installers, image builds, exposing Studio beyond localhost and long runs need approval and an undo path.
- **Keep Studio local by default.** `unsloth studio` with `-H 127.0.0.1`; `--secure`, `--cloudflare` or `-H 0.0.0.0` publish a server whose tools (code execution) are on by default. Set a strong password, or add `--disable-tools`.
- **Let the Unsloth install choose `transformers` and `trl`.** Version skew breaks the patches.
- **Import `unsloth` before `transformers` and `trl`.**
- **Train and serve with the same chat template and EOS.** The usual cause of gibberish after export.
- **Merge into 16-bit before re-quantizing.** `merged_4bit` is lossy.
- **Secrets never touch output.** Tokens come from the environment or `0600` files.
- **Verify upstream.** Versions and flags change weekly here; read the docs for the installed version.

## Workflows

### 1. Install

- [ ] Pick Core, Studio/Desktop, or Docker (`references/install.md`); use a fresh uv venv for Core.
- [ ] Verify: `python -c 'import unsloth'` succeeds (Core) or `unsloth studio` serves on the chosen port.

### 2. Train with a script

- [ ] Load with `FastLanguageModel.from_pretrained`, add LoRA, train with TRL's `SFTTrainer` (`references/finetune.md`).
- [ ] Start from the model's notebook for the exact chat-template helper and trainer args.
- [ ] Run in `tmux`, memory-capped on shared machines.
- [ ] Verify: loss falls, adapter files saved, a sample generation matches the task.

### 3. Reinforcement learning or preference tuning

- [ ] Use the GRPO/DPO notebooks as the base (`references/finetune.md`); trainer configs are TRL's (`trl` skill).
- [ ] Verify: reward trend and sample completions, not only loss.

### 4. Export

- [ ] Adapter: `model.save_pretrained(dir)`. Merged: `save_pretrained_merged(..., save_method="merged_16bit")`. GGUF: `save_pretrained_gguf(...)` (`references/export.md`).
- [ ] Verify: reload in the target engine and compare outputs with the in-Unsloth model on the same prompts.
- [ ] GGUF into Ollama: `references/combos/gguf-ollama.md`.

### 5. Update

- [ ] Check PyPI, read the notes, upgrade in a new venv (`references/updating.md`).
- [ ] Verify: a 10-step smoke run, then a save.

## Reference index

- `references/install.md`: Core, Studio/Desktop, Docker, DGX Spark, Blackwell, AMD/Intel pointers.
- `references/finetune.md`: loader and LoRA parameters, SFT script, RL and preference tuning, multi-GPU.
- `references/export.md`: adapter, merged 16-bit, GGUF quant list, manual conversion, Studio export.
- `references/studio.md`: Unsloth Studio and Desktop, launching, exposure, passwords, API.
- `references/troubleshooting.md`: symptoms and fixes.
- `references/updating.md`: versions, release channels, upgrade steps.
- `references/combos/gguf-ollama.md`: merged GGUF to an Ollama model.

## Companion skills

Install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `fine-tuning-llms`: decide, prepare data, choose method and hardware, evaluate.
- `axolotl`: config-only, multi-GPU alternative. `trl`: custom trainers and reward functions.
- `ollama`, `llama-cpp`: run the GGUF. `vllm`: serve merged weights or adapters.
- `model-quantization`: GGUF types, imatrix and other formats. `llm-evals`: compare with the base model.
