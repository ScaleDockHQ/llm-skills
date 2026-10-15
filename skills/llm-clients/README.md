# LLM Clients Skill

An agent skill for connecting the tools people actually use to any OpenAI- or Anthropic-compatible endpoint: coding agents (Claude Code, Codex CLI, OpenCode, Aider), IDE extensions (Cursor, Continue, Cline, Roo Code, Kilo Code), chat UIs (Open WebUI, LobeHub) and SDK apps (OpenAI, Anthropic, Vercel AI SDK). It helps an AI coding agent discover what is installed, pick the right API for each client, declare context windows and tool, vision and reasoning support explicitly, keep keys out of shared config, and debug the usual failures: wrong base URL shape, Responses vs Chat Completions mismatches, unreachable local endpoints and missing capabilities.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill llm-clients
```

## Rules

- **Know which API the client speaks.** Chat Completions, Responses or Anthropic Messages, matched to the endpoint first.
- **Expose capabilities explicitly.** Context window, max output, tools, vision and reasoning declared per model.
- **Use stable model names.** Gateway aliases, not provider or file names.
- **Keys in env vars or keychains, never in shared config.** Reference them; one virtual key per tool.
- **Test with a real tool call, not just chat.** Chat working proves little.

## References

- [`references/coding-agents.md`](references/coding-agents.md): Claude Code, Codex CLI, OpenCode, Aider.
- [`references/ide-extensions.md`](references/ide-extensions.md): Cursor, Continue, Cline, Roo Code, Kilo Code.
- [`references/chat-uis.md`](references/chat-uis.md): Open WebUI, LobeHub.
- [`references/sdks.md`](references/sdks.md): OpenAI, Anthropic and Vercel AI SDK base URLs and API defaults.
- [`references/capabilities.md`](references/capabilities.md): where clients get context, tool, vision and reasoning info, and how to declare it.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

Templates: [`claude-code.env.example`](assets/claude-code.env.example), [`claude-code-settings.json`](assets/claude-code-settings.json), [`codex-config.toml`](assets/codex-config.toml), [`opencode.json`](assets/opencode.json), [`continue-config.yaml`](assets/continue-config.yaml), [`aider.conf.yml`](assets/aider.conf.yml), [`aider.model.metadata.json`](assets/aider.model.metadata.json), [`open-webui.env.example`](assets/open-webui.env.example).

## Companion skills

From [ScaleDockHQ/llm-skills](https://github.com/ScaleDockHQ/llm-skills); install any of them with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `llm-gateway`: the endpoint these clients connect to; aliases, keys, API bridging.
- `local-llms`: endpoints on laptops and desktops.
- `self-hosted-llms`: endpoints on servers.
- `cloud-llms`: hosted APIs and their keys.
- `choosing-llm-hosting`: decide where models run.
- `llm-observability`: see what clients actually send.
- `llm-evals`: compare models behind the same client.

## Credits

Built on the official documentation of [Claude Code](https://code.claude.com/docs/en/llm-gateway), [Codex](https://github.com/openai/codex), [OpenCode](https://opencode.ai/docs/), [Aider](https://aider.chat/docs/), [Cursor](https://cursor.com/help), [Continue](https://docs.continue.dev/), [Cline](https://docs.cline.bot/), [Roo Code](https://roocodeinc.github.io/Roo-Code/), [Kilo Code](https://kilo.ai/docs/), [Open WebUI](https://docs.openwebui.com/), [LobeHub](https://lobehub.com/docs), the [OpenAI](https://github.com/openai/openai-python) and [Anthropic](https://github.com/anthropics/anthropic-sdk-python) SDKs and the [Vercel AI SDK](https://ai-sdk.dev/).

## License

MIT
