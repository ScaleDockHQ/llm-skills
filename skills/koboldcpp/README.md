# KoboldCpp

Install, run and tune KoboldCpp, the single-executable llama.cpp-based server for GGUF models with the KoboldAI Lite web UI and OpenAI, Ollama, Anthropic, A1111 and ComfyUI style APIs. Covers the platform binaries and source builds, GPU backends (CUDA, Vulkan, Metal), `.kcpps` configs, chat templates and tools, vision, image, speech, music, embeddings and MCP, admin and router mode, llama-swap and LiteLLM in front, systemd and Docker, updating and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill koboldcpp
```

## Rules

- **Official downloads only.** The GitHub releases of `LostRuins/koboldcpp`; `koboldcpp.com` is a fake site.
- **Bind loopback or a private network.** `--host` unset listens everywhere; `--password` skips image endpoints.
- **Keys from the environment.** `KCPP_PASSWORD` and `KCPP_ADMINPASSWORD`, never on a shown command line.
- **Check flags with `--help`.** They are renamed between releases.
- **Ask before** installs, services, exposure, `--remotetunnel` and updates.

## References

- [`references/install.md`](references/install.md): binaries, source builds, Termux, Docker, cloud.
- [`references/serve-config.md`](references/serve-config.md): flags, `.kcpps` files, env vars.
- [`references/models-and-formats.md`](references/models-and-formats.md): GGUF, mmproj, LoRA, fit.
- [`references/features.md`](references/features.md): jinja, tools, MCP, vision, image, speech, music.
- [`references/api.md`](references/api.md): endpoints, auth, admin routes.
- [`references/performance-tuning.md`](references/performance-tuning.md): offload, KV, MoE, speculation, RPC.
- [`references/integrations.md`](references/integrations.md): llama-swap, LiteLLM, router mode, proxies.
- [`references/observability.md`](references/observability.md): perf endpoint, logs, health.
- [`references/updating.md`](references/updating.md): upgrade and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/`](templates): systemd unit, compose file, `.kcpps` config.

## Companion skills

- `choosing-inference-engine`: KoboldCpp vs vLLM vs llama.cpp vs SGLang.
- `llama-cpp`: the upstream engine.
- `llama-swap`: on-demand model swapping.
- `litellm`: keys, routing, fallbacks.
- `comfyui`: richer image workflows.

## License

MIT
