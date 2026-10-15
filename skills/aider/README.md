# Aider

Helps an agent connect Aider (`aider`, the terminal AI pair-programming tool, PyPI `aider-chat`) to self-hosted and gateway models: install and upgrade, `OPENAI_API_BASE` with the `openai/` prefix, `ollama_chat/` and the Anthropic base-URL route, key handling in `.env` without printing secrets, model metadata and model settings files, edit formats, reasoning tags, and troubleshooting. Covers vLLM, llama.cpp, Ollama, llama-swap and LiteLLM, with a script that probes an endpoint the way Aider uses it.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill aider
```

## Rules

- **Prefix the model.** `openai/<served-name>` for OpenAI-compatible servers, `ollama_chat/` for Ollama.
- **Keys in `.env` or the environment.** Never on the command line, never printed; only OpenAI and Anthropic keys may be in the YAML.
- **Aider never enforces token limits.** Unknown-context warnings are usually harmless; the server and Ollama's window decide.
- **Match the edit format to the model.** `whole` for small models that garble diffs.
- **Test the endpoint first** with `scripts/check-endpoint.sh`.

## References

- [`references/custom-endpoints.md`](references/custom-endpoints.md): base URLs, prefixes, keys, per-engine setup.
- [`references/models-and-limits.md`](references/models-and-limits.md): metadata, model settings, weak and editor models, reasoning.
- [`references/compatibility.md`](references/compatibility.md): edit formats, streaming, modes, context pressure.
- [`references/install-and-update.md`](references/install-and-update.md): install, upgrade, config file locations.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-gateway.md`](references/combos/litellm-gateway.md): LiteLLM in front of local engines.

Also ships `templates/aider.conf.yml`, `templates/env.example`, `templates/aider.model.settings.yml`, `templates/aider.model.metadata.json` and `scripts/check-endpoint.sh`.

## Companion skills

- `litellm`, `llm-gateway`: gateway for several engines.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: the endpoints.
- `llm-clients`: other clients.

## License

MIT
