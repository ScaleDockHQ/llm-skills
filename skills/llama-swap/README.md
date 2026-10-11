# Llama Swap

Install, configure and operate llama-swap, the single-binary Go proxy that exposes one OpenAI- and Anthropic-compatible URL and starts, swaps and stops the upstream engine (llama.cpp, vLLM, SGLang, Ollama, ComfyUI, stable-diffusion.cpp) for each requested model. Covers install, `config.yaml`, groups and the matrix router, TTL and preload, aliases through `setParamsByID`, API keys, peers, operation, updating and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill llama-swap
```

## Rules

- **Bind loopback.** `apiKeys` is not a firewall; llama-swap starts processes on the host.
- **Containers need `cmdStop`** and a larger `unloadTimeout`.
- **`healthCheckTimeout` must exceed the real cold load.**
- **Keys come from `${env.NAME}`**, never from the file.

## References

- [`references/install.md`](references/install.md): binary, Homebrew, WinGet, unified Docker images.
- [`references/config-schema.md`](references/config-schema.md): global and model keys, macros, filters, auth, peers.
- [`references/routing.md`](references/routing.md): groups, matrix, profiles, selectors, TTL, queues.
- [`references/api.md`](references/api.md): endpoints and log streams.
- [`references/operations.md`](references/operations.md): daily commands, observability, reverse proxy, security.
- [`references/integrations.md`](references/integrations.md): engines, gateways, Kubernetes.
- [`references/updating.md`](references/updating.md): upgrade and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/`](references/combos): LiteLLM, ComfyUI, DGX Spark.
- [`templates/`](templates): config, systemd unit, compose file.

## Companion skills

- `llama-cpp`, `vllm`: engines launched by `cmd`.
- `litellm`: gateway in front.
- `nvidia-dgx-spark`, `self-hosted-llms`, `local-llms`: platform and stack skills that use llama-swap.

## License

MIT
