---
name: trl
description: TRL (Hugging Face Transformer Reinforcement Learning) is the post-training library with SFTTrainer, DPOTrainer, GRPOTrainer, RLOOTrainer, KTOTrainer, RewardTrainer and the trl CLI (trl sft, trl dpo, trl grpo). Use to install TRL, train with PEFT/LoRA/QLoRA, write custom reward functions, run GRPO with vLLM (server or colocate), scale with Accelerate or DeepSpeed, or fix errors such as chat-template, assistant_only_loss, vllm version, trl.experimental import failures. Not for Axolotl YAML or Unsloth loaders (axolotl, unsloth); method choice is fine-tuning-llms.
license: MIT
compatibility: Linux with an NVIDIA GPU (CUDA PyTorch wheel needed, arm64 incl. DGX Spark possible), Python 3.11+, uv or pip. Uses trl, accelerate, curl and jq via shell. Installs, training runs and vLLM servers need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# TRL

Post-train language models with Hugging Face's reference trainers, from the `trl` CLI for standard runs to Python scripts for custom rewards and collators.

**Scope:** this one product: install, train, scale out, export, update, troubleshoot. Whether to fine-tune, data prep and method choice belong to `fine-tuning-llms`.

Axolotl and Unsloth both build on TRL. Choose TRL directly for custom Python (reward functions, losses, collators), the newest method, or a small script.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
command -v trl && trl env 2>/dev/null | head -30
python3 --version; command -v uv accelerate
python3 -c 'import trl, transformers, peft, torch; print(trl.__version__, transformers.__version__, peft.__version__, torch.__version__, torch.cuda.is_available())' 2>/dev/null
pip show vllm 2>/dev/null | grep -E '^(Name|Version)'
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>/dev/null
uname -m; free -h 2>/dev/null | head -2; df -h . ~/.cache/huggingface 2>/dev/null
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
```

## Decision flow

1. Standard SFT/DPO/KTO/reward/RLOO/GRPO with built-in rewards -> `trl <method> --config file.yaml` (`references/cli.md`, `templates/`).
2. Custom reward function, collator, callback or loss -> a Python script with the trainer class (`references/trainers.md`).
3. Not enough VRAM -> PEFT LoRA, `--load_in_4bit`, packing, activation offloading (`references/peft-and-memory.md`).
4. Online RL (GRPO, RLOO) -> vLLM server or colocate mode (`references/combos/grpo-vllm.md`).
5. 2+ GPUs -> Accelerate via `--num_processes`, or DeepSpeed ZeRO (`references/cli.md`).
6. Method sits under `trl.experimental` -> expect API churn; pin the TRL version (`references/trainers.md`).
7. Error text -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, vLLM servers, long runs and anything that stops other services need approval and an undo path.
- **Pin the version.** TRL moves trainers between stable and `trl.experimental`; tutorials rot. Record `trl env` output with every run.
- **Check the docs for your installed version.** Field names change between releases.
- **Use instruct models or set a chat template.** Base models may lack one; conversational datasets then fail or render wrongly.
- **Keep the vLLM server on a trusted network.** TRL's server mode needs `VLLM_SERVER_DEV_MODE=1`, which exposes development endpoints.
- **Trainer and vLLM server on separate GPUs** in server mode.
- **Hold out eval data and compare with the base.** Loss curves are not the eval.
- **Secrets never touch output.** `HF_TOKEN` and `WANDB_API_KEY` come from the environment or `0600` files.

## Workflows

### 1. Install

- [ ] `uv venv && source .venv/bin/activate && uv pip install trl` (+ `peft`, `bitsandbytes`, `vllm` extras as needed) (`references/install.md`).
- [ ] Verify: `trl env` prints versions and `torch.cuda.is_available()` is `True`.

### 2. Supervised fine-tuning with LoRA

- [ ] Prepare `messages` JSONL with a held-out split (`fine-tuning-llms` for data prep).
- [ ] `cp templates/sft-lora.yaml sft.yaml`; set model, dataset, output dir; run `trl sft --config sft.yaml` (`references/cli.md`).
- [ ] Or a Python script with `SFTTrainer` and `peft_config` (`references/trainers.md`).
- [ ] Verify: eval loss falls; `output_dir` has adapter files; generate on held-out prompts.

### 3. Preference tuning

- [ ] Preference rows `prompt`/`chosen`/`rejected`; start from the SFT model; `trl dpo` or `DPOTrainer` (`references/trainers.md`).
- [ ] With PEFT, no separate `ref_model` is needed (frozen base is used).
- [ ] Verify: rewards/margins logged; outputs on held-out prompts.

### 4. GRPO with a reward function

- [ ] Write the reward function (`references/trainers.md`), test it on literals, then train (`references/combos/grpo-vllm.md`).
- [ ] Verify: reward trend and sample completions, not only loss.

### 5. Scale out

- [ ] CLI: add `--num_processes N`; scripts: `accelerate launch train.py` (`references/cli.md`).
- [ ] Verify: all processes progress; GRPO batch sizing consistent with `num_generations` (`references/combos/grpo-vllm.md`).

### 6. Merge and export

- [ ] Adapter: `trainer.save_model(dir)`. Merge: PEFT `merge_and_unload()` (`references/peft-and-memory.md`).
- [ ] GGUF and serving belong to `llama-cpp`, `vllm` and `fine-tuning-llms`.

### 7. Update

- [ ] Read release notes, new venv, re-run a smoke run (`references/updating.md`).

## Reference index

- `references/install.md`: install, extras, `trl env`, arm64/DGX Spark notes, version constraints.
- `references/cli.md`: `trl` commands, YAML configs, Accelerate scaling, `templates/`.
- `references/trainers.md`: SFT, DPO, KTO, RLOO, Reward, GRPO, experimental trainers, dataset formats, reward functions.
- `references/peft-and-memory.md`: LoRA flags, QLoRA, packing, padding-free, offloading, saving and merging adapters.
- `references/troubleshooting.md`: symptoms and fixes.
- `references/updating.md`: versions, breaking changes, experimental churn.
- `references/combos/grpo-vllm.md`: GRPO with a vLLM server or colocated engine.
- `templates/sft-lora.yaml`, `templates/grpo.yaml`: CLI config starters.

## Companion skills

Install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `fine-tuning-llms`: decide, prepare data, choose method and hardware, evaluate.
- `axolotl`: config-only, multi-GPU runs. `unsloth`: memory-tight single-GPU runs.
- `vllm`: serve the model, adapters, and the GRPO generation server.
- `llm-evals`: compare the tuned model with the base. `llama-cpp`: GGUF conversion.
