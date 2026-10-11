# Codex CLI: compatibility with non-OpenAI Responses backends

> Verified against Codex CLI rust-v0.162.1 (docs: config-reference, config-advanced; GitHub issues checked 2026-10-11), 2026-10-11

Codex needs a faithful `/v1/responses`: streaming server-sent events, function-call items and reasoning items. Self-hosted engines implement a subset. Failures usually show up as a `400`, as tool calls that never run, or as silently missing features.

## Required endpoint behavior

- `POST /v1/responses` with `stream: true`, returning the standard event stream.
- Function tools (shell, apply_patch, plan, MCP) as `tools` entries, tool results as `function_call_output` items, in a multi-turn `input` array. Whether Codex ever relies on server-side state (`previous_response_id`) was not verified; stateless engines such as Ollama are the baseline to test against.
- `instructions`, `reasoning.effort` and `max_output_tokens` accepted or ignored, not rejected.
- Probe all of it with `scripts/check-endpoint.sh` (plain, stream, tool call).

Chat-only engines: use LiteLLM's bridge (`combos/litellm-responses-bridge.md`).

## Engine notes

| Engine     | Responses support                                                                                       | Watch for                                                                                                  |
| ---------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| vLLM       | `/v1/responses` (also GET and cancel)                                                                   | `--enable-auto-tool-choice --tool-call-parser <name>`; reasoning in `reasoning` (not `reasoning_content`). |
| llama.cpp  | `/v1/responses`                                                                                         | `--jinja` and a template with tools; MCP namespace issue below.                                            |
| Ollama     | `/v1/responses`, stateless: streaming, `tools`, `instructions`, `max_output_tokens`, `reasoning.effort` | No `previous_response_id`; no `tool_choice` on `/v1/chat/completions` or `/v1/messages`.                   |
| llama-swap | proxies `/v1/responses` to the model process                                                            | Behaviour is the backend's; cold swap needs longer idle timeouts.                                          |
| LiteLLM    | bridges to chat completions                                                                             | `use_chat_completions_api: true` on the deployment (see combo).                                            |

## Tool calling

- Tool calls only work if the engine parses the model's native tool format into `function_call` items. Prose or raw XML in the answer means a missing parser or template (skill `tool-calling-parsers`).
- Open issues at write time involving custom Responses providers (GitHub, openai/codex): MCP tools wrapped as `type: "namespace"` that strict backends cannot unwrap, so MCP tools are unavailable on llama-server (#23186, #26977, #36942); tool calls from Qwen3.6 via Ollama not executed in the app (#51077). If MCP tools vanish on a local backend, test without MCP first, then check those issues for a flattening option.
- Invalid or truncated JSON arguments are a model-quality problem on small models; use a larger or coder-tuned model.

## History items non-OpenAI backends reject

- Compaction items: resuming or handing off a session that contains `compaction` items to a third-party Responses provider can fail with `item type "compaction" is not supported` (#45393). Start a fresh session when switching provider.
- Hosted-tool items: history containing `web_search_call` items can crash when switching to Ollama or another custom provider (#24612). Do not switch provider mid-session; start a new one.
- Assistant `id` and `status` fields dropped on resend broke multi-turn on some backends (#12669). Update Codex and the engine before debugging deeper.
- Context overflow is not recoverable by auto-compaction for local providers (#48870); see `models-and-limits.md`.

These are GitHub issue states at write time; check them before concluding a workaround is still needed.

## Web search and extras

`web_search` defaults to `cached`, an OpenAI-maintained index; with a self-hosted provider hosted search is not available. Set `web_search = "disabled"` to avoid the tool being offered, or provide search through MCP. Keep `supports_standalone_web_search` and `supports_websockets` off unless your endpoint implements them.

## Streaming

- Codex retries dropped streams `stream_max_retries` times (default 5) and aborts after `stream_idle_timeout_ms` (default 300000) without data. A cold model load or long prefill can exceed that: raise it on the provider.
- Proxies must not buffer SSE (Caddy `flush_interval -1`, nginx `proxy_buffering off`). Cloudflare returns 524 when an origin is silent too long (skill `cloudflare-tunnel`).
- WebSocket transport is optional (`supports_websockets`); plain HTTP SSE is the default.

## Sandbox and approvals are separate

`approval_policy` and `sandbox_mode` (`read-only`, `workspace-write`, `danger-full-access`) are unrelated to the model endpoint. A weaker local model is a reason to keep approvals on; do not widen the sandbox to compensate for tool-call failures.
