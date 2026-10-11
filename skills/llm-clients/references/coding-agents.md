# Coding agents: Claude Code, Codex CLI, OpenCode, Aider

> Verified against Claude Code v2.1.296, Codex CLI rust-v0.162.1, OpenCode v1.19.0, Aider v0.86.0, 2026-10-11

Stack notes only. Per-client install, config, capability flags and troubleshooting live in the product skills.

## How they plug into this stack

Terminal agents run on the user's machine, so `localhost`, LAN and VPN addresses all work. Match the API the agent sends to what the endpoint serves; bridge on the server (`llm-gateway`) when it does not.

| Agent       | API it sends                                        | Key source                                                    |
| ----------- | --------------------------------------------------- | ------------------------------------------------------------- |
| Claude Code | Anthropic Messages (`/v1/messages`)                 | `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY` or `apiKeyHelper` |
| Codex CLI   | OpenAI Responses (`/v1/responses`) only             | `env_key` or a `[model_providers.<id>.auth]` command          |
| OpenCode    | Chat Completions or Responses, per provider package | `{env:NAME}` or the `opencode auth` store                     |
| Aider       | Chat Completions through LiteLLM's client library   | `OPENAI_API_KEY` env var or `.env`                            |

Stack pitfalls:

- Base URL ending in `/v1` for Claude Code gives `/v1/v1/messages` and 404.
- Codex 404 on `/v1/responses` means a chat-only endpoint; bridge Responses in the gateway.
- Declare context window per model (OpenCode `limit.context`, Aider model metadata, Claude Code window variables), or compaction fires late.
- Through LiteLLM, OpenCode may send `reasoningSummary`, which chat backends reject; drop it with `additional_drop_params`.
- Test with a task that edits a file; chat alone does not exercise tool calls.

Depth:

- `claude-code`: `npx skills add ScaleDockHQ/llms-skills --skill claude-code`
- `codex-cli`: `npx skills add ScaleDockHQ/llms-skills --skill codex-cli`
- `opencode`: `npx skills add ScaleDockHQ/llms-skills --skill opencode`
- `aider`: `npx skills add ScaleDockHQ/llms-skills --skill aider`
