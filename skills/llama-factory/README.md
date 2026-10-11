# LLaMA-Factory

An agent skill for [LLaMA-Factory](https://github.com/hiyouga/LLaMA-Factory), the YAML-driven fine-tuning framework with the `llamafactory-cli` command and the LLaMA Board web UI. It covers installing, registering datasets, LoRA/QLoRA/full SFT, DPO/KTO/reward training, multi-GPU and DeepSpeed ZeRO runs, merging adapters, serving an OpenAI-style API, updating and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill llama-factory
```

## Rules

- **Ask before changing the system.** Installs, training runs and servers need approval.
- **Install from a checkout or Docker image; do not upgrade its pinned libraries.**
- **Register custom datasets in `dataset_info.json`.**
- **Never merge into a quantized model.**
- **LLaMA Board has no login and binds `0.0.0.0` by default; the API needs `API_KEY`.**
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): source and Docker install, pins.
- [`references/config-and-data.md`](references/config-and-data.md): YAML, `dataset_info.json`, data formats.
- [`references/training.md`](references/training.md): stages, QLoRA, DPO/KTO, memory levers.
- [`references/multi-gpu.md`](references/multi-gpu.md): torchrun, multi-node, DeepSpeed, Ray.
- [`references/export-and-serve.md`](references/export-and-serve.md): chat, merge, API, web UI.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): cadence and upgrade routine.
- [`templates/`](templates): `sft-lora.yaml`, `dpo-lora.yaml`, `merge-lora.yaml`, `dataset_info.custom.json`.

## Companion skills

- `fine-tuning-llms`: decide, prepare data, choose method and hardware (install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`)
- `deepspeed` and `peft`: the libraries underneath
- `axolotl`, `unsloth`, `trl`: other training stacks
- `vllm`: serve the merged model (install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`)

## License

MIT
