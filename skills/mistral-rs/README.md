# mistral.rs

Install, serve, quantize, tune, scale out, update and troubleshoot mistral.rs, the Rust LLM inference engine with the
`mistralrs` CLI. Covers the installer, Docker and pip installs, CUDA lane selection, ISQ, UQFF and GGUF quantization,
paged attention, the OpenAI, Responses and Anthropic APIs, tool calling, structured output, dynamic LoRA, MTP speculative
decoding, agent and sandbox safety, NCCL multi-GPU, Prometheus metrics and Kubernetes. Verified against mistral.rs v0.9.4.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill mistral-rs
```

## Rules

- **No built-in auth, so loopback by default.** `--host` defaults to `0.0.0.0` and the server ignores API keys.
- **Agent tools are code execution.** `--agent`, `--enable-code-execution` and `--enable-shell` stay off on reachable servers.
- **Pin versions.** `MISTRALRS_INSTALL_TAG`, `pip install mistralrs==X.Y.Z` or a versioned image tag; read installer scripts before running.
- **Secrets stay out of output.** Tokens live in `0600` files or environment variables.
- **Ask before changing the system.** Installs, services and exposure need approval.

## References

- [`references/install.md`](references/install.md): installer, CUDA lanes, Docker tags, pip, source builds.
- [`references/serve-config.md`](references/serve-config.md): flags, TOML config, environment variables.
- [`references/models-and-formats.md`](references/models-and-formats.md): supported models, ISQ, UQFF, GGUF, memory.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): NCCL, layer mapping, multi-node, ring.
- [`references/features.md`](references/features.md): tools, structured output, LoRA, MTP, agents.
- [`references/api.md`](references/api.md): endpoints, the auth gap, reverse proxy.
- [`references/performance-tuning.md`](references/performance-tuning.md): paged attention, concurrency, prefix cache.
- [`references/integrations.md`](references/integrations.md): LiteLLM, Codex, Claude Code, MCP, Kubernetes.
- [`references/observability.md`](references/observability.md): logs, health, Prometheus metrics.
- [`references/updating.md`](references/updating.md): upgrade and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- `templates/`: TOML config, compose, systemd, Kubernetes.

## Companion skills

- `choosing-inference-engine`: compare mistral.rs with other engines.
- `litellm`, `llama-swap`, `llm-gateway`: routing in front of mistral.rs.
- `caddy`, `traefik`: TLS and auth in front of mistral.rs.
- `tool-calling-parsers`, `structured-outputs`, `model-quantization`: technique detail.

## License

MIT
