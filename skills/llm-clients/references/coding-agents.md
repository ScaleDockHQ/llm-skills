# Coding agents: Claude Code, Codex CLI, OpenCode, Aider

> Verified against Claude Code v2.1.296, Codex CLI rust-v0.162.1, OpenCode v1.19.0, Aider v0.86.0, 2026-10-11

Terminal coding agents run on the user's machine, so `localhost`, LAN and VPN addresses all work. What differs is the API each one speaks and where it reads model metadata.

| Agent | API it sends | Config location | Key source |
|---|---|---|---|
| Claude Code | Anthropic Messages (`/v1/messages`) | env vars, or `env` block in `~/.claude/settings.json` / `.claude/settings.json` | `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY` or `apiKeyHelper` |
| Codex CLI | OpenAI Responses (`/v1/responses`) only | `~/.codex/config.toml` | `env_key` or `[model_providers.<id>.auth]` command |
| OpenCode | Chat Completions (`@ai-sdk/openai-compatible`) or Responses (`@ai-sdk/openai`) | `~/.config/opencode/opencode.json`, project `opencode.json` | `{env:NAME}` or `opencode auth` store |
| Aider | Chat Completions via LiteLLM client library | `.aider.conf.yml`, env vars | `OPENAI_API_KEY` env var or `.env` |

## Claude Code

### What it is and when to choose it

Anthropic's agentic CLI (plus VS Code and JetBrains integrations that share its settings). Speaks Anthropic Messages only. Point it at an endpoint that serves `/v1/messages`: the Anthropic API, a gateway with an Anthropic route (LiteLLM, OpenRouter), or an engine that implements Messages natively. Anthropic does not support routing Claude Code to non-Claude models through a gateway; it works technically, but you own the breakage.

### Config location

Env vars in the shell, or the `env` object in `~/.claude/settings.json` (user) or `.claude/settings.json` (project, committed, so no keys there). `/status` inside Claude Code shows `Anthropic base URL` and which credential source is active.

### Minimal config

```bash
export ANTHROPIC_BASE_URL="https://llm.example.com"   # root, no /v1; Claude Code appends /v1/messages
export ANTHROPIC_AUTH_TOKEN="$LITELLM_VIRTUAL_KEY"     # sent as Authorization: Bearer
export ANTHROPIC_MODEL="claude-main"                   # gateway alias
```

- `ANTHROPIC_AUTH_TOKEN` sends `Authorization: Bearer`; `ANTHROPIC_API_KEY` sends `x-api-key`. Use the one your gateway checks. LiteLLM accepts both.
- `apiKeyHelper` in settings runs a shell command that prints the key to stdout (for example a script reading a vault, or on macOS `security find-generic-password -s llm-gateway -w` for a keychain item); refresh with `CLAUDE_CODE_API_KEY_HELPER_TTL_MS`. The key never sits in a config file.
- Model slots: `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL` (used for background tasks), `CLAUDE_CODE_SUBAGENT_MODEL`. `ANTHROPIC_SMALL_FAST_MODEL` is deprecated.
- `ANTHROPIC_CUSTOM_MODEL_OPTION` (+ `_DESCRIPTION`) adds one entry to the `/model` picker.
- `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` makes the picker call `GET /v1/models` on the gateway and keep IDs containing `claude` or `anthropic`; other aliases are filtered out.
- `ANTHROPIC_CUSTOM_HEADERS` adds headers (newline-separated `Name: value`).

Template: `templates/claude-code.env.example`, `templates/claude-code-settings.json`.

### Capability flags

- Context: an unrecognised model ID is assumed to have a 200K window (an ID containing `[1m]` is assumed 1M). Set `CLAUDE_CODE_MAX_CONTEXT_TOKENS` to the real window so compaction happens on time. It only applies to IDs Claude Code cannot resolve to a known Claude model; IDs like `claude-...` resolve to the known model.
- `CLAUDE_CODE_AUTO_COMPACT_WINDOW` when the gateway enforces a smaller window than the model's native one (clamped to at least 100,000).
- Output: `CLAUDE_CODE_MAX_OUTPUT_TOKENS`; default 32000 for unknown IDs. Keep it below the backend's output limit.
- `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` stops `anthropic-beta` headers and beta-only fields that non-Anthropic backends reject.
- MCP tool search is off by default when `ANTHROPIC_BASE_URL` is not a first-party host; set `ENABLE_TOOL_SEARCH=true` only if the gateway forwards `tool_reference` blocks.
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` for offline or gateway-only setups.
- `API_TIMEOUT_MS` (default 600000) for slow local prefill.

### Pitfalls

- Base URL ending in `/v1` produces `/v1/v1/messages` and 404s.
- A gateway that rewrites context-limit errors breaks Claude Code's auto-compact-and-retry; run `/compact`, then set the window variables above.
- `/v1/messages/count_tokens` is optional; when missing Claude Code estimates.
- Login screen on start means no credential reached it; check `/status`.
- Non-Claude models behind the gateway: expect tool-format and thinking-block differences; test edits, not just chat.

Verify with the same base URL and key:

```bash
curl -sS "$ANTHROPIC_BASE_URL/v1/messages" \
  -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d '{"model":"claude-main","max_tokens":32,"messages":[{"role":"user","content":"ping"}]}' | jq '{type, stop_reason, model}'
```

## Codex CLI

### What it is and when to choose it

OpenAI's open-source coding agent. Custom providers must speak the **Responses API**: `wire_api = "responses"` is the only supported value. A chat-only engine needs a gateway that serves `/v1/responses` and bridges to chat completions (LiteLLM `use_chat_completions_api`, see the `llm-gateway` skill).

### Config location

`~/.codex/config.toml`. A project `.codex/config.toml` is read only for trusted projects and cannot override settings that redirect credentials, so keep providers in the user file. Profiles: `codex --profile <name>` reads `~/.codex/<name>.config.toml` layered on top.

### Minimal config

```toml
model = "coder"
model_provider = "gateway"
model_context_window = 131072

[model_providers.gateway]
name = "LLM gateway"
base_url = "https://llm.example.com/v1"
env_key = "LITELLM_API_KEY"
wire_api = "responses"
```

- Custom provider IDs cannot be `openai`, `ollama` or `lmstudio` (reserved). Built-ins: `codex --oss` uses `oss_provider` (`lmstudio` or `ollama`).
- `openai_base_url` repoints the built-in OpenAI provider instead of defining a new one.
- Headers: `http_headers` (static) and `env_http_headers` (value from env var).
- Command-backed tokens: `[model_providers.<id>.auth]` with `command`, `args`, `timeout_ms`, `refresh_interval_ms`. Do not combine with `env_key`, `experimental_bearer_token` or `requires_openai_auth`.
- Retries and streaming: `request_max_retries`, `stream_max_retries`, `stream_idle_timeout_ms`.

Template: `templates/codex-config.toml`.

### Capability flags

- `model_context_window` and `model_auto_compact_token_limit` for models Codex does not know.
- `model_supports_reasoning_summaries`, `model_reasoning_effort`, `model_reasoning_summary` (set summaries to `"none"` if the backend rejects them).
- `model_catalog_json` points at a custom model catalog file for richer metadata.

### Pitfalls

- 404 on `/v1/responses`: the endpoint is chat-only. Bridge in the gateway.
- `requires_openai_auth = true` tells Codex the provider uses OpenAI authentication; leave it unset for gateways that take their own key.
- `experimental_bearer_token` writes a key into the file; prefer `env_key`.
- Config reference moved to learn.chatgpt.com; older blog posts show `wire_api = "chat"`, which is no longer supported.

## OpenCode

### What it is and when to choose it

Open-source terminal agent built on the Vercel AI SDK, provider-agnostic. Good default for local and gateway models because model limits and capabilities are declared per model.

### Config location

Global `~/.config/opencode/opencode.json`, project `opencode.json` (merged), or a path in `OPENCODE_CONFIG`. Credentials added via `/connect` live in OpenCode's auth store; `opencode auth list` shows provider names only.

### Minimal config

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "gateway": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LLM gateway",
      "options": { "baseURL": "https://llm.example.com/v1", "apiKey": "{env:LITELLM_API_KEY}" },
      "models": {
        "coder": { "name": "Coder", "limit": { "context": 131072, "output": 16384 }, "tool_call": true }
      }
    }
  },
  "model": "gateway/coder"
}
```

- `@ai-sdk/openai-compatible` sends Chat Completions; `@ai-sdk/openai` sends Responses. Pick by what the endpoint serves.
- `{env:NAME}` and `{file:path}` substitutions keep secrets out of the file.

Template: `templates/opencode.json`.

### Capability flags

Per model: `limit.context`, `limit.input`, `limit.output`, `tool_call`, `reasoning`, `attachment`, `modalities.input` / `modalities.output` (`text`, `audio`, `image`, `video`, `pdf`), `interleaved.field` for reasoning content.

### Pitfalls

- Image paste silently does nothing until `attachment: true` and `modalities.input` includes `image`.
- Without `limit.context` OpenCode cannot compact on time.
- Through LiteLLM, OpenCode may send a `reasoningSummary` parameter that chat backends reject; drop it in the gateway (`additional_drop_params`).

## Aider

### What it is and when to choose it

Pair-programming CLI that edits files in a git repo via diff formats. Speaks Chat Completions through the LiteLLM client library. Model names need a provider prefix: `openai/<alias>` for any OpenAI-compatible endpoint.

### Config location

`.aider.conf.yml` in home, git root or current directory (later wins); `.env` for keys (`--env-file`); `.aider.model.settings.yml` for behaviour; `.aider.model.metadata.json` for context and cost.

### Minimal config

```bash
export OPENAI_API_BASE="https://llm.example.com/v1"
export OPENAI_API_KEY="$LITELLM_API_KEY"
aider --model openai/coder
```

Or in `.aider.conf.yml`: `model: openai/coder`, `openai-api-base: https://llm.example.com/v1`. Keep `openai-api-key` out of the YAML; use the env var or `.env`.

Template: `templates/aider.conf.yml`, `templates/aider.model.metadata.json`.

### Capability flags

- `.aider.model.metadata.json`: `max_input_tokens`, `max_output_tokens`, `input_cost_per_token`, `output_cost_per_token`, `litellm_provider` (`openai`), `mode` (`chat`). Key the entry by the full `openai/<alias>` name.
- `.aider.model.settings.yml`: `edit_format` (`diff`, `whole`, ...), `weak_model_name`, `editor_model_name`, `use_temperature`, `streaming`, `reasoning_tag`, `extra_params` (extra body or headers), `accepts_settings`.
- `--weak-model` for commit messages and summaries; `--editor-model` for architect mode.

### Pitfalls

- "Unknown context window" warnings mean no metadata entry; add one rather than `--no-show-model-warnings`.
- Weak models fail `diff` edit formats; use `whole` for small local models.
- Models that reject `temperature` (some reasoning models) need `use_temperature: false`.

## Official links

- Claude Code LLM gateway: https://code.claude.com/docs/en/llm-gateway
- Claude Code connect to a gateway: https://code.claude.com/docs/en/llm-gateway-connect
- Claude Code gateway protocol: https://code.claude.com/docs/en/llm-gateway-protocol
- Claude Code env vars: https://code.claude.com/docs/en/env-vars
- Claude Code model configuration: https://code.claude.com/docs/en/model-config
- Codex advanced config: https://learn.chatgpt.com/docs/config-file/config-advanced
- Codex config reference: https://learn.chatgpt.com/docs/config-file/config-reference
- Codex releases: https://github.com/openai/codex/releases
- OpenCode providers: https://opencode.ai/docs/providers/
- OpenCode models: https://opencode.ai/docs/models/
- OpenCode config: https://opencode.ai/docs/config/
- Aider OpenAI-compatible APIs: https://aider.chat/docs/llms/openai-compat.html
- Aider advanced model settings: https://aider.chat/docs/config/adv-model-settings.html
- Aider YAML config: https://aider.chat/docs/config/aider_conf.html
