# AnythingLLM: agents, tool calling and MCP

> Verified against AnythingLLM v1.17.0 (docs: agent/setup, agent-not-using-tools, agent/intelligent-tool-selection, mcp-compatibility/docker; source server/utils/agents/aibitat/providers and server/.env.example), 2026-10-11

`@agent` runs a workspace chat through an agent loop with skills (RAG search, web browsing, file tools, SQL, custom skills, MCP tools). It uses the Agent LLM, which defaults to the system LLM and can be set per workspace (workspace settings, agent configuration).

## Native tool calls vs prompt-based tools

Provider classes in the server decide how tools are used:

- **Native**: the provider sends OpenAI `tools` and reads `tool_calls`. This is the default for providers such as Generic OpenAI and LiteLLM, and for Ollama when the model reports tool capability (AnythingLLM asks Ollama for the model's capabilities).
- **Prompt-based ("UnTooled")**: tool definitions are put in the prompt and the model must emit JSON that AnythingLLM parses (it repairs slightly invalid JSON). Used when native calling is off or unsupported, and far less reliable on small or heavily quantized models.

Opt a provider out of native calls with `PROVIDER_DISABLE_NATIVE_TOOL_CALLING="generic-openai,litellm"` in `.env` (comma-separated provider tags, from `.env.example`). Use that when a server accepts `tools` but returns malformed calls; use the engine's parser when the model should be native.

Server-side prerequisites for native calls:

| Engine              | Needed                                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------------------------- |
| vLLM                | `--enable-auto-tool-choice --tool-call-parser <name>` (parser matching the model; see `tool-calling-parsers`). |
| llama.cpp           | `--jinja` and a tool-capable template (`--chat-template-file` if the model's own is not).                      |
| Ollama              | A model with tool capability; AnythingLLM's native Ollama provider checks it.                                  |
| LiteLLM, llama-swap | Pass-through to a backend that supports tools.                                                                 |

Prove it first: `scripts/check-endpoint.sh` prints `tool_call: get_weather` or `none`.

## When `@agent` does not use tools

Upstream's FAQ ("AI Agent not using tools"): it is almost always the model.

- You see a reply but no "thought" lines: the model made up a tool call. Use a larger or less quantized model, and `/reset` the chat history.
- "I cannot call XYZ": the model refused (common for scraping). Pick a less restricted model.
- The model never detects tools: too many tools or too little context. Turn off unused skills (Settings, Agent Skills, or the Tools button in the chat prompt) and raise the context window setting.
- Trick from upstream: use a stronger cloud or larger model for agent calls only (workspace agent LLM) and a local model for plain chat.

Also check `*_MODEL_TOKEN_LIMIT`: with the 4096 default, tool schemas plus history do not fit.

## Intelligent Tool Selection

Enabled by default (Settings, Agent Skills, settings icon). When you have more tools than the **Max Tools** value, AnythingLLM adds only the tools relevant to the chat instead of all of them, saving prompt tokens. It adds a small overhead per chat. Turn it off if tool choice becomes erratic with a weak model.

## MCP servers (Docker)

Self-hosted only; tools are supported (resources, prompts and sampling are not). Config file: `plugins/anythingllm_mcp_servers.json` inside the storage directory (`$STORAGE_LOCATION/plugins/`), created when you open Agent Skills in the UI. Servers start when you open Agent Skills or invoke `@agent`, not at container start; `anythingllm.autoStart: false` on an entry stops auto start. Click Refresh in Agent Skills to reload after editing the file.

- `npx`, `uv`/`uvx`, `node` and `bash` exist in the image (Ubuntu jammy base).
- MCP servers run inside the container with its permissions and see what you mounted; never run MCP servers you do not trust.
- Give the container enough resources for the number of servers.
- Secrets for an MCP server go in its `env` entries in that JSON file; keep the storage directory private and never paste it.

## Agent flows and skills

Agent Flows are no-code multi-step agent routines; custom skills are JS plugins (`plugin.json` and `handler.js`). Both run with the same Agent LLM, so the same tool-call reliability rules apply.

## Verify

```bash
BASE=http://localhost:4000 MODEL=coder scripts/check-endpoint.sh      # tool_call: get_weather expected
docker logs anythingllm 2>&1 | grep -i -E 'agent|tool|mcp' | tail -20
```

In the UI: workspace chat, send `@agent list the documents in this workspace`; expect thought lines naming a skill.

## Official links

- Agent setup: https://docs.anythingllm.com/agent/setup
- Agent not using tools: https://docs.anythingllm.com/agent-not-using-tools
- Intelligent tool selection: https://docs.anythingllm.com/agent/intelligent-tool-selection
- MCP on Docker: https://docs.anythingllm.com/mcp-compatibility/docker
