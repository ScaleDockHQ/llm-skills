# InvokeAI

An agent skill for installing and operating [InvokeAI](https://github.com/invoke-ai/InvokeAI), the Apache-2.0 node-based creative engine and web UI for Stable Diffusion, SDXL, FLUX, Z-Image, Qwen-Image and Wan video. It helps an agent choose the launcher, a manual `uv` install or Docker, configure `invokeai.yaml` and multi-user mode, install models safely, fit memory with partial loading, drive the queue API, handle custom nodes, update with backups, and diagnose common failures.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill invokeai
```

## Rules

- **Single-user mode has no auth.** Keep the port on loopback.
- **Custom nodes are arbitrary Python.**
- **Ask before installs, downloads and external keys.**
- **Pin release tags**, not `latest`.
- **Tokens stay in `invokeai.yaml`, `api_keys.yaml` or the environment.**

## References

- [`references/install.md`](references/install.md): launcher, `uv`, Docker.
- [`references/configuration.md`](references/configuration.md): `invokeai.yaml`, binding, multi-user mode.
- [`references/models-and-nodes.md`](references/models-and-nodes.md): models, providers, nodes.
- [`references/api.md`](references/api.md): queue API.
- [`references/memory-and-performance.md`](references/memory-and-performance.md): memory settings.
- [`references/updating.md`](references/updating.md): updates and v7 alpha.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `self-hosted-genmedia`: choosing a media stack.
- `comfyui`, `diffusers`: related engines.
- `caddy`: proxy with auth.

## License

MIT
