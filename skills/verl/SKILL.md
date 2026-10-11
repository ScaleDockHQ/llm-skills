---
name: verl
description: verl (Volcano Engine RL) is an RL post-training library for LLMs with PPO, GRPO, DAPO, RLOO and REINFORCE++ on Ray, FSDP/Megatron training and vLLM/SGLang rollout. Use to install it (uv, Docker), run `python3 -m verl.trainer.main_ppo` or `verl.trainer.sft_trainer`, write reward functions, scale to multi-node Ray, merge checkpoints, or fix OOM, rollout_probs_diff, Ray errors. Not for choosing a method (fine-tuning-llms) or TRL/OpenRLHF (trl, openrlhf).
license: MIT
compatibility: Linux with NVIDIA GPUs (CUDA 12.8+ per docs; uv lock targets CUDA 13.0, Python 3.12), Ascend and ROCm via separate images. Uses uv or Docker, ray, curl and jq. Installs, Docker pulls and long runs need the user's approval; rollout servers may need stopping first.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# verl

Run RL post-training (GRPO, PPO, DAPO, ...) and SFT for LLMs with verl: Hydra-style `key=value` overrides on `verl.trainer.main_ppo`, Ray for placement, FSDP or Megatron for training and vLLM or SGLang for rollouts. Then merge the checkpoint and hand it to a serving engine.

**Scope:** this one product: install, configure, train, scale out, checkpoint/merge, update, troubleshoot. Whether to use RL at all, reward design theory and data prep belong to `fine-tuning-llms`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
python3 --version; command -v uv docker ray
python3 -c 'import verl; print("verl", verl.__version__)' 2>/dev/null
python3 -c 'import torch; print("torch", torch.__version__, "cuda", torch.cuda.is_available())' 2>/dev/null
nvidia-smi --query-gpu=index,name,memory.total,memory.used,compute_cap --format=csv 2>/dev/null
ray status 2>/dev/null | head -20
uname -m; free -h 2>/dev/null | head -2; df -h . ~/.cache/huggingface 2>/dev/null
docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -i verl
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
gh api repos/verl-project/verl/releases/latest --jq '.tag_name,.published_at' 2>/dev/null
```

## Decision flow

1. No GPU box with Python 3.12 and uv, or Ascend/ROCm -> Docker image (`references/install.md`). Otherwise `uv run --frozen --all-packages --extra vllm --extra fsdp` from a repo checkout.
2. Prototype or models up to ~70B -> FSDP/FSDP2 backend. Very large or MoE models -> Megatron backend (`references/scaling.md`).
3. Verifiable reward (math, code) and no critic wanted -> GRPO (`algorithm.adv_estimator=grpo`). Learned value baseline -> PPO (`gae`). Other estimators and variants -> `references/training.md`.
4. SFT first -> `python3 -m verl.trainer.sft_trainer` (`references/training.md`).
5. Rewards: rule-based function via `reward.custom_reward_function`, reward model, or hybrid (`references/rewards.md`).
6. More than one node -> Ray cluster, Slurm or SkyPilot (`references/scaling.md`).
7. Result for vLLM/SGLang -> `python3 -m verl.model_merger merge` (`references/checkpoints.md`).
8. Error text -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, Docker pulls, Ray clusters, long runs and stopping a model server need approval and an undo path.
- **Start from an `examples/` script of the tag you installed.** Config keys move between releases; do not mix a doc page from `main` with an older install.
- **Pin the version.** Record the git tag or `pip show verl`, the image tag and `uv.lock`; keep extras identical across commands of one job.
- **Smoke-run small first.** One node, `trainer.total_epochs=1` or a few steps, confirm reward moves and checkpoints write.
- **Check the train/rollout mismatch.** Set `actor_rollout_ref.rollout.calculate_log_probs=True` and watch `training/rollout_probs_diff_mean`.
- **Secrets never touch output.** `HF_TOKEN`, `WANDB_API_KEY` come from the environment or a `0600` file; never inline them in scripts you commit.
- **Run long jobs under `tmux` or `ray job submit`** so a dropped SSH session does not kill training.
- **Verify upstream.** Check the config reference for the installed tag before editing keys.

## Workflows

### 1. Install

- [ ] Choose uv or Docker and pin the tag (`references/install.md`).
- [ ] `uv run --frozen --all-packages --extra vllm --extra fsdp python3 -c 'import verl'` works, or the container imports verl.
- [ ] Verify: `python3 -c 'import torch; print(torch.cuda.is_available())'` prints `True`.

### 2. Quickstart GRPO

- [ ] Prepare data: `python3 examples/data_preprocess/gsm8k.py --local_save_dir ~/data/gsm8k`.
- [ ] Copy `templates/grpo-gsm8k-1gpu.sh`, set model and paths (`references/training.md`).
- [ ] Run it under `tmux`; log shows `step:` lines and `val/test_score/...` every `trainer.test_freq` steps.
- [ ] Verify: score rises and `checkpoints/<project>/<experiment>/global_step_N/` appears.

### 3. Custom reward

- [ ] Write `compute_score(data_source, solution_str, ground_truth, extra_info)`, pass `reward.custom_reward_function.path=... .name=compute_score` (`references/rewards.md`).
- [ ] Verify: scores in the log are not constant; unit-test the function on 3 known answers first.

### 4. Scale out

- [ ] Start Ray head and workers, submit with `ray job submit` and set `trainer.nnodes` (`references/scaling.md`).
- [ ] Verify: `ray status` lists every node; all GPUs busy in the dashboard.

### 5. Merge and serve

- [ ] `python3 -m verl.model_merger merge --backend fsdp --local_dir <actor dir> --target_dir <out>` (`references/checkpoints.md`).
- [ ] Verify: `<out>` has safetensors, config and tokenizer; `vllm serve <out>` answers.

### 6. Update

- [ ] Read release notes, re-pin, rerun the smoke run (`references/updating.md`).

## Reference index

- `references/install.md`: uv extras, Docker images, version pins, NPU/ROCm.
- `references/training.md`: entrypoints, algorithms, key config groups, batch sizes, LoRA, SFT.
- `references/rewards.md`: custom reward function, reward managers, reward models.
- `references/scaling.md`: FSDP vs Megatron, rollout tuning, Ray multi-node, Slurm, SkyPilot, async trainers.
- `references/checkpoints.md`: save/load contents, resume, model_merger, callbacks.
- `references/troubleshooting.md`: error strings and fixes.
- `references/updating.md`: releases, upgrade steps, breaking changes.
- `templates/grpo-gsm8k-1gpu.sh`: small GRPO launch script.

## Companion skills

Install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `fine-tuning-llms`: decide whether and how to tune, data, evaluation.
- `openrlhf`: Ray + vLLM + DeepSpeed alternative. `trl`: Python-script GRPO/DPO. `axolotl`: YAML SFT/DPO/GRPO.
- `vllm` and `sglang`: serve the merged model. `llm-evals`: compare against the base model.
