# goose

An agent skill for connecting goose, the open-source AI agent (Desktop and CLI), to your own model endpoints. It covers the built-in OpenAI provider with `OPENAI_HOST`, custom provider JSON for OpenAI, Anthropic and Ollama engines, built-in LM Studio, llama-swap, LiteLLM and Ollama providers, key storage (keyring, `secrets.yaml`, environment, command-based credentials), model and context mapping, tool calling and the tool shim, streaming, update, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill goose
```

## Rules

- **Ask before changing the system.** Installs, config and provider-file edits, and exported keys need approval and a backup.
- **Secrets never touch output.** goose ignores keys in `config.yaml`; use the keyring, a `0600` `secrets.yaml` or environment variables, and check presence by name only.
- **Mind the URL shape.** OpenAI provider: root host plus base path. Custom OpenAI engine: full completions URL. Anthropic engine: root.
- **Tools or nothing.** Fix the engine's tool parser first; use the tool shim as a fallback.
- **Declare context.** Set `context_limit` or `GOOSE_CONTEXT_LIMIT` at or below the engine's window.
- **Verify upstream.** Variables and defaults come from the goose docs and releases at use time.

## References

- [`references/install.md`](references/install.md): install, config files, key storage, headless, update.
- [`references/custom-endpoints.md`](references/custom-endpoints.md): OpenAI env vars, custom provider JSON, Anthropic and Ollama engines.
- [`references/models-and-tools.md`](references/models-and-tools.md): models, context, tool calling, toolshim, streaming.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/engines-and-gateways.md`](references/combos/engines-and-gateways.md): vLLM, llama.cpp, Ollama, LM Studio, llama-swap, LiteLLM.

Templates: `assets/custom_provider.openai.json`, `assets/custom_provider.anthropic.json`, `assets/goose.env.example`.

## Companion skills

- `llm-clients`, `litellm`, `llama-swap`, `vllm`, `llama-cpp`, `ollama`, `lm-studio`.

## License

MIT
