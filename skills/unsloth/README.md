# Unsloth

An agent skill for [Unsloth](https://github.com/unslothai/unsloth): the fast, low-VRAM fine-tuning and RL library (Unsloth Core), plus Unsloth Studio and Desktop. It covers installing Core, Studio, Docker and the DGX Spark route, writing LoRA, QLoRA and full fine-tuning scripts on top of [TRL](https://github.com/huggingface/trl), RL and preference tuning, multi-GPU launches, and exporting to PEFT adapters, merged 16-bit weights and GGUF for [Ollama](https://github.com/ollama/ollama) and [llama.cpp](https://github.com/ggml-org/llama.cpp).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill unsloth
```

## Rules

- **Ask before changing the system.** Installers, image builds, exposing Studio and long runs need approval.
- **Keep Studio on localhost by default.** Exposed Studio has code-executing tools on by default.
- **Let Unsloth pick `transformers` and `trl`.** Version skew breaks its patches.
- **Import `unsloth` first.**
- **Same chat template and EOS at training and serving.**
- **Merge to 16-bit before re-quantizing.**
- **Secrets never touch output.** Tokens come from the environment or `0600` files.
- **Verify upstream.** Versions change weekly.

## References

- [`references/install.md`](references/install.md): Core, Studio/Desktop, Docker, DGX Spark, Blackwell, AMD/Intel.
- [`references/finetune.md`](references/finetune.md): loader and LoRA parameters, SFT script, RL, multi-GPU.
- [`references/export.md`](references/export.md): adapter, merged, GGUF quant list, manual conversion.
- [`references/studio.md`](references/studio.md): Studio and Desktop, launching, exposure, passwords.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): version channels and upgrades.
- [`references/combos/gguf-ollama.md`](references/combos/gguf-ollama.md): merged GGUF to an Ollama model.

## Companion skills

- `fine-tuning-llms`: decide, prepare data, choose method and hardware (install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`)
- `axolotl`: config-only, multi-GPU alternative (install: `npx skills add ScaleDockHQ/llm-skills --skill axolotl`)
- `trl`: custom trainers and reward functions (install: `npx skills add ScaleDockHQ/llm-skills --skill trl`)
- `ollama`: run the GGUF (install: `npx skills add ScaleDockHQ/llm-skills --skill ollama`)
- `llama-cpp`: convert and serve GGUF (install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`)
- `model-quantization`: quant types and imatrix (install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`)

## License

MIT
