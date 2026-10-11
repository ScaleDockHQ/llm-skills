# AnythingLLM

An agent skill for running AnythingLLM, the all-in-one chat, RAG and agent app, against your own model servers. It covers the persistent Docker install, the Generic OpenAI, Ollama, LiteLLM and LocalAI providers with env names, key and header handling, model-name and context-window settings, per-engine recipes for vLLM, llama.cpp, llama-swap, LiteLLM and Ollama, `@agent` tool calling (native versus prompt-based), MCP servers, and troubleshooting, with an env template and a read-only endpoint probe.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill anythingllm
```

## Rules

- **Ask before changing the system.** Installs, `.env` edits, container recreation and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in the mounted server `.env` (`0600`); read non-secret keys with a targeted `grep`, never `cat` it.
- **Persist storage** with the two `-v` mounts, or everything is lost on container removal.
- **Inside Docker, `localhost` is the container.** Use `host.docker.internal` or `172.17.0.1` on Linux.
- **Generic OpenAI needs `/v1`, a typed model id and a declared context window** (default 4096).
- **Anthropic provider has no base URL.** Use an OpenAI-compatible route for gateways.
- **Verify upstream.** Variables come from the upstream `.env.example` and docs at use time.

## References

- [`references/install.md`](references/install.md): Docker run and Compose, permissions, auth, AVX2, updating.
- [`references/llm-providers.md`](references/llm-providers.md): providers, env names, model mapping, per-engine recipes, key handling.
- [`references/agents-and-mcp.md`](references/agents-and-mcp.md): `@agent`, tool calling, tool selection, MCP, flows.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

Templates: [`assets/anythingllm.env.example`](assets/anythingllm.env.example). Script: [`scripts/check-endpoint.sh`](scripts/check-endpoint.sh).

## Companion skills

- `llm-clients`: choosing and troubleshooting every kind of LLM client.
- `litellm`, `llama-swap`: gateways to point AnythingLLM at.
- `vllm`, `llama-cpp`, `ollama`: the engines behind the endpoint.
- `tool-calling-parsers`: fixing agents that never call tools.
- `open-webui`, `librechat`: other multi-user chat UIs.

## License

MIT
