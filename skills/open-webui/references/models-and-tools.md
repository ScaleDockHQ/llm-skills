# Open WebUI: capabilities, tool calling, params, streaming and reasoning

> Verified against Open WebUI v0.12.0 (docs: features/workspace/models, plugin/tools, reference/env-configuration, troubleshooting/connection-error), 2026-10-11

## Declare what the model can do

Open WebUI cannot learn context size, vision or tool support from `/v1/models`. Set them per model: Settings, Admin, Models (or Workspace, Models), edit the model.

- **Capabilities**: Vision, File Upload, File Context, Web Search, Code Interpreter, Builtin Tools, Usage (requests `stream_options.include_usage` so token counts show), Citations. A capability the backend lacks will fail at request time.
- **Advanced Params**: temperature, max tokens, stop, seed, reasoning effort and others, passed through as standard OpenAI parameters. The backend enforces context length; Open WebUI has no context field to set.
- **Baselines for all models**: `DEFAULT_MODEL_METADATA` (JSON, for example `{"capabilities":{"vision":true}}`) and `DEFAULT_MODEL_PARAMS` (JSON, for example `{"temperature":0.7}`), read at startup.
- Name collisions: use the connection's prefix id when two connections serve the same model name.

## Tool calling

- **Native** function calling has been the default since v0.10.0: Open WebUI sends `tools`/`tool_choice` and the model's real function calling is used. The docs now describe **Legacy** (prompt-based, formerly "Default") as unsupported and not actioned in bug reports; builtin tools (memory, notes, knowledge, web search, code interpreter) are Native-only. Earlier guidance to flip weak models to Legacy is outdated; fix the model or engine instead.
- The engine must parse tools: vLLM `--enable-auto-tool-choice --tool-call-parser <name>`, llama.cpp `--jinja` with a tool-capable template, Ollama with a tool-capable model. See the engine skills.
- In Native mode, model-attached knowledge bases are not auto-injected; the model must call the retrieval tool.
- Tool servers (OpenAPI, MCP over HTTP, MCPO) are called by the Open WebUI backend, so their URLs must be reachable from the container, not the browser (`docker-networking.md`).

### Blank replies when a model uses a tool

Symptom: the assistant message is empty, no error, output tokens still billed, worse with builtin tools, intermittent. Cause: the endpoint streams tool calls without the `index` field that the OpenAI streaming schema puts on each tool call delta, so the call is dropped. Known for Google's OpenAI compatibility layer; any off-schema endpoint can do it. Options: put a gateway in front that normalises (LiteLLM), use a pipe, or turn off builtin tools for that model. Test an endpoint with a streamed tool-call request and check that each delta carries `index`.

## Streaming and proxies

- Streaming is SSE over the backend. Reverse proxies must not buffer it: nginx needs `proxy_buffering off; proxy_cache off;`, `proxy_http_version 1.1` and Upgrade/Connection headers for WebSocket; Caddy handles SSE by default. Garbled markdown (`##`, `**` visible) that disappears with streaming off is proxy buffering.
- `ENABLE_ORJSON=True` on v0.11.0 could drop text containing U+2028, U+2029 or U+0085; check it if replies lose pieces and the proxy is fine.
- Long first-token latency on swap proxies (llama-swap loading a model) is normal; raise `AIOHTTP_CLIENT_TIMEOUT` rather than assuming failure (default is no timeout; a non-integer value falls back to 300).

## Reasoning

Reasoning models that return `reasoning_content` display it separately; models that inline `<think>` in content show raw tags unless the server parses reasoning (vLLM `--reasoning-parser`, llama.cpp reasoning options). With the llama.cpp Provider setting, stored reasoning is replayed to the server in `reasoning_content`.

## Embeddings and RAG

RAG uses an embedding engine (`RAG_EMBEDDING_ENGINE` set to `ollama`, `openai` or `azure_openai`, or the bundled local models in the standard image). With `:slim` you must provide an external embedding engine and, for vectors, PostgreSQL with pgvector. An OpenAI-compatible connection must serve `/v1/embeddings` to be used for it.

## Verify

1. Select the model; send "hello"; text streams in.
2. Enable a tool or builtin tool; ask something that needs it; the call completes and the reply is non-empty.
3. With Usage on, token counts appear under the reply.

## Official links

- Models workspace: https://docs.openwebui.com/features/workspace/models
- Tools and Native vs Legacy: https://docs.openwebui.com/features/extensibility/plugin/tools
- Connection errors, blank replies and streaming: https://docs.openwebui.com/troubleshooting/connection-error
- Environment configuration: https://docs.openwebui.com/reference/env-configuration
