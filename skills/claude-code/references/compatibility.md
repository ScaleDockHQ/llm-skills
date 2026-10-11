# Claude Code: compatibility with non-Anthropic backends

> Verified against Claude Code v2.1.296 (docs: llm-gateway-protocol, llm-gateway-connect, env-vars), 2026-10-11

Behind `ANTHROPIC_BASE_URL`, Claude Code treats the endpoint as the Claude API and sends the full current feature set, including beta headers and body fields, except a few direct-connection defaults. Anything the backend rejects surfaces as a `400`. The set grows with each release, so re-test after upgrades.

## Switches, in the order to try

| Symptom                                                                                                                                                 | Switch                                                                                                                                                                                                                                    |
| ------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `400` naming `anthropic-beta`, `context_management`, `Extra inputs are not permitted`, tool fields (`strict`, `defer_loading`, `eager_input_streaming`) | `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`. It strips pre-release beta headers and paired fields, MCP tool search, `output_config.format` (v2.1.287+) and `task_budget`. It keeps effort, adaptive thinking and extended-context headers. |
| `400` naming `thinking` or `adaptive` (`Input tag 'adaptive' found`)                                                                                    | Upgrade the backend; or on Opus 4.6 / Sonnet 4.6 only `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`. For other IDs use `CLAUDE_CODE_DISABLE_THINKING=1`, which omits the `thinking` parameter (the model may still think).                    |
| `400` naming `output_config` / effort                                                                                                                   | Claude Code retries without effort when the message names `output_config.effort` with `Extra inputs are not permitted`; otherwise drop the field in the gateway.                                                                          |
| Backend needs a field Claude Code does not send                                                                                                         | `CLAUDE_CODE_EXTRA_BODY='{"key":value}'` merges a JSON object into every request body. `ANTHROPIC_BETAS` adds beta header values.                                                                                                         |
| Unrecognized tool type such as `advisor_20260301` (v2.1.275 only)                                                                                       | Update to v2.1.276+, or `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1`.                                                                                                                                                                             |
| `400` rejecting a tool `pattern` with `\p{...}` (v2.1.265 to v2.1.267)                                                                                  | Update to v2.1.268+.                                                                                                                                                                                                                      |
| MCP tool search off                                                                                                                                     | Default off behind a non-first-party base URL. `ENABLE_TOOL_SEARCH=true` only if the endpoint forwards `tool_reference` blocks and the beta header.                                                                                       |
| Large file writes seem to hang                                                                                                                          | Fine-grained tool streaming is off behind a custom base URL; `CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING=1` if the endpoint streams partial tool JSON.                                                                                |

Claude Code self-heals some rejections (retries without `thinking`, mid-conversation system messages, thinking signatures, advisor entry, effort). It matches on the upstream's error wording, so a gateway must forward error bodies unmodified. It does not retry context-management or tool-schema rejections.

## Tool calling

- Claude Code relies on native Anthropic `tool_use` / `tool_result` blocks for every file edit and shell command. Chat has no value without them; a model or parser that emits tool calls as prose breaks edits.
- vLLM: `--enable-auto-tool-choice --tool-call-parser <name>` (Qwen3-Coder uses `qwen3_xml`, Hermes-style models `hermes`; see skill `tool-calling-parsers`). llama.cpp: `--jinja` and a chat template with a tool section; log line `Chat format: Generic` means no tool support. Ollama: pick a model with the `tools` capability (`ollama show <m>`).
- Ollama's `/v1/messages` does not support `tool_choice`, so a forced or forbidden tool cannot be enforced there.
- Parallel tool calls and strict schema validation depend on the model and parser; test with a multi-file edit, not a one-line change.
- A model that loops on the same tool call or invents tool names is a model-quality problem, not a Claude Code setting. Try a coder-tuned model with a larger context.

## Thinking and reasoning output

Claude Code requests adaptive reasoning for models it does not recognize. Backends that return reasoning in another shape (OpenAI-style `reasoning_content`, vLLM `reasoning`) must map it to Anthropic `thinking` blocks at `/v1/messages`; engines with a native Messages route and a reasoning parser do. If thinking text leaks into the answer, fix the engine's reasoning parser, not the client. The `bound to a different conversation` 400 means something rewrote `system`, `tools` or earlier messages between turns; Claude Code removes earlier thinking blocks and retries, but find the rewriting hop.

## Streaming

- Claude Code reads server-sent events as they arrive and expects the whole event sequence through `message_delta` and `message_stop`. A body that ends early is treated as a dropped connection; buffering proxies make it stall.
- It aborts when no bytes arrive within its streaming idle timeout; `ping` events are the only bytes during a long think or a cold model load. Keep `ping` events flowing through proxies; never buffer (Caddy `flush_interval -1`, nginx `proxy_buffering off`; Cloudflare returns 524 when the origin stays silent too long, see skill `cloudflare-tunnel`).
- Slow prefill or a model swap: raise `API_TIMEOUT_MS`.

## Caching, counting, headers

- `cache_control` markers are attached to system blocks and messages. Backends that ignore them just recompute (slow on long histories); gateways that flatten block-form `system` to a string defeat caching. Engines with prefix caching (vLLM, llama.cpp) cache by token prefix independently.
- `/v1/messages/count_tokens` is optional; absent means character-based estimates in `/context`.
- A WAF in front of the endpoint may block real requests (XML-ish tags and code look like XSS) while short curl tests pass: exempt `/v1/messages` from body inspection.
- TLS inspection or a private CA: `NODE_EXTRA_CA_CERTS=/path/ca.pem`.

## Honest limits

Anthropic does not support non-Claude models behind a gateway. Expect weaker edits, occasional malformed tool calls and features that silently do nothing (extended thinking budget, citations, PDF blocks, prompt cache TTLs). Use `claude --debug` and the endpoint's own logs side by side when diagnosing.
