---
name: openrlhf
description: OpenRLHF is a Ray + vLLM + DeepSpeed RLHF framework for SFT, reward models, DPO and PPO, REINFORCE++, GRPO and RLOO on Hugging Face models. Use to install it (pip, NGC Docker), run `deepspeed --module openrlhf.cli.train_*` or `python3 -m openrlhf.cli.train_ppo_ray`, write reward_func or agent_func files, run hybrid-engine, async or Slurm jobs, merge LoRA, or fix OOM and Ray GPU errors. Not for choosing a method (fine-tuning-llms) or verl/TRL (verl, trl).
license: MIT
compatibility: Linux with NVIDIA GPUs, Python 3.10+, Docker (NGC PyTorch image) recommended. Uses ray, deepspeed, vLLM, curl and jq via shell. Installs, Docker runs and long training jobs need the user's approval; model servers may need stopping first.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# OpenRLHF

Train with OpenRLHF: supervised fine-tuning, reward models and DPO through `deepspeed --module openrlhf.cli.train_*`, and RL (PPO, REINFORCE++, REINFORCE++-baseline, GRPO, RLOO, Dr. GRPO) through Ray jobs running `openrlhf.cli.train_ppo_ray` with vLLM for generation and DeepSpeed ZeRO for training.

**Scope:** this one product: install, train, scale out, merge, update, troubleshoot. Whether RLHF is the right method, data curation and reward design theory belong to `fine-tuning-llms`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
python3 --version; command -v docker ray deepspeed
python3 -c 'import openrlhf, importlib.metadata as m; print("openrlhf", m.version("openrlhf"))' 2>/dev/null
pip list 2>/dev/null | grep -Ei '^(openrlhf|vllm|deepspeed|ray|torch|transformers|flash.attn) '
nvidia-smi --query-gpu=index,name,memory.total,memory.used,compute_cap --format=csv 2>/dev/null
ray status 2>/dev/null | head -20
free -h 2>/dev/null | head -2; df -h . ~/.cache/huggingface 2>/dev/null
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
curl -s https://pypi.org/pypi/openrlhf/json | jq -r '.info.version,.info.requires_python'
```

## Decision flow

1. Install: NGC PyTorch container then `pip install openrlhf[vllm]` (`references/install.md`).
2. SFT, reward model or DPO -> `deepspeed --module openrlhf.cli.train_sft|train_rm|train_dpo` (`references/sft-rm-dpo.md`).
3. RL with a verifiable reward and no critic -> `--algo.advantage.estimator reinforce_baseline` (recommended upstream for RLVR) or `group_norm` (GRPO); learned critic -> default PPO (`references/rl-training.md`).
4. Reward source: reward model (`--reward.model_name_or_path`), Python file (`--reward.remote_url x.py`), HTTP service, or agent file (`--train.agent_func_path`) (`references/rewards-and-agents.md`).
5. GPU layout: few GPUs -> hybrid engine (`--train.colocate_all`); throughput over stability -> async (`references/scaling.md`).
6. More than one node -> Ray cluster or Slurm (`references/scaling.md`).
7. LoRA result -> `python -m openrlhf.cli.lora_combiner` (`references/rl-training.md`); then serve with vLLM.
8. Error text -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, pip uninstalls inside containers, Docker runs, Ray clusters and long runs need approval and an undo path.
- **Flag names change between releases.** 0.11 uses dotted groups (`--actor.*`, `--model.*`, `--ds.*`, `--vllm.*`, `--rollout.*`, `--train.*`, `--ckpt.*`, `--algo.*`). Check `python3 -m openrlhf.cli.<entry> --help` for the installed version; the upstream README still shows some old forms.
- **Pin the version.** `pip show openrlhf`, the container tag, vLLM and DeepSpeed versions; `openrlhf[vllm]` pins an exact vLLM.
- **Smoke-run small first.** Few steps, small `--data.max_samples`, then scale.
- **Prefer hybrid engine for stability.** Async and partial rollout are off-policy; validate convergence before using them.
- **Secrets never touch output.** Pass wandb via `wandb login` or an environment variable; avoid `--logger.wandb.key <literal>` on shared shells and in committed scripts.
- **Never expose the Ray dashboard publicly.** Port 8265 has no authentication by default; bind to localhost or tunnel.
- **Verify upstream.** Compare against `examples/scripts/` of your tag.

## Workflows

### 1. Install

- [ ] Start the NGC container, remove conflicting packages, `pip install openrlhf[vllm]` (`references/install.md`).
- [ ] Verify: `python3 -c 'import openrlhf, vllm, deepspeed, ray'` succeeds and `torch.cuda.is_available()` is `True`.

### 2. SFT / reward model / DPO

- [ ] Copy the matching `examples/scripts/train_*.sh`, set model, dataset and keys (`references/sft-rm-dpo.md`).
- [ ] Run under `tmux`; `--ckpt.save_steps` writes checkpoints.
- [ ] Verify: loss falls; `--ckpt.output_dir` has a loadable HF model.

### 3. RL with Ray and vLLM

- [ ] `ray start --head ...`; submit with `ray job submit` (`references/rl-training.md`, `templates/reinforce-baseline-hybrid.sh`).
- [ ] Verify: reward and `timing/*` metrics logged; vLLM engines up; checkpoint written.

### 4. Custom reward or agent

- [ ] Write `reward_func(queries, prompts, labels, **kwargs)` returning `rewards`, `scores`, `extra_logs` (`references/rewards-and-agents.md`).
- [ ] Verify: unit-test the function; rewards in the log are not constant.

### 5. Scale out

- [ ] Choose colocate flags, add nodes, or use the Slurm example (`references/scaling.md`).
- [ ] Verify: `ray status` lists all GPUs; no OOM at the first step.

### 6. Merge LoRA and update

- [ ] `python -m openrlhf.cli.lora_combiner --model_path ... --lora_path ... --output_path ...`.
- [ ] Updating: `references/updating.md`.

## Reference index

- `references/install.md`: container, pip extras, source install, version pins.
- `references/sft-rm-dpo.md`: SFT, reward model and DPO commands and data keys.
- `references/rl-training.md`: train_ppo_ray flags, algorithms, checkpoints, LoRA merge.
- `references/rewards-and-agents.md`: reward_func, agent_func, dynamic filtering, OpenAI-server agents.
- `references/scaling.md`: Ray, colocation, async, Slurm, memory and speed tuning.
- `references/troubleshooting.md`: error strings and fixes.
- `references/updating.md`: releases and upgrade steps.
- `templates/reinforce-baseline-hybrid.sh`: 4-GPU hybrid-engine RLVR starter.

## Companion skills

Install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `fine-tuning-llms`: decide whether and how to tune, data, evaluation.
- `verl`: Ray + FSDP/Megatron RL alternative. `trl`: Python-script trainers. `axolotl`: YAML SFT/DPO/GRPO.
- `vllm`: serve the result. `llm-evals`: compare with the base model.
