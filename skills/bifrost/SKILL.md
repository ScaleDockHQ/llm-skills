---
name: bifrost
description: Install and run Bifrost (maximhq/bifrost), a Go open-source AI gateway with a web UI that fronts 20+ providers behind OpenAI-, Anthropic-, Bedrock- and GenAI-compatible APIs, with fallbacks, virtual keys, budgets, semantic cache and MCP. Use when the user mentions Bifrost, maximhq/bifrost, getbifrost.ai, `npx @maximhq/bifrost`, virtual keys sk-bf-, x-bf-vk, config.json for a gateway, or migrating from LiteLLM. For other gateways use litellm, llm-gateway or portkey.
license: MIT
compatibility: Linux or macOS with Docker or Node (npx), curl and jq; PostgreSQL 16+ for production or multi-replica use. Ask before exposing it beyond localhost, enabling auth, creating virtual keys, adding provider keys, or enabling semantic cache backends.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Bifrost

Run Bifrost as the single front door for model providers: start the gateway, add providers, call it with the OpenAI, Anthropic or other SDKs, add fallbacks, issue virtual keys with budgets, observe it, update it, and tear it down.

**Scope:** the open-source Bifrost HTTP gateway (docker image `maximhq/bifrost`, npx wrapper `@maximhq/bifrost`), its web UI, `config.json`, governance, retries and fallbacks, caching and observability. The Go SDK, Bifrost Enterprise features and the Edge product are mentioned only to flag the boundary. Out of scope: LiteLLM operation (`litellm`), gateway design across products (`llm-gateway`).

Work through the steps in order. Load a reference only when a step names it. Bifrost ships a patch roughly every 2 to 3 days, so check the release before pinning.

## Discover first

Read-only. Nothing here prints a key.

```bash
command -v docker node npx curl jq
docker ps --filter ancestor=maximhq/bifrost --format '{{.Names}} {{.Image}} {{.Ports}}'
docker image ls maximhq/bifrost --format '{{.Tag}} {{.CreatedSince}}'

# Latest gateway release and image tags (no auth)
gh api repos/maximhq/bifrost/releases --jq '[.[]|select(.tag_name|startswith("transports/"))][0]|.tag_name,.published_at'
curl -sS 'https://hub.docker.com/v2/repositories/maximhq/bifrost/tags?page_size=5&ordering=last_updated' | jq -r '.results[].name'

# A running instance
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:8080/health
curl -sS http://localhost:8080/api/providers | jq 'keys? // .'
```

`GET /health` returns 200 when ready (503 if a store check fails). With dashboard auth enabled, admin routes need credentials.

## Decision flow

1. Trying it out on one machine: `npx -y @maximhq/bifrost` or Docker with a volume (`references/install.md`).
2. Production: pin an image tag, enable auth, TLS, durable storage (SQLite with a volume for one instance, PostgreSQL 16+ otherwise), declare config in `config.json` (`references/configuration.md`).
3. Add providers and keys, including self-hosted vLLM or Ollama as custom providers (`references/configuration.md`).
4. Per-team access, budgets and rate limits: virtual keys (`references/governance.md`).
5. Reliability: `max_retries` per provider and `fallbacks` per request (`references/routing-and-fallbacks.md`).
6. Clients: OpenAI, Anthropic, LiteLLM SDK drop-ins and Claude Code (`references/integrations.md`).
7. Metrics, logs, caching: `/metrics`, content logging, semantic cache (`references/observability.md`).
8. Replacing LiteLLM: migration CLI (`references/integrations.md`).
9. Update or stop: `references/updating.md`, `references/teardown.md`.

## Rules

- **Pin versions in production.** The unversioned `docker run maximhq/bifrost` and `npx` commands are for local evaluation; use a tag like the latest `vX.Y.Z` and read the release notes.
- **Secrets never touch output.** Reference keys as `env.VAR_NAME` in `config.json`; keep `BIFROST_ENCRYPTION_KEY` and `BIFROST_SETUP_TOKEN` in `0600` files or the platform's secret store.
- **Turn on auth before exposing it.** Until an admin account exists, the dashboard and admin API are open to anyone who can reach the port. Creating the first admin needs a setup token.
- **OSS is single node.** Running several OSS replicas on one PostgreSQL is not supported because state is held in memory; high availability and clustering are Enterprise features.
- **Virtual keys are deny-by-default for providers.** A key with empty `provider_configs` blocks everything.
- **Ask before widening exposure.** Binding `0.0.0.0`, public hostnames and disabling inference auth need approval.
- **Do not trust gateway keys as a security boundary alone.** Pair with network controls.

## Workflows

### 1. Start

- [ ] Pick install method -> `references/install.md`
- [ ] Verify: `curl http://localhost:8080/health` is 200 and the UI loads on port 8080.

### 2. Add providers and call it

- [ ] UI, `POST /api/providers`, or `config.json` -> `references/configuration.md`
- [ ] Call `POST /v1/chat/completions` with `model: "<provider>/<model>"`.
- [ ] Verify: the request appears in the UI logs.

### 3. Govern

- [ ] Auth on, virtual keys, budgets, rate limits -> `references/governance.md`
- [ ] Verify: a key over budget is rejected and a key without provider access fails.

### 4. Make it resilient and observable

- [ ] Retries, fallbacks, routing rules -> `references/routing-and-fallbacks.md`
- [ ] Prometheus, OTel, semantic cache -> `references/observability.md`

### 5. Connect clients

- [ ] `references/integrations.md`

### 6. Update, tear down, troubleshoot

- [ ] `references/updating.md`, `references/teardown.md`, `references/troubleshooting.md`

## Reference index

- `references/install.md`: npx, Docker, Compose, Kubernetes and cloud pointers, storage.
- `references/configuration.md`: flags, env vars, `config.json`, providers, custom providers.
- `references/governance.md`: auth, virtual keys, teams, budgets and rate limits.
- `references/routing-and-fallbacks.md`: retries, fallbacks, routing rules, weights.
- `references/observability.md`: logs, Prometheus, OpenTelemetry, semantic cache.
- `references/integrations.md`: SDK drop-ins, Claude Code, LiteLLM migration.
- `references/updating.md`: release cadence, upgrade steps.
- `references/teardown.md`: stop and delete.
- `references/troubleshooting.md`: symptom to fix.
- `assets/docker-compose.yaml`, `assets/config.json`: starting templates.

## Companion skills

- `llm-gateway`: gateway design. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `litellm`: the main alternative and migration source. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llm-observability`: wider tracing. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
- `vllm`, `ollama`: self-hosted providers behind Bifrost. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `caddy`, `cloudflare-tunnel`, `tailscale`: TLS and exposure. Install: `npx skills add ScaleDockHQ/llm-skills --skill caddy`.
