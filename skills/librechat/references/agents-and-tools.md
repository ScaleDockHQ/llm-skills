# LibreChat: tool calling, agents and MCP on self-hosted models

> Verified against LibreChat v0.8.8 / config v1.3.17 (docs: features/agents, librechat_yaml/object_structure/agents, mcp_servers, custom_endpoint), vLLM v0.31.0 docs (features/tool_calling), llama.cpp server README, 2026-10-11

Chat works on any endpoint; agents and tools need a model and engine that return real OpenAI `tool_calls` (or Anthropic `tool_use` blocks on the Messages path). LibreChat does not translate prompt-based pseudo tools.

## Prove tool calls at the server first

`scripts/check-endpoint.sh` sends a `get_weather` tool and prints `tool_call: get_weather` or `none`. If it prints `none`, fix the engine before touching LibreChat.

| Engine              | What enables tool calls                                                                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| vLLM                | Start with `--enable-auto-tool-choice` (mandatory) and `--tool-call-parser <name>` matching the model family; some models also need `--chat-template`. Use the `tool-calling-parsers` skill to choose. |
| llama.cpp           | `--jinja` (enabled by default in current builds), and a chat template that supports tools; override with `--chat-template-file`, worst case `--chat-template chatml`.                                  |
| Ollama              | The model must advertise tool support; the OpenAI route at `/v1` accepts `tools`. Check with `ollama show <model>` (capabilities) before blaming LibreChat.                                            |
| LiteLLM, llama-swap | Pass-through. Tool support comes from the backend model; LiteLLM may drop unsupported params only if `drop_params` is set.                                                                             |

## Agents on a custom endpoint

Agents are LibreChat's tool-using assistants (Agent Builder: instructions, tools, files, MCP servers, subagents, skills). An agent can use any configured provider or custom endpoint as its model; choose your custom endpoint in the builder. Defaults for the `agents` endpoint (including which capabilities are on) live under `endpoints.agents` in `librechat.yaml`; opt-in capabilities such as `programmatic_tools`, `stateful_code_sessions`, `run_in_background` and `tool_intents` are off unless listed. Several of these (code workspaces, programmatic tool calling) need extra services and are marked experimental upstream.

Practical rules:

- Give agents a model with solid tool calling; small quantized models loop or emit malformed arguments.
- Each extra enabled tool adds schema tokens to every request; keep context windows honest in `tokenConfig`.
- If tool results show up but the model never answers, the server probably stops after a tool turn: check the engine's `finish_reason` and parser logs.
- Tool approval can be required deployment-wide; paused runs resume after a decision.

## Reasoning models

Thinking models differ in how they return reasoning. Per endpoint, `customParams`:

```yaml
customParams:
  reasoningFormat: reasoning_object # reasoning_effort | reasoning_object | disabled
  reasoningKey: reasoning_content # response field that carries reasoning text
  includeReasoningContent: true # replay reasoning_content during tool-call turns (providers that require it)
  # includeReasoningHistory: true     # also rebuild it from stored history on later turns (some Kimi/MiMo-style gateways)
```

`reasoning_effort` sends the legacy parameter, `reasoning_object` sends `{effort, summary}`, `disabled` suppresses both even when a user picks a level. If reasoning appears inline as `<think>` text instead, configure the engine's reasoning parser rather than LibreChat.

## MCP servers

Configured under `mcpServers` in `librechat.yaml`, one entry per server, with `type` `stdio`, `sse`, `streamable-http` or `websocket`:

```yaml
mcpServers:
  docs:
    type: streamable-http
    url: https://mcp.example.com/mcp
    headers:
      Authorization: "${MCP_DOCS_TOKEN}" # keep the token in .env
    requiresOAuth: false # static header auth: skip OAuth auto-detection
    startup: true
  files:
    type: stdio
    command: npx
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/data/share"]
```

`stdio` and other process-backed servers must be in the file; the admin API rejects them. Run only MCP servers you trust: they execute with the container's permissions, and a stdio server sees only what you mount. Set `startup: false` to skip connecting at boot. Model-side tool calling is still required for the model to use MCP tools.

## Context size and cost

`/v1/models` carries no context window or price. Declare them per model in `tokenConfig` (`prompt`, `completion`, `context`; `cacheRead`/`cacheWrite` optional, per million tokens). Without it, context meters and trimming fall back to defaults and can truncate early or overflow.

## Official links

- Agents: https://www.librechat.ai/docs/features/agents
- Agents endpoint config: https://www.librechat.ai/docs/configuration/librechat_yaml/object_structure/agents
- MCP servers config: https://www.librechat.ai/docs/configuration/librechat_yaml/object_structure/mcp_servers
- vLLM tool calling: https://docs.vllm.ai/en/latest/features/tool_calling/
- llama.cpp server: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
