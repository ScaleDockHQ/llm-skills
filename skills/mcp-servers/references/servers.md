# Store servers

> Verified against MCP spec 2026-07-28, mcp-server-qdrant v0.8.1, chroma-mcp v0.2.6, postgres-mcp v0.3.0, LiteLLM v1.105.0, 2026-10-11

Maintenance at the check date (2026-10-11):

| Server                   | Latest release      | Last push  | Archived   |
| ------------------------ | ------------------- | ---------- | ---------- |
| qdrant/mcp-server-qdrant | v0.8.1 (2025-12-10) | 2026-09-04 | no         |
| chroma-core/chroma-mcp   | v0.2.6 (2025-08-14) | 2025-09-17 | no (stale) |
| crystaldba/postgres-mcp  | v0.3.0 (2025-05-16) | 2026-08-17 | no         |

None of the three README pages state support for the 2026-07-28 revision; test with your host.

## Qdrant (`mcp-server-qdrant`)

Tools: `qdrant-store` and `qdrant-find`. Configured by env: `QDRANT_URL` (or `QDRANT_LOCAL_PATH`, not both), `QDRANT_API_KEY`, `COLLECTION_NAME`, `EMBEDDING_PROVIDER` (only `fastembed`), `EMBEDDING_MODEL` (default `sentence-transformers/all-MiniLM-L6-v2`), `QDRANT_SEARCH_LIMIT` (10), `QDRANT_READ_ONLY` (disables `qdrant-store`). Transports via `--transport`: `stdio` (default), `sse`, `streamable-http`; host `FASTMCP_SERVER_HOST` (default 127.0.0.1) and port `FASTMCP_SERVER_PORT` (8000). The README's Docker example sets the host to 0.0.0.0, which exposes it: publish only on loopback or behind the proxy.

Important: embeddings are computed inside the MCP server with fastembed, not through your LiteLLM or TEI. A collection written by your own pipeline will not match unless it uses the same fastembed model and vector name. Either let the MCP server own ingestion, or use the Qdrant REST API from your own tools.

```bash
QDRANT_URL=http://127.0.0.1:6333 COLLECTION_NAME=docs QDRANT_READ_ONLY=true uvx mcp-server-qdrant
```

(`QDRANT_API_KEY` is read from the environment; load it from your 0600 file.)

## Chroma (`chroma-mcp`)

Tools: `chroma_list_collections`, `chroma_create_collection`, `chroma_peek_collection`, `chroma_get_collection_info`, `chroma_get_collection_count`, `chroma_modify_collection`, `chroma_delete_collection`, `chroma_add_documents`, `chroma_query_documents`, `chroma_get_documents`, `chroma_update_documents`, `chroma_delete_documents`. Client types (`--client-type` or `CHROMA_CLIENT_TYPE`): ephemeral, persistent (`--data-dir`), http (`--host`, `--port`, `--ssl`), cloud. Embedding functions listed: default, cohere, openai, jina, voyageai, roboflow; API keys via `CHROMA_<NAME>_API_KEY`. The README does not document a custom OpenAI base URL, so pointing it at LiteLLM or TEI is unverified. It also exposes delete tools; there is no read-only flag in the README. Its `--custom-auth-credentials` targets legacy server auth that Chroma v1 removed, so the token proxy from the `chroma` skill will not work with it; run it against loopback or the internal network. The README documents stdio client configs only.

## Postgres and pgvector (`postgres-mcp`, "Postgres MCP Pro")

No official pgvector-specific server exists. `crystaldba/postgres-mcp` is a general Postgres server (env `DATABASE_URI`); `--access-mode=restricted` limits it to read-only transactions with an execution-time cap, `unrestricted` allows writes. Transports in its README: stdio and SSE (`--transport=sse`), no streamable HTTP, so keep it on stdio or on loopback/proxy. Because it runs SQL, pgvector operators like `<=>` work as ordinary SQL; that is not demonstrated in its README. Use a dedicated read-only database role (see the `pgvector` skill), not the owner, and the connection string from a secret.

## Choosing

Need semantic search over docs with the least glue: Qdrant server (accept fastembed). Already Chroma: chroma-mcp over stdio, local. SQL plus vectors in Postgres: Postgres MCP in restricted mode. If none fit, write a small server around your own embedder; use an official MCP SDK and implement the streamable HTTP rules.
