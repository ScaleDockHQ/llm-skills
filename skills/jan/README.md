# Jan Skill

An agent skill for [Jan](https://github.com/janhq/jan), the open-source desktop app that runs LLMs offline. It covers packages for macOS, Windows and Linux, the Local API Server on port 1337 (OpenAI and Anthropic compatible) with its key, host and Trusted Hosts settings, importing GGUF and MLX models, custom providers for vLLM, Ollama and LiteLLM, MCP servers and the Claude Code integration, updates across the 0.8.x line and troubleshooting. Every command is read-only first and never prints secrets.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill jan
```

## Rules

- **Ask before changing the system.** Installs, `0.0.0.0` binding and data deletion need approval.
- **Localhost by default**; set a key and Trusted Hosts before exposing.
- **Custom endpoint URLs include `/v1`.**
- **The engine ships with the app**; use a custom provider for another `llama-server`.
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): packages, data folder, uninstall.
- [`references/local-api-server.md`](references/local-api-server.md): server settings and endpoints.
- [`references/models-and-engines.md`](references/models-and-engines.md): models, llama.cpp, MLX.
- [`references/providers-and-integrations.md`](references/providers-and-integrations.md): custom endpoints, MCP, Claude Code.
- [`references/updating.md`](references/updating.md): updates and migration notes.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

`local-llms`, `lm-studio`, `ollama`, `llama-cpp`, `mlx`, `litellm`, `llm-clients`.

## License

MIT
