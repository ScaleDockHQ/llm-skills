# Axolotl

An agent skill for running [Axolotl](https://github.com/axolotl-ai-cloud/axolotl), the YAML-driven LLM fine-tuning framework: install it with uv or Docker, write and debug configs, train LoRA, QLoRA and full fine-tunes with SFT, DPO, KTO and GRPO, scale to several GPUs with FSDP2 or DeepSpeed, merge adapters, export to GGUF, update and troubleshoot. It builds on [TRL](https://github.com/huggingface/trl), [PEFT](https://github.com/huggingface/peft) and optionally [vLLM](https://github.com/vllm-project/vllm).

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill axolotl
```

## Rules

- **Ask before changing the system.** Installs, image pulls, long runs and stopping servers need approval and an undo path.
- **Inspect masks before a long run.** `axolotl preprocess --debug` shows which tokens are trained.
- **Hold out eval data.** `test_datasets` or `val_set_size`, never both.
- **Pin the version.** Release tags and Docker tags, not `main-latest`.
- **Keep llama.cpp requirements out of the Axolotl venv.**
- **Secrets never touch output.** Tokens come from the environment or `0600` files.
- **Verify upstream.** Config keys change between releases.

## References

- [`references/install.md`](references/install.md): uv, Docker images and tags, Blackwell and arm64 notes.
- [`references/config.md`](references/config.md): CLI commands, config keys, dataset types, mask checks.
- [`references/rl-and-grpo.md`](references/rl-and-grpo.md): DPO, KTO, GRPO, vLLM server and colocate modes.
- [`references/multi-gpu.md`](references/multi-gpu.md): FSDP2, DeepSpeed, context parallelism, cloud launchers.
- [`references/export-merge.md`](references/export-merge.md): merge-lora, `--dequant`, GGUF export.
- [`references/troubleshooting.md`](references/troubleshooting.md): error strings and fixes.
- [`references/updating.md`](references/updating.md): upgrading and breaking changes.
- [`references/combos/merge-llm-compressor-fp8-vllm.md`](references/combos/merge-llm-compressor-fp8-vllm.md): merged adapter to FP8 to vLLM.
- [`templates/lora-sft.yaml`](templates/lora-sft.yaml): commented LoRA SFT config. [`templates/grpo-colocate.yaml`](templates/grpo-colocate.yaml): single-GPU GRPO starter.

## Companion skills

- `fine-tuning-llms`: decide, prepare data, choose method and hardware (install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`)
- `unsloth`: memory-tight single-GPU alternative (install: `npx skills add ScaleDockHQ/llms-skills --skill unsloth`)
- `trl`: custom Python trainers and rewards (install: `npx skills add ScaleDockHQ/llms-skills --skill trl`)
- `llm-compressor`: quantize merged models (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-compressor`)
- `vllm`: serve merged models or adapters (install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`)
- `llm-evals`: compare the fine-tune with the base model (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`)

## License

MIT
