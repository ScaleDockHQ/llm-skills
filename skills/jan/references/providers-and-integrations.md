# Jan: providers, MCP and integrations

> Verified against Jan v0.8.6 (docs jan.ai/docs/desktop), 2026-10-11

Sources: jan.ai/docs/desktop remote-models (custom-endpoint, openai, anthropic, ...), mcp, integrations/claude-code, v0.7.6 changelog.

## Custom endpoint

Settings -> Model Providers -> Add Provider. Choose the API format (OpenAI-compatible default, or Anthropic-compatible), a name, the **Base URL** and an API key (required; any non-empty placeholder such as `sk-no-key` for local servers). Jan fetches `{base_url}/models`; if missing, add model IDs manually and set capabilities (tools, vision) per model; custom providers are not capability-detected.

| Server                                 | Format    | Base URL                    |
| -------------------------------------- | --------- | --------------------------- |
| vLLM                                   | OpenAI    | `http://localhost:8000/v1`  |
| Ollama                                 | OpenAI    | `http://localhost:11434/v1` |
| llama.cpp `llama-server`, LocalAI, TGI | OpenAI    | `http://localhost:8080/v1`  |
| LiteLLM                                | OpenAI    | `http://localhost:4000/v1`  |
| LiteLLM (Anthropic mode)               | Anthropic | `http://localhost:4000`     |

Picking the wrong format or omitting `/v1` gives 404 or failures. Built-in providers also exist for OpenAI, Anthropic, Google, Groq, Mistral, Azure, Hugging Face and OpenRouter.

## MCP

Jan is an MCP host (Settings -> MCP Servers). The model must support tool calling: cloud models with the tools capability, local models with tool calling enabled in model capabilities. Treat MCP servers as code with your permissions; install only trusted ones. v0.8.6 sends images returned by MCP tools to vision-capable models as images.

## Claude Code

Settings -> Integrations -> Claude Code: assign Jan models to the Large (Opus), Medium (Sonnet) and Small (Haiku) tiers, then Save & Enable. The `/v1/messages` endpoint is what Claude-compatible clients use.

## Jan as a backend for other apps

Point any OpenAI or Anthropic SDK at the Local API Server (see `local-api-server.md`). For gateways with budgets and routing put `litellm` in front.
