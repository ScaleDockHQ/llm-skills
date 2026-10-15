# ComfyUI

An agent skill for installing, running headless and operating ComfyUI, the node-graph engine for image, video and audio diffusion models. It helps an agent pick an install path (desktop, portable, comfy-cli, manual), start a loopback-only server, drive it over HTTP with API-format workflow JSON, manage model folders and `extra_model_paths.yaml`, handle custom nodes and ComfyUI-Manager security, tune VRAM and RAM flags, update safely, and put ComfyUI behind llama-swap and LiteLLM. Built on [ComfyUI](https://github.com/Comfy-Org/ComfyUI), [comfy-cli](https://github.com/Comfy-Org/comfy-cli) and [ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill comfyui
```

## Rules

- **Loopback only.** ComfyUI core has no authentication; a bare `--listen` binds every interface.
- **Custom nodes are arbitrary Python.** Start with `--disable-all-custom-nodes` and whitelist what a workflow needs.
- **Use API-format workflows.** `POST /prompt` rejects the UI save format.
- **Verify upstream.** Flags and routes change every release; check `python main.py --help` on the installed checkout.
- **Secrets stay out of output.** Tokens come from environment variables or `0600` files.

## References

- [`references/install.md`](references/install.md): install paths per OS and GPU, comfy-cli, Python and torch requirements, containers.
- [`references/serve-configuration.md`](references/serve-configuration.md): launch flags, binding, TLS, CORS, directories, offline mode, service unit.
- [`references/api.md`](references/api.md): routes, API-format workflows, job lifecycle, websocket messages, memory release.
- [`references/models.md`](references/models.md): model folders, `extra_model_paths.yaml`, downloads.
- [`references/custom-nodes.md`](references/custom-nodes.md): Manager security levels, comfy-cli node commands, whitelisting.
- [`references/performance-memory.md`](references/performance-memory.md): VRAM and RAM flags, dynamic VRAM, sharing a GPU.
- [`references/integrations.md`](references/integrations.md): reverse proxy, auth gap, OpenAI wrapper outline.
- [`references/updating.md`](references/updating.md): git, comfy-cli and portable updates, rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/llama-swap-litellm.md`](references/combos/llama-swap-litellm.md): ComfyUI behind llama-swap with LiteLLM in front.
- [`templates/`](templates): systemd unit, `extra_model_paths.yaml`, llama-swap and LiteLLM entries.
- [`scripts/comfy-run.sh`](scripts/comfy-run.sh): submit a workflow, poll, download outputs (bash, curl, jq).

## Companion skills

- `self-hosted-genmedia`: choose between ComfyUI, sd-server and speech servers; memory planning and licences.
- `llama-swap`: hot-swap ComfyUI with LLMs on one GPU.
- `litellm`: keys, budgets and routing in front.
- `hugging-face`: model weights and cache.
- `nvidia-dgx-spark`: arm64 unified-memory platform notes.

## License

MIT
