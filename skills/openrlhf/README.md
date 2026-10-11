# OpenRLHF

An agent skill for running [OpenRLHF](https://github.com/OpenRLHF/OpenRLHF), the Ray + vLLM + DeepSpeed RLHF framework: install it in the NGC container, train SFT, reward models and DPO, run PPO, REINFORCE++, GRPO and RLOO jobs on Ray, write reward and agent functions, tune placement (hybrid engine, async), run on Slurm, merge LoRA, update and troubleshoot.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill openrlhf
```

## Rules

- **Ask before changing the system.** Installs, container runs, Ray clusters and long runs need approval and an undo path.
- **Check flag names with `--help`.** Releases moved flags into dotted groups; some upstream docs still show old forms.
- **Pin the version.** Release tag, container tag, vLLM and DeepSpeed.
- **Smoke-run small first,** and prefer the hybrid engine for stability.
- **Secrets never touch output.** Use `wandb login` or environment variables.
- **Never expose the Ray dashboard publicly.**
- **Verify upstream.** Compare against `examples/scripts/` of your tag.

## References

- [`references/install.md`](references/install.md): container, pip extras, source install.
- [`references/sft-rm-dpo.md`](references/sft-rm-dpo.md): SFT, reward model and DPO.
- [`references/rl-training.md`](references/rl-training.md): `train_ppo_ray` flags, algorithms, checkpoints, LoRA merge.
- [`references/rewards-and-agents.md`](references/rewards-and-agents.md): reward functions, agents, dynamic filtering.
- [`references/scaling.md`](references/scaling.md): placement modes, async, Slurm, tuning.
- [`references/troubleshooting.md`](references/troubleshooting.md): error strings and fixes.
- [`references/updating.md`](references/updating.md): releases and upgrades.
- [`templates/reinforce-baseline-hybrid.sh`](templates/reinforce-baseline-hybrid.sh): 4-GPU hybrid-engine RLVR starter.
