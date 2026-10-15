---
name: lobehub
description: LobeHub (formerly LobeChat) v2 chat and agent workspace, self-hosted with Docker Compose. Use to deploy it, point its OpenAI-compatible or Anthropic proxy URLs at vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, set *_MODEL_LIST capabilities (fc, vision), handle keys, Docker networking, SSRF allowlists, update and backup, and fix empty replies, model-not-listed and connection errors. Not for choosing a chat UI (llm-clients).
license: MIT
compatibility: Docker with Compose v2 on Linux, macOS or Windows (WSL 2 for the setup script). Commands assume bash, curl and jq. Installs, secrets, exposure, updates and database or storage changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LobeHub

A working LobeHub v2 (`lobehub/lobehub`, formerly `lobe-chat`) talking to your own endpoints through a server-side provider config, with secrets in `0600` files and a pinned image.

**Scope:** this one product: install, connect endpoints, model lists and capabilities, Docker networking, update, backup, troubleshoot. Choosing among chat UIs belongs to `llm-clients` (`npx skills add ScaleDockHQ/llm-skills --skill llm-clients`); the gateway belongs to `litellm` or `llama-swap`; engines to `vllm`, `llama-cpp`, `ollama`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; env variable names only, never values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i lobe || true
docker inspect lobehub --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | cut -d= -f1 | sort
docker compose ps 2>/dev/null | head -20
gh api repos/lobehub/lobehub/releases/latest --jq .tag_name        # newest release
B="${LLM_BASE_URL:-http://localhost:4000/v1}"
curl -fsS -m 5 "$B/models" -H "Authorization: Bearer ${LLM_API_KEY:-none}" | jq -r '.data[].id' | head -20
docker exec lobehub sh -c 'wget -qO- --timeout=5 "$0" >/dev/null && echo reachable' "$B/models" 2>&1 | tail -1   # may lack wget/curl; then test from a sibling container
```

Ask only what discovery cannot show: single user or team, domain and TLS plan, which endpoints and where they run, which models need tools or vision.

## Decision flow

1. **No deployment yet:** v2 is server-database only. Needs PostgreSQL 17 with pgvector and pg_search, S3-compatible storage, and Better Auth secrets. Use the official Compose bundle. -> `references/install.md`
2. **Connect an endpoint:** server env vars (`OPENAI_PROXY_URL`, `OPENAI_API_KEY`, `OPENAI_MODEL_LIST`), or the UI under App Settings, AI Providers. -> `references/connections.md`
3. **Models missing, no tools, no vision, wrong context:** capabilities come from `*_MODEL_LIST` flags, not from `/v1/models`. -> `references/models-and-capabilities.md`
4. **Endpoint on the host or another container; private IP blocked:** -> `references/docker-networking.md`
5. **Behind a gateway (recommended for several engines):** -> `references/combos/gateway.md`
6. **Update, backup, move:** -> `references/updating-and-backup.md`
7. **Anything failing:** -> `references/troubleshooting.md`

## Hard rules

- Secrets (`KEY_VAULTS_SECRET`, `AUTH_SECRET`, `JWKS_KEY`, S3 and database passwords, provider keys) live in a `0600` `.env`, are generated locally with `openssl`, and are never printed or committed. Replace every placeholder and any password copied from an example before first start.
- `KEY_VAULTS_SECRET` encrypts stored user keys; changing it later makes saved keys unreadable. Back it up with the database.
- Pin an image tag (for example `lobehub/lobehub:2.2.19`) for anything shared; `latest` and `canary` move.
- Recreating the stack must keep the Postgres and object-storage volumes. Back up before updating.
- Use least-privilege, budgeted keys for the model endpoint, not a gateway master key.
- `SSRF_ALLOW_PRIVATE_IP_ADDRESS=1` disables SSRF protection entirely; prefer `SSRF_ALLOW_IP_ADDRESS_LIST` with only the endpoint IPs.
- `localhost` inside the container is the container. Use `host.docker.internal` (with `host-gateway` on Linux) or a service name.
- Do not claim a model supports tools or vision until a request proves it.

## Verify

1. `docker compose ps`: all services healthy; `docker logs lobehub` shows the migration passing and "Ready".
2. The app loads at `APP_URL` and you can register or sign in.
3. AI Providers shows the provider enabled; **Check** passes; the model appears in the selector.
4. A chat streams a reply; a tool-using agent completes a tool call (if `fc` is declared).

## Reference index

| File                                    | Read when                                                        |
| --------------------------------------- | ---------------------------------------------------------------- |
| `references/install.md`                 | First deployment, required secrets, ports, compose layout        |
| `references/connections.md`             | Proxy URLs, keys, OpenAI vs Anthropic providers, UI vs env       |
| `references/models-and-capabilities.md` | `*_MODEL_LIST` syntax, fc and vision flags, limits               |
| `references/docker-networking.md`       | Host endpoints, private IPs, SSRF allowlist, Client Request Mode |
| `references/updating-and-backup.md`     | Upgrade, gateway variables, backup and restore                   |
| `references/troubleshooting.md`         | Symptom table                                                    |
| `references/combos/gateway.md`          | One connection to LiteLLM or llama-swap in front of engines      |
| `assets/lobehub-models.env.example`     | Provider variables to merge into the Compose `.env`              |

## Out of scope

Choosing among chat UIs (`llm-clients`), serving engines (`vllm`, `llama-cpp`, `ollama`), gateways (`litellm`, `llama-swap`), reverse proxy and TLS (`caddy`, `tailscale`, `cloudflare-tunnel`), tracing (`langfuse`).
