# Troubleshooting LLM clients

> Verified against Claude Code v2.1.296, Codex CLI rust-v0.162.1, OpenCode v1.19.0, Aider v0.86.0, Continue v2.0.0-vscode, Cline v4.1.23, Kilo Code v7.8.8, Open WebUI v0.12.0, LobeHub v2.2.19 docs and Cursor help docs, 2026-10-11

## What it is and when to choose it

Symptom-first fixes for a client that cannot use an endpoint. Server-side causes (unsupported routes, rejected params, gateway timeouts) belong to the `llm-gateway` skill; this file tells you when to switch.

## Install

Nothing to install. The first step is always the same: reproduce with `curl` using the **same base URL, key and model name** the client uses. If curl fails, the client is not the problem.

```bash
B=https://llm.example.com      # what the client is configured with
M=coder                         # model name the client sends
# Chat Completions
curl -sS -o /dev/null -w '%{http_code}\n' "$B/v1/chat/completions" -H "Authorization: Bearer $LLM_API_KEY" \
  -H 'Content-Type: application/json' -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}"
# Responses
curl -sS -o /dev/null -w '%{http_code}\n' "$B/v1/responses" -H "Authorization: Bearer $LLM_API_KEY" \
  -H 'Content-Type: application/json' -d "{\"model\":\"$M\",\"input\":\"ping\"}"
# Anthropic Messages
curl -sS -o /dev/null -w '%{http_code}\n' "$B/v1/messages" -H "Authorization: Bearer $LLM_API_KEY" \
  -H 'anthropic-version: 2023-06-01' -H 'Content-Type: application/json' \
  -d "{\"model\":\"$M\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}"
```

Three status codes tell you which APIs the endpoint serves for that model.

## Minimal working config

Not applicable; see the per-client references.

## How it plugs into the stack

```text
client --(API: chat | responses | messages)--> [vendor cloud?] --> gateway --> engine or provider
```

Each arrow is a place to break: wrong API, unreachable network hop, gateway rejection, engine limit.

## Operating

Turn on client-side debug output while reproducing:

- Claude Code: `claude --debug` (or `--debug-file <path>`), `/status` for base URL and credential source.
- Codex CLI: `codex -c log_dir=./.codex-log` writes a plaintext `codex-tui.log` there.
- Aider: `--verbose`.
- OpenCode: `opencode --print-logs --log-level DEBUG`.
- Editors: the extension's Output panel; Continue also has a console view.
- Gateway log: the request path and model name actually received.

## Tuning knobs

Timeouts on the client side for slow local prefill: Claude Code `API_TIMEOUT_MS`, Codex `stream_idle_timeout_ms`, Continue `requestOptions.timeout`.

## Known pitfalls

| Symptom                                    | Likely cause                                                                               | Fix                                                                                                   |
| ------------------------------------------ | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| 404 on every request                       | Base URL missing or doubling `/v1`                                                         | OpenAI clients: end with `/v1`. Claude Code and Anthropic SDK: no `/v1`. AI SDK Anthropic: with `/v1` |
| 404 only from Codex or AI SDK `openai()`   | Endpoint has no `/v1/responses`                                                            | Bridge in the gateway (`llm-gateway`), or `openai.chat()` in AI SDK                                   |
| 404 only from Claude Code                  | Endpoint has no `/v1/messages`                                                             | Gateway with an Anthropic route                                                                       |
| Cursor: connection error with a local URL  | Requests come from Cursor's servers                                                        | Public HTTPS endpoint or tunnel, with a scoped key                                                    |
| Container UI: connection refused           | `localhost` is the container                                                               | `host.docker.internal` (+ `host-gateway` on Linux) or a shared network                                |
| 401 with a key that works in curl          | Wrong header (`x-api-key` vs Bearer), stale key in client store, IDE cannot read shell env | Match `ANTHROPIC_AUTH_TOKEN` vs `ANTHROPIC_API_KEY`; re-enter key; Continue: use `~/.continue/.env`   |
| Model list empty                           | Allowlist or virtual key restricts models; `/v1/models` unsupported                        | Add model IDs manually; check key's `models`                                                          |
| Model missing in Claude Code picker        | Discovery keeps only IDs containing `claude` or `anthropic`                                | `ANTHROPIC_CUSTOM_MODEL_OPTION` or name aliases accordingly                                           |
| New model not showing                      | Client caches the model list                                                               | Open WebUI: save Connections or restart; others: restart or refetch                                   |
| Session overflows or truncates early       | Client does not know the context window                                                    | Declare it (`capabilities.md`)                                                                        |
| Claude Code never auto-compacts, then 400s | Gateway rewrote the context error                                                          | `/compact`, set `CLAUDE_CODE_MAX_CONTEXT_TOKENS` / `CLAUDE_CODE_AUTO_COMPACT_WINDOW`                  |
| Chat works, agent never edits files        | Tools not offered or model ignores tool schema                                             | Declare tool support; Open WebUI Native mode; test tool call with curl                                |
| 400 "unsupported parameter"                | Client sends fields the backend rejects (reasoning, betas, `reasoningSummary`)             | `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`, or drop params in the gateway                             |
| Images ignored                             | Vision not declared or backend not multimodal                                              | Declare vision; confirm with an image request in curl                                                 |
| Stream stalls then times out               | Long prefill on local engines                                                              | Raise client timeout; check gateway `stream_timeout`                                                  |
| Reasoning text shows up as answer          | Engine puts `<think>` in content                                                           | Configure the client's reasoning tag or the engine's reasoning parser                                 |

## Official links

- Claude Code gateway troubleshooting: https://code.claude.com/docs/en/llm-gateway-connect
- Codex advanced config: https://learn.chatgpt.com/docs/config-file/config-advanced
- OpenCode troubleshooting (providers): https://opencode.ai/docs/providers/
- Continue FAQ: https://docs.continue.dev/faqs
- Open WebUI connection errors: https://docs.openwebui.com/troubleshooting/connection-error
- Cursor bring your own API key: https://cursor.com/help/models-and-usage/api-keys
