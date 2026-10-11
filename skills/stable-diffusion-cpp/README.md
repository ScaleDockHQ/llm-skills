# stable-diffusion.cpp

An agent skill for installing, serving and tuning [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp), the ggml C/C++ engine for image and video diffusion models (SD, SDXL, FLUX, Qwen-Image, Z-Image, Wan and more). It helps an agent pick a release zip, container image or CMake backend, assemble the right weight files, quantize to GGUF, run `sd-cli`, start a loopback-only `sd-server`, call its OpenAI, WebUI and native async APIs, fit memory, update safely, and put it behind llama-swap and LiteLLM.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill stable-diffusion-cpp
```

## Rules

- **Loopback only.** `sd-server` has no authentication.
- **Ask before installing, building or downloading weights.**
- **No LoRA prompt tags on the server.** Use the structured `lora` field.
- **Match component files to the model architecture.**
- **Pin tags.** `master-*` images and releases move.

## References

- [`references/install.md`](references/install.md): zips, images, CMake backends.
- [`references/models-and-weights.md`](references/models-and-weights.md): model files, GGUF, LoRA, first commands.
- [`references/serve-and-api.md`](references/serve-and-api.md): server flags and the three APIs.
- [`references/performance-memory.md`](references/performance-memory.md): memory and speed knobs.
- [`references/updating.md`](references/updating.md): updating and regression checks.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/llama-swap-litellm.md`](references/combos/llama-swap-litellm.md): llama-swap and LiteLLM.

## Companion skills

- `self-hosted-genmedia`: choosing a media stack.
- `comfyui`: node-graph alternative.
- `llama-swap`, `litellm`: swapping and gateway.

## License

MIT
