---
name: llama-factory
description: LLaMA-Factory (llamafactory-cli) is the YAML-driven fine-tuning framework with the LLaMA Board web UI for LoRA, QLoRA, full tuning, SFT, DPO, KTO, reward and pre-training on 100+ LLMs and VLMs. Use to install it, register data in dataset_info.json, write train YAML, go multi-GPU (torchrun, DeepSpeed ZeRO), merge LoRA adapters, or serve an OpenAI-style API, or fix pin conflicts and dataset-not-found errors. Not for Axolotl, Unsloth or TRL scripts (axolotl, unsloth, trl); method choice is fine-tuning-llms.
license: MIT
compatibility: Linux with an NVIDIA GPU (also AMD ROCm and Ascend NPU), Python 3.11+, uv or pip, or the hiyouga/llamafactory Docker image. Uses llamafactory-cli, curl and jq via shell. Installs, training runs, merges, web UI and API servers need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LLaMA-Factory

Fine-tune open models from one YAML file and the `llamafactory-cli` command, or from the LLaMA Board web UI: train, chat-test, merge the LoRA adapter and optionally serve it.

**Scope:** this one product: install, data registration, train, scale out, merge/export, serve, update, troubleshoot. Whether to fine-tune, data prep and method choice belong to `fine-tuning-llms`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
command -v llamafactory-cli lmf && llamafactory-cli version 2>/dev/null
llamafactory-cli env 2>/dev/null | head -30
python3 --version; command -v uv docker
python3 -c 'import torch; print("torch", torch.__version__, "cuda", torch.cuda.is_available())' 2>/dev/null
pip list 2>/dev/null | grep -iE '^(peft|trl|transformers|accelerate|deepspeed|bitsandbytes|vllm) '
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>/dev/null
uname -m; free -h 2>/dev/null | head -2; df -h . ~/.cache/huggingface 2>/dev/null
ls data/dataset_info.json examples/train_lora 2>/dev/null | head
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
```

## Decision flow

1. No install yet -> `references/install.md` (source clone with `uv`, or Docker).
2. Own data -> register it in `dataset_info.json` first (`references/config-and-data.md`).
3. One GPU, standard SFT/DPO/KTO -> YAML + `llamafactory-cli train` (`references/training.md`, `templates/`).
4. Not enough VRAM -> QLoRA (`quantization_bit`), shorter `cutoff_len`, DeepSpeed offload (`references/training.md`).
5. 2+ GPUs or nodes -> `FORCE_TORCHRUN`, `NNODES`, ZeRO config (`references/multi-gpu.md`).
6. Done training -> merge and serve (`references/export-and-serve.md`).
7. Error text or pip conflict -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, training runs, web UI, API servers and long jobs need approval and an undo path.
- **Install from a checkout or the Docker image, in a fresh environment.** Upstream marks installation as mandatory; the project pins `peft`, `trl`, `accelerate`, `transformers` and `deepspeed` to ranges, so never `pip install -U` them over it (`references/install.md`).
- **Run from the repo root.** Relative paths such as `data/` and `examples/deepspeed/...` assume it.
- **Register every custom dataset** in `dataset_info.json` under `dataset_dir`; the YAML only names it.
- **Match `template` to the model family**, and the same `template` at train, chat and export time.
- **Never merge into a quantized model.** Merge the adapter into the unquantized base (`references/export-and-serve.md`).
- **LLaMA Board and the API bind `0.0.0.0` by default and the web UI has no login.** Bind to localhost or a private interface, and set `API_KEY` for the API (`references/export-and-serve.md`).
- **Hold out eval data and compare with the base.** Loss curves are not the eval.
- **Secrets never touch output.** `HF_TOKEN`, `WANDB_API_KEY` and `API_KEY` come from the environment or `0600` files.

## Workflows

### 1. Install

- [ ] Clone, create a `uv` environment, `pip install -e .`, add `deepspeed` or metrics extras if needed (`references/install.md`).
- [ ] Verify: `llamafactory-cli version` and `llamafactory-cli env` print versions; `torch.cuda.is_available()` is `True`.

### 2. Smoke run with the bundled example

- [ ] `llamafactory-cli train examples/train_lora/qwen3_lora_sft.yaml` (small model, `max_samples: 1000`) (`references/training.md`).
- [ ] Verify: `output_dir` has adapter files and, with `plot_loss: true`, a loss plot.

### 3. Train on your data

- [ ] Put JSON/JSONL in `data/`, add its entry to `data/dataset_info.json` (`references/config-and-data.md`).
- [ ] `cp templates/sft-lora.yaml mytrain.yaml`, set `model_name_or_path`, `dataset`, `template`, `output_dir`; hold out `val_size`.
- [ ] `llamafactory-cli train mytrain.yaml`; override single keys on the command line (`learning_rate=1e-5`).
- [ ] Verify: eval loss falls; chat-test the adapter before merging.

### 4. Preference tuning

- [ ] A `ranking: true` dataset with `chosen`/`rejected`; `stage: dpo` with `pref_loss` (`templates/dpo-lora.yaml`, `references/training.md`).
- [ ] Verify: reward/margin logs and outputs on held-out prompts.

### 5. Scale out

- [ ] Several GPUs launch `torchrun` automatically; multi-node and ZeRO via env vars and a `deepspeed:` key (`references/multi-gpu.md`).
- [ ] Verify: every rank progresses; effective batch = `per_device_train_batch_size` x `gradient_accumulation_steps` x GPUs.

### 6. Chat-test, merge and serve

- [ ] `llamafactory-cli chat <infer.yaml>`; then `llamafactory-cli export <merge.yaml>` (`templates/merge-lora.yaml`).
- [ ] Serve with `llamafactory-cli api` or hand the merged folder to `vllm` (`references/export-and-serve.md`).

### 7. Update

- [ ] Read release notes and the `pyproject.toml` pins, new environment, re-run the smoke run (`references/updating.md`).

## Reference index

- `references/install.md`: source and Docker install, version pins, Windows/NPU notes, `llamafactory-cli env`.
- `references/config-and-data.md`: YAML anatomy, `dataset_info.json`, alpaca/sharegpt/preference formats, CLI overrides.
- `references/training.md`: stages, finetuning types, QLoRA, DPO/KTO/reward, memory levers, W&B.
- `references/multi-gpu.md`: automatic torchrun, `FORCE_TORCHRUN`, multi-node, DeepSpeed ZeRO config, Ray.
- `references/export-and-serve.md`: chat, merge, quantized export, OpenAI-style API, LLaMA Board exposure.
- `references/troubleshooting.md`: symptoms and fixes.
- `references/updating.md`: release cadence, pin ranges, upgrade routine.
- `templates/sft-lora.yaml`, `templates/dpo-lora.yaml`, `templates/merge-lora.yaml`, `templates/dataset_info.custom.json`: starters.

## Companion skills

Install with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `fine-tuning-llms`: decide, prepare data, choose method and hardware, evaluate.
- `deepspeed`: ZeRO stages, offload and config details. `peft`: adapter types and merging internals.
- `axolotl`, `unsloth`, `trl`: other training stacks.
- `vllm`: serve the merged model. `llm-evals`: compare with the base.
