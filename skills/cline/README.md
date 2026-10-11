# Cline

An agent skill for configuring Cline (VS Code, JetBrains, CLI) against self-hosted LLM endpoints: vLLM, llama.cpp, Ollama, LiteLLM and llama-swap, over OpenAI-compatible or Anthropic-compatible base URLs. It covers the OpenAI Compatible, Anthropic custom-base-URL, Ollama and LiteLLM providers, key handling in `~/.cline`, context and output limits, Compact Prompt for local models, proxies and CA certificates, tool-calling and streaming caveats, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill cline
```

## Rules

- **Ask before changing the system.** Provider settings and `~/.cline` files need approval and an undo path.
- **Secrets never touch output.** `providers.json` holds keys; keep it owner-only, list provider ids only, avoid `-k` on the command line.
- **Set Context Window and Max Output** explicitly for non-catalog models.
- **Local models: Use Compact Prompt** and keep tasks short.
- **Verify upstream.** Cline releases on several lines; docs.cline.bot is the source of truth at use time.

## References

- [`references/install.md`](references/install.md): IDE, CLI, config layout, environment variables, proxies and CA.
- [`references/providers-endpoints.md`](references/providers-endpoints.md): OpenAI Compatible, Anthropic base URL, Ollama, LiteLLM, CLI auth, key handling.
- [`references/combos/self-hosted-endpoints.md`](references/combos/self-hosted-endpoints.md): exact values per engine and gateway.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/updating.md`](references/updating.md): release lines and updating.

**Script:** [`scripts/probe.sh`](scripts/probe.sh): read-only check of models, chat, streaming and tool calls (key from a file or environment, never printed).

## Companion skills

- `litellm`, `llm-gateway`, `llm-clients`, `kilo-code`, `continue`, `cursor`, `vllm`, `llama-cpp`, `ollama`, `llama-swap`.

## License

MIT
