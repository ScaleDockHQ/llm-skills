---
name: milvus
description: Run Milvus, the distributed vector database, as standalone Docker or Milvus Lite next to a self-hosted LLM stack for RAG. Use for milvusdb/milvus, standalone_embed.sh, port 19530 and 9091, etcd and MinIO dependencies, pymilvus, HNSW, IVF, DiskANN, mmap, root:Milvus default password, authorizationEnabled, memory sizing, embeddings via LiteLLM or TEI. For smaller stacks consider qdrant, pgvector or chroma.
license: MIT
compatibility: Linux or macOS with Docker (standalone needs 8 GB RAM minimum, 16 GB recommended per upstream), or pip for Milvus Lite on Ubuntu 20.04+ and macOS 11+, bash, curl and jq. Installing, starting containers, opening ports and deleting volumes needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Milvus

Run Milvus standalone (or Milvus Lite for prototyping) with authentication on, hardened defaults, and a memory plan, then feed it embeddings produced through LiteLLM.

**Scope:** Milvus only: choose a mode, install, size, secure, back up, upgrade, troubleshoot, tear down. Kubernetes cluster operation is outside the depth here; point to upstream Helm and Operator docs. Embedders are `text-embeddings-inference` and `infinity`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
command -v docker && docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i -E 'milvus|etcd|minio' || true
curl -fsS http://127.0.0.1:9091/healthz -w '  healthz %{http_code}\n' 2>/dev/null
ss -ltnp 2>/dev/null | grep -E ':(19530|9091|2379|9000|9001)\b' || true
free -g 2>/dev/null | sed -n 1,2p; df -h . | tail -1
lscpu 2>/dev/null | grep -i -E 'model name|flags' | grep -o -i -E 'avx512[a-z_]*|avx2|sse4_2' | sort -u | tr '\n' ' '
```

## Decision flow

1. Prototype or tests, one process, no server: Milvus Lite (`pip install "pymilvus[milvus-lite]"`). Same API, but some parameters are unsupported; not for production traffic.
2. A server on one machine: Milvus standalone with Docker Compose (etcd, MinIO, milvus) or the `standalone_embed.sh` single container (embedded etcd, local storage).
3. Multi-node, HA or very large: Milvus distributed on Kubernetes (upstream Helm or Operator).
4. Fewer than a few million vectors and you already run Postgres: `pgvector` is simpler; for a lighter single binary use `qdrant`.
5. Size first (`references/sizing.md`); upstream standalone minimum is 8 GB RAM, 16 GB recommended, 4+ cores.
6. Turn authentication on before first use, and change the default `root` password.

## Rules

- **Ask before changing the system.** Containers, ports, config edits, upgrades and volume deletion need approval and an undo path.
- **Secrets never touch output.** The `root` token, MinIO keys and passwords come from `0600` files or env, not from shell history or compose files in git.
- **Defaults are insecure.** Authentication is off (`common.security.authorizationEnabled: false`), the bundled `root` password is `Milvus`, MinIO uses `minioadmin`/`minioadmin`, and upstream compose publishes ports on all interfaces.
- **Port 9091** (health, metrics, WebUI, management) is plaintext. Set `adminAuthEnabled`, keep it on loopback or a private network.
- **Never publish etcd (2379) or MinIO (9000/9001).**
- **Vector dimension and metric are fixed per field.** A model change means a new collection and re-embedding.
- **Upgrades are one-way.** Upstream says an image-only rollback after an upgrade can fail; back up metadata and data first.
- **Verify upstream.** Image tags and config keys come from the repo and docs read on the writing date (v3.0.x line).

## Workflows

- [ ] Choose mode and install -> `references/install.md`, `templates/docker-compose.yml`
- [ ] Size memory and pick an index -> `references/sizing.md`
- [ ] Harden -> `references/security.md`, `templates/user.yaml`
- [ ] Create collections, load, query through LiteLLM embeddings -> `references/api.md`, `references/combos/llm-stack.md`
- [ ] Back up, upgrade, tear down -> `references/updating.md`
- [ ] Debug -> `references/troubleshooting.md`
- [ ] Verify: `/healthz` is OK, an unauthenticated REST call is rejected, a test collection round-trips an embedding, and memory use matches the plan.

## Reference index

- `references/install.md`: Lite, `standalone_embed.sh`, Compose, tags, requirements.
- `references/sizing.md`: memory math per index type, mmap, DiskANN.
- `references/security.md`: authentication, root password, MinIO keys, TLS, ports.
- `references/api.md`: REST v2 and pymilvus basics.
- `references/updating.md`: backup, upgrade, rollback limits, teardown.
- `references/troubleshooting.md`: symptom to fix.
- `references/combos/llm-stack.md`: LiteLLM embeddings, llama-swap, Open WebUI.

## Companion skills

- `text-embeddings-inference`, `infinity`: embedding servers. Install: `npx skills add ScaleDockHQ/llms-skills --skill text-embeddings-inference`.
- `litellm`: embeddings gateway. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `qdrant`: lighter alternative. Install: `npx skills add ScaleDockHQ/llms-skills --skill qdrant`.
- `pgvector`: Postgres alternative. Install: `npx skills add ScaleDockHQ/llms-skills --skill pgvector`.
