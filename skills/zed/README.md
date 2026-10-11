# Zed

An agent skill for connecting Zed, the Rust code editor, to your own model endpoints. It covers `openai_compatible` and `anthropic_compatible` providers against vLLM, llama.cpp, Ollama, LM Studio, LiteLLM and llama-swap, exact model-name and context mapping, key handling through the keychain or environment, tool calling, reasoning and streaming caveats, self-hosted edit prediction, update, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill zed
```

## Rules

- **Ask before changing the system.** Settings edits, exported keys and restarts need approval and a backup.
- **Secrets never touch output or `settings.json`.** Keys live in the keychain, a `0600` file or an environment variable; presence is checked by name only.
- **Name is the wire id.** `name` is sent as the model; copy it from the endpoint's `/v1/models`.
- **Declare capabilities and context.** Zed does not learn them from a standard model list.
- **Mind the base URL.** OpenAI-compatible ends at `/v1`; verify the Anthropic-compatible path in the server log.
- **Verify upstream.** Setting names and defaults come from the Zed docs and releases at use time.

## References

- [`references/install.md`](references/install.md): install, channels, settings locations, environment, update.
- [`references/custom-endpoints.md`](references/custom-endpoints.md): compatible-provider fields, keys, headers, tests.
- [`references/models-and-features.md`](references/models-and-features.md): capabilities, tools, reasoning, streaming, feature models.
- [`references/local-providers.md`](references/local-providers.md): built-in Ollama, llama.cpp and LM Studio providers.
- [`references/edit-prediction.md`](references/edit-prediction.md): self-hosted tab completion.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-llama-swap.md`](references/combos/litellm-llama-swap.md): one gateway for many models.

Templates: `assets/settings.openai-compatible.jsonc`, `assets/settings.anthropic-compatible.jsonc`.

## Companion skills

- `llm-clients`, `litellm`, `llama-swap`, `vllm`, `llama-cpp`, `ollama`, `lm-studio`.

## License

MIT
