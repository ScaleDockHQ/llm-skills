# nvidia-nemo

An agent skill for NVIDIA NeMo Framework as it is now organised under [github.com/NVIDIA-NeMo](https://github.com/NVIDIA-NeMo): pick between AutoModel, Megatron-Bridge and NeMo RL, install them with uv or NGC containers, run fine-tuning, pretraining and RL jobs, scale on Slurm, convert Hugging Face and Megatron checkpoints, troubleshoot and update.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill nvidia-nemo
```

## Rules

- **Pick the repo first.** AutoModel for YAML fine-tuning, Megatron-Bridge for Megatron scale and conversion, NeMo RL for RL and preference training.
- **Ask before changing the system.** Installs, container pulls, `--gpus all` runs and Slurm submissions need approval.
- **Pin versions** per repo (tag, PyPI version or NGC tag). They release independently.
- **Config is code.** Automodel `_target_` entries import and execute code, so run only trusted YAML.
- **Smoke-run small first,** then scale.
- **Secrets never touch output.** `HF_TOKEN` and `WANDB_API_KEY` come from the environment.

## References

- [`references/overview.md`](references/overview.md): repo map and choosing.
- [`references/automodel.md`](references/automodel.md): install, CLI, YAML, checkpoints.
- [`references/megatron-bridge.md`](references/megatron-bridge.md): AutoBridge conversion, recipes, launching.
- [`references/nemo-rl.md`](references/nemo-rl.md): install, entry points, config keys, converters.
- [`references/scaling.md`](references/scaling.md): Slurm, `ray.sub`, parallelism.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): releases, upgrades, NeMo 2.x migration.
- [`templates/automodel-lora-llama.yaml`](templates/automodel-lora-llama.yaml): LoRA recipe.
- [`templates/nemo-rl-grpo-smoke.sh`](templates/nemo-rl-grpo-smoke.sh): GRPO smoke run.
