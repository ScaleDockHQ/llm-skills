# Kilo Code

An agent skill for configuring Kilo Code (VS Code, JetBrains, `kilo` CLI) against self-hosted LLM endpoints: vLLM, llama.cpp, Ollama, LiteLLM and llama-swap. It covers the Custom provider dialog and `kilo.jsonc`, the OpenAI Compatible, OpenAI Responses and Anthropic Messages wire APIs, key handling with `{env:}` and `{file:}`, model id mapping, context and output limits, tool-calling and streaming caveats, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill kilo-code
```

## Rules

- **Ask before changing the system.** Show the `kilo.jsonc` diff and keep a backup.
- **Secrets never touch output.** Keys go in global config as `{env:}` or `{file:}`, never literal in a project `kilo.json`.
- **Set `limit.context` and `limit.output`**; unset limits disable compaction.
- **Set `tool_call: true`** for agent models.
- **Verify upstream.** Kilo moves fast; kilo.ai/docs is the source of truth at use time.

## References

- [`references/install.md`](references/install.md): extension, JetBrains, CLI, config locations, versions.
- [`references/providers-endpoints.md`](references/providers-endpoints.md): Custom provider fields, schema, wire APIs, keys, limits.
- [`references/combos/self-hosted-endpoints.md`](references/combos/self-hosted-endpoints.md): exact values per engine and gateway.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/updating.md`](references/updating.md): updating and version lines.

**Template:** [`assets/kilo.jsonc`](assets/kilo.jsonc). **Script:** [`scripts/probe.sh`](scripts/probe.sh): read-only check of models, chat, streaming and tool calls.

## Companion skills

- `litellm`, `llm-gateway`, `llm-clients`, `cline`, `continue`, `cursor`, `vllm`, `llama-cpp`, `ollama`, `llama-swap`.

## License

MIT
