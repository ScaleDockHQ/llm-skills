# Codex CLI

Helps an agent connect OpenAI's Codex CLI (`codex`) to self-hosted and gateway models through custom model providers over the Responses API: install and update, `~/.codex/config.toml` providers and profiles, key handling without printing secrets, context and compaction limits, compatibility notes and known open issues for non-OpenAI backends, and troubleshooting. Covers vLLM, llama.cpp, Ollama, llama-swap and LiteLLM endpoints, with a script that probes an endpoint the way Codex uses it.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill codex-cli
```

## Rules

- **Responses only.** `wire_api = "responses"`; chat-only engines need LiteLLM's bridge.
- **Providers in the user config.** Project `.codex/config.toml` ignores provider and credential keys; use `--profile`.
- **Keys by name.** `env_key` or an auth command; never inline or printed.
- **Declare real limits** (`model_context_window`, compaction limit) and never trust auto-compaction to recover an overflow.
- **Test the endpoint first** with `scripts/check-endpoint.sh`.

## References

- [`references/custom-providers.md`](references/custom-providers.md): provider keys, auth, profiles, `--oss`, per-engine setup.
- [`references/models-and-limits.md`](references/models-and-limits.md): model names, context window, compaction, reasoning.
- [`references/compatibility.md`](references/compatibility.md): Responses features, tools, MCP, history items, open issues.
- [`references/install-and-update.md`](references/install-and-update.md): install paths, updating, state directory.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-responses-bridge.md`](references/combos/litellm-responses-bridge.md): LiteLLM in front of chat-only engines.

Also ships `templates/config.toml`, `templates/local.config.toml` and `scripts/check-endpoint.sh`.

## Companion skills

- `litellm`, `llm-gateway`: bridge and manage the endpoint.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: the endpoints.
- `tool-calling-parsers`: engine-side tool-call parsing.
- `llm-clients`: other clients.

## License

MIT
