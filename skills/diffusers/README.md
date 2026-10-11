# Diffusers

An agent skill for installing, running and tuning [Hugging Face Diffusers](https://github.com/huggingface/diffusers), the PyTorch library for image, video and audio diffusion pipelines. It helps an agent set up an environment, load pipelines with the right dtype and `device_map`, use `diffusers-cli run`, fit large models into memory (offloading, VAE tiling, quantization, GGUF), speed up inference, stack LoRAs, run the example FastAPI server safely, update, and diagnose common errors.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill diffusers
```

## Rules

- **Ask before installing or downloading weights.**
- **Never pass `trust_remote_code` for unreviewed repos.**
- **The example server has no auth.** Keep it on loopback.
- **Pin model revisions** for repeatable results.
- **Tokens come from the environment or a `0600` file.**

## References

- [`references/install.md`](references/install.md): environment and cache.
- [`references/pipelines-and-cli.md`](references/pipelines-and-cli.md): loading and `diffusers-cli`.
- [`references/memory-and-speed.md`](references/memory-and-speed.md): memory and speed.
- [`references/quantization-and-lora.md`](references/quantization-and-lora.md): quantization, GGUF, LoRA.
- [`references/serving.md`](references/serving.md): HTTP serving.
- [`references/updating.md`](references/updating.md): upgrades.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `self-hosted-genmedia`: choosing a media stack.
- `comfyui`, `stable-diffusion-cpp`: alternative engines.
- `hugging-face`: tokens and cache.

## License

MIT
