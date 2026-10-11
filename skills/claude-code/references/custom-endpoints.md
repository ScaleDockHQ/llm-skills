# Claude Code: custom Anthropic-format endpoints

> Verified against Claude Code v2.1.296 (docs: llm-gateway, llm-gateway-connect, llm-gateway-protocol, env-vars), 2026-10-11

Claude Code speaks one wire format to a custom base URL: Anthropic Messages (`POST /v1/messages?beta=true`, optional `POST /v1/messages/count_tokens`). It does not send Chat Completions or Responses. Any server that implements Messages works; anything else needs a bridge.

## What to set

```bash
export ANTHROPIC_BASE_URL="http://HOST:PORT"       # root only; Claude Code adds /v1/messages
export ANTHROPIC_AUTH_TOKEN="$(cat ~/.config/llm/key)"   # Authorization: Bearer; read from a 0600 file
export ANTHROPIC_MODEL="local-coder"               # the name the endpoint serves
```

| Credential source        | Header sent                          | Use when                                                                        |
| ------------------------ | ------------------------------------ | ------------------------------------------------------------------------------- |
| `ANTHROPIC_AUTH_TOKEN`   | `Authorization: Bearer <value>`      | Endpoint or gateway checks a bearer token (default pick)                        |
| `ANTHROPIC_API_KEY`      | `x-api-key: <value>`                 | Endpoint checks `x-api-key`. First interactive use asks you to approve the key. |
| `apiKeyHelper` (setting) | both `Authorization` and `x-api-key` | Key rotates or comes from a vault or keychain                                   |

- No auth on the endpoint (typical Ollama): set `ANTHROPIC_AUTH_TOKEN` to any non-empty dummy such as `local`. Without any credential Claude Code shows its login screen. If an old `ANTHROPIC_API_KEY` is exported, unset it or set it to an empty string to avoid the auth-conflict warning.
- A gateway credential variable beats a saved claude.ai login; run `/logout` once to remove the login so only the gateway credential remains. Setting only `ANTHROPIC_BASE_URL` does not replace the subscription login.
- `apiKeyHelper` is a command printing only the key on stdout (on v2.1.227+ any banner makes it fail). Output is cached five minutes; change with `CLAUDE_CODE_API_KEY_HELPER_TTL_MS`. Example: `"apiKeyHelper": "~/bin/get-llm-key.sh"` where the script does `cat ~/.config/llm/key`, or on macOS `security find-generic-password -s local-llm -w`.
- Extra headers: `ANTHROPIC_CUSTOM_HEADERS` (`Name: Value`, newline separated; `\n` inside JSON settings), for example a tenant or routing header.
- Where to put values, in order of reach: shell export (one terminal) < `~/.claude/settings.json` `env` block (all projects, also background agents) < managed settings. A project `.claude/settings.json` is committed: no credential there. In an interactive session, an `env` block in a _project_ settings file applies only after the first-run wizard and trust prompt, so a login screen with a working curl means the credential sits in a place read too late.
- Remote Control, voice dictation, Slack and cloud sessions need a claude.ai identity and are unavailable or not routed through your endpoint while a gateway credential is active.

Templates: `templates/claude-code.env.example`, `templates/settings.json`.

## Per engine

Engine-side flags and versions belong to the engine skills; this table is what Claude Code needs from each.

| Endpoint                   | `ANTHROPIC_BASE_URL`     | Credential                                                                   | Notes                                                                                                                                                                                                                                                                        |
| -------------------------- | ------------------------ | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM (`vllm serve`)        | `http://HOST:PORT`       | `ANTHROPIC_AUTH_TOKEN` matching `--api-key`                                  | Serves `/v1/messages` and `/v1/messages/count_tokens`. Needs `--enable-auto-tool-choice --tool-call-parser <name>` for tools and a reasoning parser for thinking (skill `tool-calling-parsers`). `--api-key` guards `/v1` routes only. `--served-model-name` sets the alias. |
| llama.cpp (`llama-server`) | `http://HOST:PORT`       | `ANTHROPIC_API_KEY` if started with `--api-key`, else dummy                  | Serves `/v1/messages` and `/v1/messages/count_tokens`; Anthropic route expects `x-api-key`. Tools need `--jinja` (default on current builds) and a template with a tool section. Set `-c` large: agents need long context.                                                   |
| Ollama                     | `http://127.0.0.1:11434` | dummy token (`ollama`) locally                                               | `/v1/messages` supported: streaming, tools, thinking. Not supported: `tool_choice`, `count_tokens`, prompt caching, in-stream error events. Raise `OLLAMA_CONTEXT_LENGTH` (agents need 64k+). Direct Ollama Cloud: `https://ollama.com` with a bearer API key.               |
| llama-swap                 | `http://HOST:PORT`       | `apiKeys` entry via either header (it accepts Bearer, `x-api-key` and Basic) | Routes `/v1/messages` by the `model` field, loading the model on demand. First request after a swap is slow: raise `API_TIMEOUT_MS`. Model IDs and aliases must match config.                                                                                                |
| LiteLLM proxy              | `http://HOST:4000`       | virtual key via Bearer or `x-api-key`                                        | Unified `/v1/messages` for any backend, including chat-only engines. See `combos/litellm-gateway.md`.                                                                                                                                                                        |

Chat-only endpoint (no `/v1/messages`)? A request returns 404 or HTML. Put LiteLLM in front rather than hacking the client.

## Verify before opening Claude Code

```bash
scripts/check-endpoint.sh           # reads ANTHROPIC_BASE_URL, credential and ANTHROPIC_MODEL from the environment
```

It runs: `GET /v1/models`, a plain `POST /v1/messages`, a streamed one (checks `message_stop`), and a one-tool request (checks for a `tool_use` block). It prints HTTP status and short verdicts, never the key. Equivalent single probe (from the official docs; an "unknown model" error still proves URL and key work):

```bash
curl -sS -w '\n%{http_code}\n' -X POST "$ANTHROPIC_BASE_URL/v1/messages" \
  -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"'"$ANTHROPIC_MODEL"'","max_tokens":1,"messages":[{"role":"user","content":"."}]}'
```

A `401` means the credential is in the wrong variable or revoked: switch between `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_API_KEY`. In Claude Code, `/status` must show your base URL and the credential source; `claude --debug` writes `~/.claude/debug/<session-id>.txt` for request-level detail.

## Privacy and traffic

Model requests go to your endpoint. Claude Code still sends nonessential traffic (telemetry, update checks, release notes, error reporting) to Anthropic and other hosts, without your endpoint credential. For offline or egress-restricted hosts set `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`; it disables auto-update, so update by hand. The WebFetch tool's domain check still calls `api.anthropic.com`; `skipWebFetchPreflight: true` in settings turns it off. Fast mode checks also go direct and are unavailable behind a gateway unless skipped (`CLAUDE_CODE_SKIP_FAST_MODE_NETWORK_ERRORS=1`). `/v1/models` discovery and inference go only to your endpoint.

## Other formats

Claude Code can also speak Bedrock InvokeModel (`CLAUDE_CODE_USE_BEDROCK=1` with `ANTHROPIC_BEDROCK_BASE_URL`) and Vertex rawPredict (`CLAUDE_CODE_USE_VERTEX=1` with `ANTHROPIC_VERTEX_BASE_URL`) to a gateway. They apply to real Claude models on those clouds, not to self-hosted engines; use `ANTHROPIC_BASE_URL` for everything in this skill.
