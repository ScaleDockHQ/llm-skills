# LocalAI

Agent skill for installing, running and operating LocalAI (`local-ai`): the self-hosted server with OpenAI, Anthropic Messages, Open Responses and Ollama style endpoints, a model gallery and downloadable gRPC backends (llama.cpp, vLLM, whisper, diffusers and more). Covers container, binary and Kubernetes installs, model YAML, backends, auth and bind safety, TLS proxying, LRU and watchdog memory control, distributed mode, observability, updates and troubleshooting.

Verified against LocalAI v4.11.0 on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill localai
```

## Rules

- **Ask before changing the system.** Installs, image pulls, model and backend downloads, services and exposure need approval.
- **Secrets never touch output.** API keys, `HF_TOKEN`, OAuth and NATS secrets live in `0600` env files.
- **Auth is off by default.** The server refuses a public bind without auth; set `LOCALAI_API_KEY` and use a TLS proxy.
- **Persist `/models`, `/backends`, `/configuration` and `/data`.** Pin a versioned image tag.
- **Backends are separate downloads** and have no built-in rollback.

## References

- [`references/install.md`](references/install.md): container tags, binary, macOS, Helm.
- [`references/serve-config.md`](references/serve-config.md): flags, env vars, auth, TLS, bind safety.
- [`references/models-and-formats.md`](references/models-and-formats.md): gallery, URIs, backends, model YAML.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): multi-GPU, RPC, P2P, distributed mode.
- [`references/features.md`](references/features.md): tools, MCP, embeddings, rerank, failover.
- [`references/api.md`](references/api.md): endpoints and errors.
- [`references/performance-tuning.md`](references/performance-tuning.md): LRU, watchdog, concurrency, options.
- [`references/integrations.md`](references/integrations.md): LiteLLM, clients, systemd, Kubernetes.
- [`references/observability.md`](references/observability.md): metrics, traces, health, logs.
- [`references/updating.md`](references/updating.md): update and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/combos/ik-llama-cpp-backend.md`](references/combos/ik-llama-cpp-backend.md): the ik-llama-cpp backend.
- [`templates/`](templates): Compose file, systemd unit, LiteLLM config, model YAML.

## Companion skills

- `choosing-inference-engine`: compare engines.
- `ik-llama-cpp`, `llama-cpp`, `vllm`: engines LocalAI can run as backends.
- `litellm`: gateway.
