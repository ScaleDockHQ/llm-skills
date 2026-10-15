---
name: chroma
description: Run Chroma, the simple open-source vector database, beside a self-hosted LLM stack for RAG. Use for chromadb/chroma Docker, port 8000, the HttpClient, OpenAI-compatible embedding functions pointed at LiteLLM or TEI, RAM sizing (HNSW lives in memory), fronting it with an auth proxy because v1 has no built-in auth, backups and upgrades. Alternatives are qdrant, pgvector, milvus and weaviate.
license: MIT
compatibility: Linux, macOS or Windows with Docker and Docker Compose, bash, curl and jq. Installing, starting containers, opening ports and deleting volumes needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Chroma

Run a single-node Chroma server with persistence, a memory plan, an authenticating proxy in front and an embeddings route through your own OpenAI-compatible endpoint.

**Scope:** Chroma single-node server only: install, size, secure, embed through your own endpoint, back up, update, troubleshoot, tear down. Chroma Cloud and distributed deployments are out of scope. Embedders are `text-embeddings-inference` and `infinity`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Do not print tokens.

```bash
command -v docker && docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i chroma || true
curl -fsS http://127.0.0.1:8000/api/v2/heartbeat 2>/dev/null | jq .
curl -fsS http://127.0.0.1:8000/api/v2/version 2>/dev/null
ss -ltnp 2>/dev/null | grep -E ':8000\b' || true
free -g 2>/dev/null | sed -n 1,2p; df -h . | tail -1
```

## Decision flow

1. Prototype or small corpus (up to a few million vectors) and you want the least setup: Chroma server in Docker.
2. You need built-in API keys, RBAC or quantization: `qdrant` or `weaviate`. Already on Postgres: `pgvector`.
3. Size RAM first (`references/sizing.md`). The whole HNSW index must fit in memory.
4. Chroma v1 ships no authentication. Never publish port 8000; put the proxy from `references/security.md` in front.
5. Pick the embedder and set the embedding function per collection (`references/combos/llm-stack.md`).

## Rules

- **Ask before changing the system.** Containers, ports, collection deletes and volume removal need approval and a backup.
- **Secrets never touch output.** The proxy token lives in a `0600` env file, not in compose files or shell history.
- **No built-in auth in v1.** Upstream states v1.0.0 removed the auth providers; `CHROMA_SERVER_AUTHN_*` variables are historical. Bind Chroma to loopback or an internal Docker network and authenticate at a proxy.
- **Keep `allow_reset` false.** `CHROMA_ALLOW_RESET=true` lets a client wipe all data.
- **CORS defaults to `*`.** Restrict `cors_allow_origins` if browsers talk to it.
- **Fix the embedding model per collection.** A model or dimension change means a new collection and re-embedding; the default `l2` space may not suit your embedder.
- **Back up before upgrades** (`references/updating.md`).
- **Verify upstream.** Tags, paths and defaults come from docs read on the writing date (v1.5 line).

## Workflows

- [ ] Install and run -> `references/install.md`, `templates/docker-compose.yml`
- [ ] Size memory and disk -> `references/sizing.md`
- [ ] Secure (proxy, loopback, reset, CORS) -> `references/security.md`
- [ ] Embed through your endpoint, create a collection, query -> `references/api.md`, `references/combos/llm-stack.md`
- [ ] Back up, update, tear down -> `references/updating.md`
- [ ] Debug -> `references/troubleshooting.md`
- [ ] Verify: `/api/v2/heartbeat` answers, an unauthenticated request through the proxy gets 401, a test document is embedded and returned by a query, and RAM fits the plan.

## Reference index

- `references/install.md`: image, Docker run and Compose, config file, volumes.
- `references/sizing.md`: RAM and disk rules, batch sizes.
- `references/security.md`: no built-in auth, token proxy, reset, CORS.
- `references/api.md`: client, collections, embedding function, HNSW config.
- `references/updating.md`: backups, upgrade, teardown.
- `references/troubleshooting.md`: symptom to fix.
- `references/combos/llm-stack.md`: LiteLLM, llama-swap, Open WebUI.

## Companion skills

- `text-embeddings-inference`, `infinity`: embedding servers. Install: `npx skills add ScaleDockHQ/llm-skills --skill text-embeddings-inference`.
- `litellm`: embeddings gateway. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `qdrant`: alternative with API keys. Install: `npx skills add ScaleDockHQ/llm-skills --skill qdrant`.
- `pgvector`: Postgres alternative. Install: `npx skills add ScaleDockHQ/llm-skills --skill pgvector`.
