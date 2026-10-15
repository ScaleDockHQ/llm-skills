---
name: qdrant
description: Run Qdrant, the Rust vector database, next to a self-hosted LLM stack for RAG and semantic search. Use for qdrant/qdrant Docker, port 6333, collections, HNSW, quantization (scalar, binary, TurboQuant), memory tiers, API keys and JWT, snapshots, sizing RAM per million vectors, embeddings via LiteLLM or TEI. For Postgres use pgvector, for Chroma use chroma, for MCP exposure use mcp-servers.
license: MIT
compatibility: Linux, macOS or Windows with Docker (or a native binary), bash, curl and jq. Installing, starting containers, opening ports, deleting collections or volumes needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Qdrant

Run a single-node Qdrant with persistence, auth and sane memory settings beside your LLM and embedding servers, then feed it embeddings produced through LiteLLM.

**Scope:** Qdrant only: install, size, configure, secure, back up, update, troubleshoot, tear down. Embedding servers are `text-embeddings-inference` and `infinity`; the gateway is `litellm`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Do not print API keys.

```bash
command -v docker && docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i qdrant || true
curl -fsS http://127.0.0.1:6333/ 2>/dev/null | jq .            # version banner (needs api-key if enabled)
curl -fsS http://127.0.0.1:6333/readyz -o /dev/null -w 'readyz %{http_code}\n' 2>/dev/null
ss -ltnp 2>/dev/null | grep -E ':(6333|6334|6335)\b' || true
free -g 2>/dev/null | sed -n 1,2p; df -h . | tail -1
```

With an existing instance and key (read from your env file, never echoed): `curl -s -H "api-key: $QDRANT_API_KEY" localhost:6333/collections | jq '.result.collections[].name'`.

## Decision flow

1. Already running Postgres and under about 10M vectors: consider `pgvector` first (one less service).
2. Need filtering, hybrid sparse+dense, quantization and a purpose-built server: Qdrant single node.
3. Billion-scale or sharded: Qdrant cluster or `milvus`; cluster setup is outside this skill's depth, see upstream distributed docs.
4. Size RAM before choosing the box (`references/sizing.md`).
5. Open WebUI as the front end: `references/combos/llm-stack.md` has the `VECTOR_DB=qdrant` variables.
6. Agents calling Qdrant as a tool: install `mcp-servers`.

## Rules

- **Ask before changing the system.** Containers, ports, collection deletes, volume removal and config edits need approval and an undo path (snapshot first).
- **Secrets never touch output.** `QDRANT__SERVICE__API_KEY` lives in a `0600` env file. Never pass it with `-e KEY=value` on a shared shell, never echo it.
- **Auth defaults to off and binds to `0.0.0.0`.** Publish `127.0.0.1:6333:6333`, set an API key, and put TLS in front before anything off-host connects.
- **Port 6335 (cluster) is never exposed.** Internal traffic is not authenticated by default.
- **One embedding model per collection.** Vector size and distance are fixed at creation; a model change means a new collection and re-embedding.
- **Snapshot before upgrades and deletes.**
- **Verify upstream.** Defaults, memory tiers and flags come from docs read on the writing date; v1.19 introduced the `memory` parameter.

## Workflows

- [ ] Install and run -> `references/install.md`, `templates/docker-compose.yml`
- [ ] Size RAM and disk -> `references/sizing.md`
- [ ] Configure memory, quantization, HNSW -> `references/config.md`
- [ ] Create a collection and load data through LiteLLM embeddings -> `references/api.md`, `references/combos/llm-stack.md`
- [ ] Secure -> `references/security.md`
- [ ] Back up, update, tear down -> `references/updating.md`
- [ ] Debug -> `references/troubleshooting.md`
- [ ] Verify: `/readyz` is 200, an unauthenticated request returns 401/403, a test point round-trips, and RAM matches the estimate after indexing.

## Reference index

- `references/install.md`: image tags, Docker run, volumes, ports.
- `references/sizing.md`: RAM and disk formulas with a worked example.
- `references/config.md`: config file, env overrides, memory tiers, quantization, HNSW.
- `references/api.md`: REST calls: collections, upsert, query, snapshots, health.
- `references/security.md`: API keys, read-only key, JWT RBAC, TLS, network.
- `references/updating.md`: snapshots, upgrade, rollback, teardown.
- `references/troubleshooting.md`: symptom to fix.
- `references/combos/llm-stack.md`: LiteLLM `/v1/embeddings`, llama-swap, Open WebUI.

## Companion skills

- `text-embeddings-inference`, `infinity`: embedding servers. Install: `npx skills add ScaleDockHQ/llm-skills --skill text-embeddings-inference`.
- `litellm`: gateway for embeddings. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `pgvector`: the Postgres alternative. Install: `npx skills add ScaleDockHQ/llm-skills --skill pgvector`.
- `mcp-servers`: expose Qdrant to MCP tools. Install: `npx skills add ScaleDockHQ/llm-skills --skill mcp-servers`.
