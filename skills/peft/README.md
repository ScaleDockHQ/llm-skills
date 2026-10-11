# PEFT

An agent skill for [PEFT](https://github.com/huggingface/peft), Hugging Face's parameter-efficient fine-tuning library: `LoraConfig`, `get_peft_model`, `PeftModel`, `merge_and_unload` and the other adapter methods. It covers installing, choosing `target_modules` and rank, training with Trainer, TRL or a custom loop, QLoRA, DeepSpeed and FSDP, saving, loading, hot-swapping and merging adapters, updating and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill peft
```

## Rules

- **Ask before changing the system.** Installs, training runs and merges need approval.
- **Pin the PEFT version and record it with each adapter.**
- **Check `print_trainable_parameters()`.** A tiny count means `target_modules` missed.
- **Reload with `is_trainable=True` to keep training.**
- **Check merge support before merging into a quantized base.**
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): install and version floor.
- [`references/lora-config.md`](references/lora-config.md): `LoraConfig`, targets, rank, initializations.
- [`references/methods.md`](references/methods.md): method families and capabilities.
- [`references/training.md`](references/training.md): Trainer, TRL, QLoRA, DeepSpeed, FSDP.
- [`references/adapters-and-merging.md`](references/adapters-and-merging.md): save, load, hot-swap, merge.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): cadence and upgrade routine.
- [`templates/`](templates): `accelerate-deepspeed-zero3.yaml`.

## Companion skills

- `fine-tuning-llms`: decide, prepare data, choose method and hardware (install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`)
- `trl`, `axolotl`, `llama-factory`, `unsloth`: trainers built on PEFT
- `deepspeed`: ZeRO configs and offload
- `vllm`: serve adapters or merged models (install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`)

## License

MIT
