---
name: open-webui
description: Open WebUI, the self-hosted multi-user chat UI (ghcr.io/open-webui/open-webui) with RAG, tools and model presets. Use to install it (Docker, Compose, pip), add OpenAI-compatible connections to vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, handle keys and model IDs, Docker networking to host endpoints, native tool calling, persistence and backups, pinned updates, or fix empty model list, Connection error, blank replies, logged out after update. Not for choosing a client (llm-clients).
license: MIT
compatibility: Docker or Podman (Compose v2) on Linux, macOS or Windows; pip and uv installs also exist. Commands assume bash, curl and jq. Installs, exposure, updates and anything that touches the data volume need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Open WebUI

A working Open WebUI (`open-webui/open-webui`, image `ghcr.io/open-webui/open-webui`, custom Open WebUI License) in front of your own model endpoints: containerised so it reaches the host or gateway, keyed with least privilege, with model capabilities declared, data on a volume that survives updates, and a pinned image you can roll back.

**Scope:** this one product: install, connect endpoints, capabilities and tools, Docker networking, persistence and backups, update, troubleshoot. Choosing among chat UIs and clients belongs to `llm-clients`. Running the endpoint belongs to the engine, `litellm` or `llama-swap` skills; reverse proxies and TLS belong to `caddy`, `tailscale` or `cloudflare-tunnel`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i open-webui || true
docker volume ls --format '{{.Name}}' | grep -i open-webui || true
docker inspect open-webui --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | cut -d= -f1 | sort   # env variable NAMES only
docker inspect open-webui --format '{{.Image}} {{range .Mounts}}{{.Name}}:{{.Destination}} {{end}}' 2>/dev/null
curl -fsS -m 5 http://localhost:3000/api/config | jq 'del(.oauth)' | head -20          # backend reachable (JSON back)
curl -fsS -m 5 http://localhost:3000/api/version | jq .                              # running version
gh api repos/open-webui/open-webui/releases/latest --jq .tag_name                      # newest release
B="${LLM_BASE_URL:-http://localhost:4000/v1}"
curl -fsS -m 5 "$B/models" -H "Authorization: Bearer ${LLM_API_KEY:-none}" | jq -r '.data[].id' | head -20   # from the host
docker exec open-webui sh -c 'curl -fsS -m 5 -o /dev/null -w "%{http_code}\n" "$0"' "$B/models" 2>&1 | tail -1   # from inside the container
```

Ask only what discovery cannot show: Docker or pip, single user or team, which endpoint(s) and where they run (same host, LAN, gateway), which models need tools or vision, whether TLS and a reverse proxy are in front.

## Decision flow

1. **No instance yet:** Docker with a named volume, a fixed `WEBUI_SECRET_KEY` and a pinned tag. -> `references/install.md`
2. **Endpoint on the Docker host or LAN:** `host.docker.internal`, `host-gateway`, bind addresses. -> `references/docker-networking.md`
3. **Add an OpenAI-compatible connection** (vLLM, llama.cpp, LiteLLM, llama-swap, LM Studio): Admin Connections or env. -> `references/connections.md`
4. **Ollama:** its own connection type. -> `references/connections.md`
5. **Tools, vision, context, reasoning, streaming issues:** -> `references/models-and-tools.md`
6. **Env vars ignored, settings lost, backups, update, rollback:** -> `references/persistence-and-updating.md`
7. **Gateway in front:** least-privilege key, user headers. -> `references/combos/litellm.md`
8. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, port exposure, updates, `docker rm`, volume operations and resetting config need approval and an undo path (volume backup, recorded image digest).
- **Secrets never touch output.** Keys, `WEBUI_SECRET_KEY` and connection keys live in `0600` env files or the admin UI; check presence by variable name only. Give Open WebUI a least-privilege virtual key, never a gateway master key.
- **Persist the data and the secret.** Run with `-v open-webui:/app/backend/data` and a fixed `WEBUI_SECRET_KEY`; without them updates wipe data or log everyone out.
- **`localhost` is the container.** Use `host.docker.internal` (with `--add-host=host.docker.internal:host-gateway` on Linux), a Compose service name, or a LAN address.
- **Env vars are first-boot only.** With `ENABLE_PERSISTENT_CONFIG=True` (default) the database wins after first start; change connections in the admin UI or set `ENABLE_PERSISTENT_CONFIG=False`.
- **Pin the image.** Exact `vX.Y.Z` tags, not `:main`/`:latest`; back up before upgrading; never share a data volume with `:dev`.
- **Declare capabilities.** `/v1/models` carries ids only; set vision, tools and params per model.
- **Verify upstream.** Variables, defaults and tags come from docs.openwebui.com and releases at use time, not memory.

## Workflows

### Install and first connection

- [ ] Run Discover; pick Docker or Compose -> `references/install.md`; generate the secret with `openssl rand -hex 32` into a `0600` file.
- [ ] Start with `assets/docker-compose.yml` (pinned tag, volume, `extra_hosts`).
- [ ] From inside the container, curl the endpoint's `/models` -> `references/docker-networking.md`.
- [ ] Admin, Settings, Connections, Add Connection: URL ending in `/v1`, key, Model IDs allowlist, then Verify Connection -> `references/connections.md`.
- [ ] Set model capabilities and test a tool chat -> `references/models-and-tools.md`.

### Team instance behind a gateway

- [ ] One connection to the gateway with a virtual key; Model IDs allowlist of aliases -> `references/combos/litellm.md`.
- [ ] Optional: `ENABLE_FORWARD_USER_INFO_HEADERS=true` for per-user audit at the gateway.
- [ ] Reverse proxy with WebSocket upgrade and no SSE buffering -> `references/troubleshooting.md`.

### Update

- [ ] Back up the volume; record `docker inspect --format '{{.Image}}' open-webui`.
- [ ] Bump the pinned tag, `docker compose pull && docker compose up -d`; hard-refresh the browser -> `references/persistence-and-updating.md`.

## Reference index

| File                                     | Read when                                                                             |
| ---------------------------------------- | ------------------------------------------------------------------------------------- |
| `references/install.md`                  | Image tags and variants, docker run, Compose, pip, first boot                         |
| `references/connections.md`              | OpenAI-compatible and Ollama connections, URLs per engine, Provider setting, env vars |
| `references/models-and-tools.md`         | Capabilities, native tool calling, params, streaming, reasoning, embeddings           |
| `references/docker-networking.md`        | Reaching host, LAN and container endpoints; bind addresses; Podman                    |
| `references/persistence-and-updating.md` | Volume, persistent config, backup and restore, update, rollback                       |
| `references/troubleshooting.md`          | Symptom to cause to fix                                                               |
| `references/combos/litellm.md`           | LiteLLM or llama-swap in front, keys and headers                                      |

Templates: `assets/docker-compose.yml`, `assets/open-webui.env.example`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-clients`: choosing a client, shared capability and troubleshooting notes.
- `litellm`: the gateway with virtual keys that Open WebUI should point at.
- `llama-swap`: hot-swapping local models behind one URL.
- `vllm`, `llama-cpp`, `ollama`, `lm-studio`: engines Open WebUI connects to; they own tool-parser and bind flags.
- `caddy`, `tailscale`, `cloudflare-tunnel`: TLS and exposure in front of the UI.
