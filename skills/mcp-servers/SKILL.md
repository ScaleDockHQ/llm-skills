---
name: mcp-servers
description: Connect a self-hosted LLM stack to MCP tool servers such as vector stores (Qdrant, Chroma, Postgres/pgvector) and your own tools. Use for choosing stdio or streamable HTTP under MCP spec 2026-07-28, authenticating and hardening remote MCP servers, the LiteLLM MCP gateway, and why a self-hosted OpenAI-compatible model is reached by the host, not the MCP server.
license: MIT
compatibility: Any MCP host (Open WebUI, LiteLLM, desktop or IDE clients) plus Docker or uv for the servers, bash, curl and jq. Installing packages, starting servers, opening ports and enabling write tools needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# MCP servers for a self-hosted LLM stack

Wire vector stores and tools into your own models over the Model Context Protocol, with the right transport and authentication.

**Scope:** Narrow. How a self-hosted OpenAI-compatible model and vector store meet MCP tools; stdio vs streamable HTTP; auth; the Qdrant, Chroma and Postgres (pgvector) MCP servers. Not a tutorial for writing MCP servers.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Print no tokens or connection strings.

```bash
command -v uvx npx docker 2>/dev/null
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i -E 'mcp|qdrant|chroma|postgres|litellm' || true
curl -fsS http://127.0.0.1:4000/health/liveliness 2>/dev/null; echo
ss -ltnp 2>/dev/null | grep -E ':(4000|6333|8000|8001)\b' || true
```

## Mental model

- The **host** (chat UI, agent, LiteLLM) calls your model on `/v1/chat/completions` and calls MCP **tools**. An MCP server does not call your LLM. Server-initiated sampling is deprecated in spec 2026-07-28, so do not design around it.
- Embedding stays with your embedder (`text-embeddings-inference`, `infinity`) behind LiteLLM `/v1/embeddings`. Check which servers can use it (`references/servers.md`): `mcp-server-qdrant` only embeds with fastembed models, so a collection filled through TEI will not match its queries.

## Decision flow

1. Server and client on one machine, one user: **stdio**. The client launches the server and credentials come from the environment (the spec says stdio servers should not use the HTTP auth flow).
2. Shared, remote or containerized: **streamable HTTP** behind an authenticating proxy (`references/transports-auth.md`). HTTP+SSE is deprecated; use it only if a server offers nothing else.
3. Many clients and many servers: put the **LiteLLM MCP gateway** in front (`references/combos/llm-stack.md`).
4. Pick the server per store (`references/servers.md`): Qdrant, Chroma, or the generic Postgres server for pgvector. There is no official pgvector-specific MCP server.
5. Default to read-only tools. Enable write tools only when the agent must ingest.

## Rules

- **Ask before changing the system.** Installing packages, running servers, opening ports and enabling write tools need approval.
- **Secrets never touch output.** API keys and tokens go in `0600` env files or secret stores, not in client JSON, args or logs.
- **stdio servers run with your user's rights.** Review the package, pin its version, and pass only the env it needs.
- **Remote means authenticated.** Bind to loopback by default, validate `Origin`, require a bearer token or OAuth at the proxy, add TLS off-box.
- **Tool output is untrusted input** to the model; a poisoned document can carry prompt injection. Keep tools least-privilege and read-only where possible.
- **Check maintenance** before adopting a server (`references/servers.md` has dates); the Chroma server has seen no commits for a year at the check date.
- **Verify upstream.** Spec revision, flags and defaults come from sources read on the writing date.

## Workflows

- [ ] Choose transport and auth -> `references/transports-auth.md`
- [ ] Pick and configure the store's server -> `references/servers.md`, `templates/`
- [ ] Route through LiteLLM or Open WebUI -> `references/combos/llm-stack.md`
- [ ] Harden, update, tear down -> `references/operations.md`
- [ ] Debug -> `references/troubleshooting.md`
- [ ] Verify: the host lists the tools, a read-only query returns a known document, an unauthenticated HTTP request is rejected, and no secret appears in configs or logs.

## Reference index

- `references/transports-auth.md`: spec 2026-07-28 transports and authorization, what changed.
- `references/servers.md`: Qdrant, Chroma and Postgres MCP servers, env, caveats.
- `references/operations.md`: hardening, updating, teardown.
- `references/troubleshooting.md`: symptom to fix.
- `references/combos/llm-stack.md`: LiteLLM `/v1/embeddings`, LiteLLM MCP gateway, llama-swap, Open WebUI.

## Companion skills

- `qdrant`, `chroma`, `pgvector`: the stores. Install: `npx skills add ScaleDockHQ/llms-skills --skill qdrant`.
- `litellm`: gateway for models and MCP. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `open-webui`: chat host with MCP tool support. Install: `npx skills add ScaleDockHQ/llms-skills --skill open-webui`.
- `text-embeddings-inference`: embedder. Install: `npx skills add ScaleDockHQ/llms-skills --skill text-embeddings-inference`.
