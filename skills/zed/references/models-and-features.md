# Zed: models, capabilities, tools, reasoning and streaming

> Verified against Zed v1.23.2 (docs: ai/agent-settings, ai/use-api-access, ai/tool-permissions, ai/zed-agent), 2026-10-11

## What Zed needs to know about a model

For generic providers Zed cannot infer much from `/v1/models` (ids only), so you declare it:

| Need           | Setting (per model entry)                                                                                             | Symptom when wrong                              |
| -------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| Context window | `max_tokens`                                                                                                          | Early truncation or "context length exceeded"   |
| Output cap     | `max_output_tokens` (and `max_completion_tokens` on built-ins)                                                        | Cut-off answers or 400 on too large max tokens  |
| Tool calling   | `capabilities.tools` (OpenAI/Anthropic-compatible), `supports_tools` (built-in providers)                             | Agent chats but never edits files or runs tools |
| Images         | `capabilities.images` / `supports_images`                                                                             | Image paste ignored or rejected                 |
| Thinking       | `reasoning_effort` (OpenAI-compatible), `mode` with `budget_tokens` (Anthropic), `supports_thinking` (Ollama, Mantle) | No thinking UI, or errors about unknown field   |

Keep `max_tokens` at or below the context the engine was launched with, and at or below the gateway's `max_input_tokens` if one is set. Leave 5 to 10 percent headroom for tool schemas.

## Tool calling

- Defaults assume tools work (`tools: true`). If the engine is not configured for tool parsing, the model prints JSON as text or the server returns 400. Fix it at the engine: vLLM needs `--enable-auto-tool-choice --tool-call-parser <name>`; llama.cpp needs `--jinja` and a template with tool support; Ollama needs a tool-capable model. See the engine skills.
- Set `parallel_tool_calls: true` only if the server and model handle several calls per turn; the default is off.
- `tool_override` (Anthropic-style entries) names another model to handle tool calls when the main one cannot.
- Tool approval is separate from tool support: `agent.tool_permissions.default` (`allow`, `confirm`, `deny`) from Zed v0.224.0, with per-tool rules under `agent.tool_permissions.tools`. Earlier releases used `agent.always_allow_tool_actions`.
- Agent profiles (`agent-profiles`) choose which tools a thread may see. A model that "has no tools" may just be on a profile that excludes them.

## Reasoning and thinking tokens

- OpenAI-compatible: set `reasoning_effort` to a non-`none` level to enable thinking in the Agent Panel; `none` forces it off. Servers that return reasoning in a `reasoning_content` field and want it echoed back need `capabilities.interleaved_reasoning: true`.
- Models that inline `<think>...</think>` in content with no separate field show raw tags. Fix on the server (a reasoning parser such as vLLM `--reasoning-parser`, or llama.cpp reasoning-format options) so reasoning arrives in its own field.
- Anthropic-compatible: `mode: {"type":"thinking","budget_tokens":N}` on the model entry; the gateway must pass thinking blocks through.

## Streaming

- Zed streams responses. Proxies that buffer server-sent events (nginx without `proxy_buffering off`, some CDNs) make answers appear all at once or stall; see `llm-gateway` and `caddy` skills for proxy settings.
- If an endpoint rejects `stream_options` or tool streaming, test with `curl -N` and `"stream":true` to see the exact failure before changing Zed settings.

## Which model does what

```jsonc
{
  "agent": {
    "default_model": { "provider": "my-gateway", "model": "coder" },
    "inline_assistant_model": { "provider": "my-gateway", "model": "fast" },
    "commit_message_model": { "provider": "my-gateway", "model": "fast" },
    "thread_summary_model": { "provider": "my-gateway", "model": "fast" },
    "compaction_model": { "provider": "my-gateway", "model": "coder" },
  },
}
```

- The `provider` value for built-in providers is their id (`anthropic`, `openai`, `ollama`, `openrouter`). For a custom `openai_compatible` or `anthropic_compatible` provider the docs do not spell out the id; select the model once in the UI and copy what Zed writes to `settings.json`.
- Cheap, fast models suit commit messages and summaries; keep the strongest tool-capable model for `default_model`.
- Automatic compaction runs at 90 percent of the context window by default (`agent.auto_compact.enabled`, `threshold`: `"90%"`, a positive token count, or a negative remaining-token count). `/compact` does it on demand. The compaction model should have at least the primary model's context.

## Verify

1. Select the model; ask "read the README and list three TODOs". A tool-using answer shows file reads in the thread.
2. Ask for a one-line edit and approve it; confirm the diff applies.
3. For thinking models, confirm a collapsed reasoning block appears and the final answer is not empty.

## Official links

- Agent settings: https://zed.dev/docs/ai/agent-settings
- Tool permissions: https://zed.dev/docs/ai/tool-permissions
- Agent profiles: https://zed.dev/docs/ai/agent-profiles
- Use API Access: https://zed.dev/docs/ai/use-api-access
