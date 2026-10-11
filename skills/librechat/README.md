# LibreChat

An agent skill for running LibreChat, the self-hosted multi-user chat UI with agents, MCP and RAG, against your own model servers. It covers a pinned Docker Compose install, `librechat.yaml` custom endpoints for OpenAI-compatible and Anthropic Messages servers (vLLM, llama.cpp, Ollama, LiteLLM, llama-swap), model-name mapping, key handling through `.env`, tool calling, agents, reasoning and MCP settings, and symptom-first troubleshooting, with templates and a read-only endpoint probe.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill librechat
```

## Rules

- **Ask before changing the system.** Installs, config edits, restarts, registration and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in `.env` (`0600`) and are referenced as `${VAR}`; presence is checked by name only.
- **`apiKey` is mandatory** on every custom endpoint, even without auth; use a placeholder.
- **`baseURL` depends on the API:** `/v1` for OpenAI-compatible, server root for `provider: anthropic`.
- **Inside Docker, `localhost` is the container.** Use `host.docker.internal` or a service name.
- **Pin the image**, close open registration before exposing, keep MongoDB and Meilisearch private.
- **Verify upstream.** Fields come from the librechat.ai docs and release notes at use time.

## References

- [`references/install.md`](references/install.md): Compose install, `.env` essentials, mounting config, networking, updating.
- [`references/custom-endpoints.md`](references/custom-endpoints.md): every field, per-server recipes, Anthropic provider, model-name mapping, auth headers.
- [`references/agents-and-tools.md`](references/agents-and-tools.md): tool calling per engine, agents, reasoning, MCP, context and cost.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

Templates: [`assets/librechat.yaml`](assets/librechat.yaml), [`assets/docker-compose.override.yml`](assets/docker-compose.override.yml). Script: [`scripts/check-endpoint.sh`](scripts/check-endpoint.sh).

## Companion skills

- `llm-clients`: choosing and troubleshooting every kind of LLM client.
- `litellm`, `llama-swap`: gateways to point LibreChat at.
- `vllm`, `llama-cpp`, `ollama`: the engines behind the endpoint.
- `tool-calling-parsers`: fixing agents that never call tools.
- `open-webui`, `lobehub`: other multi-user chat UIs.

## License

MIT
