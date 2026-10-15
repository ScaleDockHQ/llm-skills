---
name: traefik
description: Traefik Proxy, a cloud-native reverse proxy and ingress controller with automatic Let's Encrypt TLS, Docker, file and Kubernetes providers and middlewares. Use to front LLM endpoints (vLLM, Ollama, LiteLLM, llama-swap) with TLS, forwardAuth, basicAuth, IP allowlists and rate limits, keep SSE streaming working, install, upgrade v2 to v3, and fix 404, 502, 504, ACME or dashboard-exposure problems. Not Caddy or tunnels.
license: MIT
compatibility: Commands assume bash, curl, jq and Docker Compose (Kubernetes and binary paths are covered by reference). Installs, exposing ports, mounting the Docker socket, certificate issuance and upgrades need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Traefik

A running Traefik Proxy (`traefik`, image `traefik:v3.7`, repo traefik/traefik, MIT) that terminates TLS and routes `https://llm.example.com` to local model servers, with auth, limits and streaming-safe settings.

**Scope:** this one product: install, configure routers, services and middlewares, TLS, operate, update, troubleshoot. Choosing between exposure options belongs to `choosing-llm-hosting`; the siblings are `caddy`, `cloudflare-tunnel` and `tailscale`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i traefik || true
command -v traefik && traefik version
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -E ':(80|443|8080|8082)\b' || true
find ~ /etc/traefik -maxdepth 4 \( -name 'traefik*.y*ml' -o -name 'traefik*.toml' -o -name 'acme.json' \) 2>/dev/null | head
docker inspect <traefik-container> --format '{{.Config.Image}} {{json .Mounts}}' 2>/dev/null | jq -r . 2>/dev/null
curl -fsS http://127.0.0.1:8080/api/overview | jq .                       # only if api.insecure or a private entrypoint
curl -fsS http://127.0.0.1:8080/api/http/routers | jq -r '.[]|[.name,.rule,.status]|@tsv'
traefik healthcheck --ping 2>/dev/null                                    # needs --ping
gh api repos/traefik/traefik/releases/latest --jq .tag_name
```

Ask only what discovery cannot show: the backends and their ports, the hostname and DNS provider, who may call it (people, apps, CI), Docker vs Kubernetes vs binary, public vs private network.

## Decision flow

1. **Nothing installed:** Docker Compose with the file provider for fixed backends, or the Docker provider with labels for containers. -> `references/install.md`
2. **Need HTTPS:** ACME resolver with TLS-ALPN, HTTP or DNS challenge; wildcard needs DNS. -> `references/tls-acme.md`
3. **Fronting an LLM server (streaming, long requests):** -> `references/llm-reverse-proxy.md`
4. **Need auth, allowlists, rate limits:** middlewares. -> `references/middlewares-auth.md`
5. **Routers, services, providers, entrypoints:** -> `references/routing-and-providers.md`
6. **Static options, entrypoints, timeouts, logs, metrics:** -> `references/serve-config.md`, `references/observability.md`
7. **Upgrade or v2 to v3:** -> `references/updating.md`
8. **404, 502, 504, no certificate, dashboard open:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Exposure, Docker socket access, certificate requests and upgrades need approval and an undo path (previous image tag, copy of `acme.json`).
- **Never enable `api.insecure` in production.** It serves the dashboard and API on the `traefik` entrypoint (8080) without auth. Bind it to `127.0.0.1` or route it through a router with auth.
- **The Docker socket is root-equivalent.** Mount it read-only at most, or use a socket proxy; set `providers.docker.exposedByDefault=false` and label only what should be public.
- **Pin the image.** `traefik:v3.7.14` or `v3.7`, never `latest` in anything shared. Only 3.7 has active support in the docs table; read the migration notes before moving minors.
- **LLM routes are streaming routes.** No `buffering` middleware, no `forwardAuth.forwardBody`, `compress` off or excluding `text/event-stream`, and no write timeout. See `references/llm-reverse-proxy.md`.
- **Static vs dynamic.** Entrypoints, providers, resolvers, logs and metrics are static (restart); routers, services and middlewares are dynamic (hot reload).
- **`acme.json` must be `chmod 600`** and persisted on a volume. Test with the Let's Encrypt staging `caServer` first.
- **Secrets never touch output.** DNS provider tokens and hashed users live in `0600` env or users files; `jq`-filter any config dump.
- **Verify upstream.** Options come from doc.traefik.io for the running version; `/api/rawdata` shows the live dynamic config.

## Workflows

### Install and first route

- [ ] Choose compose + file provider or Docker labels -> `references/install.md`; copy `templates/`.
- [ ] Set entrypoints `web` (80, redirect to https) and `websecure` (443); bind the dashboard to localhost.
- [ ] `docker compose up -d`; check `/api/http/routers` and one `curl -H 'Host: ...'`.

### Front an LLM backend

- [ ] Add a router and a `loadBalancer.servers` URL for the backend -> `references/routing-and-providers.md`.
- [ ] Add auth and rate limit middlewares -> `references/middlewares-auth.md`.
- [ ] Test a stream: `curl -N` and confirm tokens arrive incrementally -> `references/llm-reverse-proxy.md`.

### Update

- [ ] Read `migrate/v3` notes between tags, record the current image, copy `acme.json` -> `references/updating.md`.
- [ ] Bump the pin, pull, recreate, re-run smoke tests; roll back to the recorded tag on regression.

## Reference index

| File                                  | Read when                                                  |
| ------------------------------------- | ---------------------------------------------------------- |
| `references/install.md`               | Docker Compose, binary, Kubernetes pointers, hardening     |
| `references/serve-config.md`          | Static config, entrypoints, timeouts, ping, API            |
| `references/routing-and-providers.md` | Routers, rules, services, Docker and file providers        |
| `references/middlewares-auth.md`      | forwardAuth, basicAuth, ipAllowList, rateLimit, headers    |
| `references/tls-acme.md`              | Resolvers, challenges, storage, redirects                  |
| `references/llm-reverse-proxy.md`     | SSE streaming, timeouts, long prompts, WebSocket, backends |
| `references/observability.md`         | Access logs, Prometheus, health checks, dashboard          |
| `references/updating.md`              | Release support, v2 to v3, pinning, rollback               |
| `references/troubleshooting.md`       | Symptom to cause to fix                                    |

Templates: `templates/docker-compose.yml`, `templates/traefik.yml`, `templates/dynamic-llm.yml`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `caddy`: simpler auto-TLS reverse proxy and the LLM model catalog front.
- `cloudflare-tunnel`, `tailscale`: exposure without opening ports.
- `choosing-llm-hosting`: where to host and how to expose.
- `litellm`, `llama-swap`, `vllm`, `ollama`: backends behind Traefik.
- `llm-gateway`: keys and budgets, which Traefik does not provide.
