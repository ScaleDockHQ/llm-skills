# TRL

An agent skill for [TRL](https://github.com/huggingface/trl), Hugging Face's post-training library: `SFTTrainer`, `DPOTrainer`, `GRPOTrainer`, `RLOOTrainer`, `KTOTrainer`, `RewardTrainer` and the `trl` CLI. It covers installing, LoRA/QLoRA training, custom reward functions, GRPO with vLLM (server or colocate), Accelerate and DeepSpeed scaling, merging adapters, troubleshooting and updating.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill trl
```

## Rules

- **Ask before changing the system.** Installs, vLLM servers and long runs need approval.
- **Pin the TRL version.** Experimental trainers change without notice.
- **Use instruct models or set a chat template.**
- **Keep the vLLM server on a trusted network.** It needs `VLLM_SERVER_DEV_MODE=1`.
- **Hold out eval data and compare with the base.**
- **Secrets never touch output.** Tokens come from the environment or `0600` files.

## References

- [`references/install.md`](references/install.md): install, extras, vLLM range, `trl env`.
- [`references/cli.md`](references/cli.md): `trl` commands, YAML, Accelerate profiles.
- [`references/trainers.md`](references/trainers.md): SFT, DPO, GRPO, reward functions, dataset formats.
- [`references/peft-and-memory.md`](references/peft-and-memory.md): LoRA, QLoRA, packing, memory levers, merging.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): cadence and upgrade routine.
- [`references/combos/grpo-vllm.md`](references/combos/grpo-vllm.md): GRPO with vLLM.
- [`templates/`](templates): `sft-lora.yaml`, `grpo.yaml`.

## Companion skills

- `fine-tuning-llms`: decide, prepare data, choose method and hardware (install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`)
- `axolotl` and `unsloth`: higher-level trainers built on TRL
- `vllm`: serve the model and the GRPO generation server (install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`)
- `llm-evals`: compare against the base model

## License

MIT
