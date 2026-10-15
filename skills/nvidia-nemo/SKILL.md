---
name: nvidia-nemo
description: "NVIDIA NeMo Framework is a set of repos: NeMo AutoModel (PyTorch/FSDP2 fine-tuning via the automodel CLI), NeMo Megatron-Bridge (Megatron pretraining, HF conversion) and NeMo RL (GRPO, DPO, SFT on Ray). Use to pick the right NeMo repo, install via uv or NGC containers, run recipes, convert HF<->Megatron, or fix NeMo errors. Not for NeMo Speech/Guardrails/Curator, a method choice (fine-tuning-llms) or Axolotl/TRL/verl."
license: MIT
compatibility: Linux with NVIDIA GPUs (Docker with nvidia runtime for NGC containers, or uv with Python 3.10+; Megatron-Bridge needs Python 3.12; NeMo RL pins Python 3.13). Uses uv, docker, curl and jq via shell. Installs, container runs and long training jobs need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA NeMo (AutoModel, Megatron-Bridge, RL)

Choose and run the right NeMo Framework repo for an LLM/VLM training job: **AutoModel** for YAML-driven fine-tuning and pretraining with PyTorch-native parallelism, **Megatron-Bridge** for Megatron-Core scale and Hugging Face <-> Megatron checkpoint conversion, **NeMo RL** for GRPO/PPO/DPO/SFT/distillation on Ray. Hand the result to a serving engine.

**Scope:** these three training repos and how they fit together. The legacy monolithic NeMo 2.x repo now centres on speech; Curator, Guardrails, Evaluator, Export-Deploy, Gym, Run and others are only pointed at (`references/overview.md`). Whether to tune at all belongs to `fine-tuning-llms`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
command -v uv docker automodel am ray; python3 --version
python3 -c 'import nemo_automodel as n; print("automodel", n.__version__)' 2>/dev/null
python3 -c 'import importlib.metadata as m; print("megatron-bridge", m.version("megatron-bridge"))' 2>/dev/null
nvidia-smi --query-gpu=index,name,memory.total,memory.used,compute_cap --format=csv 2>/dev/null; nvidia-smi | head -4 | tail -1
docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -i 'nemo'
free -h 2>/dev/null | head -2; df -h . ~/.cache/huggingface 2>/dev/null
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
for r in Automodel RL Megatron-Bridge; do gh api repos/NVIDIA-NeMo/$r/releases/latest --jq '"'$r' "+.tag_name+" "+.published_at' 2>/dev/null; done
```

## Decision flow

1. SFT, LoRA or pretraining of an HF model on 1 to ~1000 GPUs -> **AutoModel** (`references/automodel.md`).
2. Largest scale (> ~1000 GPUs), Megatron parallelism (TP/PP/CP/EP), or you need HF <-> Megatron checkpoints -> **Megatron-Bridge** (`references/megatron-bridge.md`).
3. RL (GRPO, PPO, DAPO, GSPO, distillation), DPO, reward model, multi-turn or environment training -> **NeMo RL** (`references/nemo-rl.md`).
4. Multi-node: Slurm via `slurm.sub` (AutoModel) or `ray.sub` (NeMo RL), or Kubernetes (`references/scaling.md`).
5. Need a TRL-style script, Axolotl YAML or a non-NVIDIA stack -> a sibling skill (below).
6. Error text -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, `docker pull`, container runs with `--gpus all`, and long jobs need approval and an undo path.
- **Pin versions.** Record the git tag or PyPI version, the NGC container tag and `uv.lock`; NGC tags like `latest` move.
- **YAML and `_target_` are code.** AutoModel resolves `_target_` and `file.py:symbol` by importing; only run configs from trusted sources.
- **Bind-mount outputs.** Containers run with `--rm`; mount checkpoint and cache directories or the weights vanish.
- **Smoke-run first.** One node, few steps (`references/nemo-rl.md` has a smoke config), then scale.
- **Secrets never touch output.** `HF_TOKEN`, `WANDB_API_KEY`, NGC keys come from the environment or `0600` files; never inline them in YAML.
- **Use `uv run`, not an activated venv, for NeMo RL.** Rebuild with `NRL_FORCE_REBUILD_VENVS=true` after `pyproject.toml` changes.
- **Verify upstream.** The repos move fast; read the release notes and the tag's example configs.

## Workflows

### 1. Fine-tune with AutoModel

- [ ] Install (`uv pip install nemo-automodel` or the NGC container) (`references/automodel.md`).
- [ ] `cp templates/automodel-lora-llama.yaml my.yaml`; set model, dataset, checkpoint dir.
- [ ] `automodel my.yaml --nproc-per-node <N>`.
- [ ] Verify: validation loss logged; `checkpoints/.../model/` exists (consolidated HF weights when `save_consolidated` is `final`/`every`).

### 2. Run RL with NeMo RL

- [ ] Container or `git clone --recursive` + `uv venv` (`references/nemo-rl.md`).
- [ ] `uv run examples/run_grpo.py --config examples/configs/grpo_smoke.yaml`, then your config with overrides.
- [ ] Verify: reward/accuracy metrics logged; DCP checkpoint in `checkpointing.checkpoint_dir`; convert to HF before evaluation.

### 3. Convert HF <-> Megatron

- [ ] Use `AutoBridge` or the example scripts (`references/megatron-bridge.md`).
- [ ] Verify: round-trip script reports matching weights.

### 4. Scale out

- [ ] `references/scaling.md`: Slurm, NeMo-Run, SkyPilot, Kubernetes.

### 5. Update

- [ ] `references/updating.md`: read breaking changes, bump pins, rerun a smoke job.

## Reference index

- `references/overview.md`: repo map, what replaced NeMo 2.x, which repo for which job, release status.
- `references/automodel.md`: install, CLI, YAML structure, PEFT, distributed, checkpoints.
- `references/megatron-bridge.md`: container, AutoBridge conversion, recipes, Megatron-Core pins.
- `references/nemo-rl.md`: install, run scripts, GRPO config, backends, conversion and eval.
- `references/scaling.md`: Slurm, NeMo-Run, SkyPilot, Kubernetes, containers.
- `references/troubleshooting.md`: error strings and fixes.
- `references/updating.md`: versions, breaking changes, upgrade steps.
- `templates/automodel-lora-llama.yaml`, `templates/nemo-rl-grpo-smoke.sh`.

## Companion skills

Install with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `fine-tuning-llms`: decide whether and how to tune, data, evaluation.
- `axolotl`, `trl`, `unsloth`: other fine-tuning stacks. `verl`, `openrlhf`: other Ray RL stacks.
- `vllm`: serve the converted HF checkpoint. `llm-evals`: compare against the base model.
