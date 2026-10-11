# MCP beside LiteLLM, TEI, llama-swap and Open WebUI

> Verified against MCP spec 2026-07-28, mcp-server-qdrant v0.8.1, chroma-mcp v0.2.6, postgres-mcp v0.3.0, LiteLLM v1.105.0, 2026-10-11

## LiteLLM `/v1/embeddings`

MCP servers do not need your embedder, except where they embed themselves. The embedder for your own ingestion and retrieval stays behind LiteLLM:

```yaml
model_list:
  - model_name: embed-default
    litellm_params:
      model: openai/Qwen/Qwen3-Embedding-0.6B
      api_base: http://tei-embed:80/v1
      api_key: os.environ/TEI_API_KEY
    model_info:
      mode: embedding
```

## LiteLLM MCP gateway

LiteLLM's MCP Gateway lists and calls tools from registered servers (transports http for streamable HTTP, sse, and stdio) and offers REST `/mcp-rest/tools/list` and `/mcp-rest/tools/call`. In `config.yaml`:

```yaml
mcp_servers:
  qdrant_mcp:
    url: "http://mcp-qdrant:8000/mcp"
    transport: "http"
    description: "Read-only document search"
```

Stdio servers require `LITELLM_ENABLE_MCP_STDIO=true` on the proxy. Note the config default transport is `http`, while management API requests default to `sse`: set it explicitly. Confirm the endpoint path your server uses; `/mcp` is the usual streamable HTTP path, verify per server. See the `litellm` skill for gateway keys and access groups.

## llama-swap

Not applicable: llama-swap swaps model processes; MCP tools are called by the host, not by the model server. Tool-calling quality depends on the model you swap in.

## Open WebUI

Open WebUI connects to MCP servers as tool servers (admin-configured; `MCP_INITIALIZE_TIMEOUT` and tool-server TLS settings exist). It has its own RAG and vector settings, so use its skill for those rather than a vector MCP. Its tool calls go to your servers, so apply the proxy and read-only rules above.
