# OpenCode

Helps an agent connect OpenCode (`opencode`, the open-source terminal coding agent from anomalyco, formerly sst) to self-hosted and gateway models: install and upgrade, `opencode.json` custom providers for OpenAI-compatible and Anthropic-compatible endpoints, key handling with `{env:}` and `{file:}` without printing secrets, model limits and capability flags, the OpenCode 1 versus 2 config split, tool-calling and streaming caveats, and troubleshooting. Covers vLLM, llama.cpp, Ollama, llama-swap and LiteLLM, with a script that probes an endpoint the way OpenCode uses it.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill opencode
```

## Rules

- **One AI SDK package per wire format.** `@ai-sdk/openai-compatible` for chat completions, `@ai-sdk/openai` for Responses, `@ai-sdk/anthropic` for Messages.
- **Declare each model.** `limit.context` and `limit.output` together, `tool_call`, and image flags; IDs must match `/v1/models`.
- **Keys by reference.** `{env:NAME}` or `{file:path}`, never inline or printed.
- **Know the generation.** v1 uses `provider`; v2 uses `providers`, `package` and `settings`.
- **Test the endpoint first** with `scripts/check-endpoint.sh`.

## References

- [`references/custom-providers.md`](references/custom-providers.md): provider blocks, auth, per-engine setup.
- [`references/models-and-limits.md`](references/models-and-limits.md): model keys, limits, capability flags, reasoning, variants.
- [`references/compatibility.md`](references/compatibility.md): tool calling, streaming, reasoning fields, defaults that surprise.
- [`references/opencode-2.md`](references/opencode-2.md): OpenCode 2 config, discovery, install.
- [`references/install-and-update.md`](references/install-and-update.md): install paths, upgrade and pin, storage, offline.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-gateway.md`](references/combos/litellm-gateway.md): LiteLLM in front of local engines.

Also ships `templates/opencode.json`, `templates/opencode-v2.jsonc` and `scripts/check-endpoint.sh`.

## Companion skills

- `litellm`, `llm-gateway`: gateway for several engines.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: the endpoints.
- `tool-calling-parsers`: engine-side tool-call parsing.
- `llm-clients`: other clients.

## License

MIT
