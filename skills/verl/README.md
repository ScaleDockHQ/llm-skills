# verl

An agent skill for running [verl](https://github.com/verl-project/verl), the open-source RL post-training library for LLMs: install it with uv or Docker, run GRPO, PPO and other algorithms with FSDP or Megatron training and vLLM or SGLang rollouts, write reward functions, scale to multi-node Ray, merge checkpoints into Hugging Face models, update and troubleshoot.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill verl
```

## Rules

- **Ask before changing the system.** Installs, image pulls, Ray clusters and long runs need approval and an undo path.
- **Start from the `examples/` script of your tag.** Config keys move between releases.
- **Pin the version.** Git tag, `uv.lock` or image tag.
- **Smoke-run small first,** then scale.
- **Watch the train/rollout mismatch** with `rollout.calculate_log_probs=True`.
- **Secrets never touch output.** Tokens come from the environment or `0600` files.
- **Verify upstream.** Check the config reference for the installed tag.

## References

- [`references/install.md`](references/install.md): uv extras, Docker, pins, NPU/ROCm.
- [`references/training.md`](references/training.md): entrypoints, algorithms, config groups, batch sizes, LoRA, SFT.
- [`references/rewards.md`](references/rewards.md): custom reward function, reward managers, reward models.
- [`references/scaling.md`](references/scaling.md): backends, rollout tuning, Ray multi-node, Slurm, SkyPilot, async trainers.
- [`references/checkpoints.md`](references/checkpoints.md): save contents, resume, model_merger, callbacks.
- [`references/troubleshooting.md`](references/troubleshooting.md): error strings and fixes.
- [`references/updating.md`](references/updating.md): releases and upgrade steps.
- [`templates/grpo-gsm8k-1gpu.sh`](templates/grpo-gsm8k-1gpu.sh): small GRPO launch script.
