---
name: portkey
description: Run and use the Portkey AI Gateway, an open-source Node.js gateway to 250+ LLMs with configs for fallbacks, load balancing, retries, timeouts and guardrails, plus the hosted Portkey app. Use for Portkey, @portkey-ai/gateway, portkeyai/gateway, x-portkey-config, x-portkey-provider, conditional routing, Model Catalog `@provider/model`, port 8787, or routing errors. Not for choosing a gateway (llm-gateway); for virtual keys and budgets self-hosted, see litellm.
license: MIT
compatibility: Self-hosting needs Node.js 20+ or Docker and outbound access to providers. The open-source gateway has no virtual keys, budgets or inbound auth of its own, so bind to loopback or put an authenticating proxy in front. Hosted features need a Portkey account. Installs, exposure and key changes need explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Portkey AI Gateway

A running Portkey gateway (`@portkey-ai/gateway`, image `portkeyai/gateway`, repo Portkey-AI/gateway, MIT) that gives clients one OpenAI-compatible endpoint across providers with config-driven fallbacks, load balancing, retries, timeouts and conditional routing, plus the know-how to choose between the open-source gateway and the hosted Portkey platform, update it and troubleshoot it.

**Scope:** this one product, in two forms: the self-hosted open-source gateway (primary) and the hosted Portkey app and API (Model Catalog, API keys, config IDs, logs, guardrails). Choosing between gateways belongs to `llm-gateway`. If you need per-key budgets and virtual keys on your own hardware, use `litellm`.

Work through the steps in order. Load a reference only when a step names it. Docs and source were read on 2026-10-11. Docs mix hosted and open-source behavior; this skill marks which is which.

## Discover first

Read-only. Never print key values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i portkey || true
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep ':8787\b' || true
node --version 2>/dev/null; command -v npx
env | cut -d= -f1 | grep -iE 'portkey|openai_(api|base)'                       # names only
curl -fsS http://127.0.0.1:8787/v1/models | jq -r '.data[0:5][]?.id' 2>/dev/null || true
curl -fsS http://127.0.0.1:8787/ -o /dev/null -w '%{http_code}\n'                # liveness
gh api repos/Portkey-AI/gateway/releases/latest --jq '.tag_name + " " + .published_at'
curl -fsS "https://hub.docker.com/v2/repositories/portkeyai/gateway/tags?page_size=5" | jq -r '.results[].name'
```

Ask only what discovery cannot show: self-hosted or hosted, providers and where their keys live, who the callers are, whether the endpoint leaves localhost, and whether virtual keys, budgets or a UI are required.

## Decision flow

1. **Need per-team keys, budgets, rate limits, logs UI, saved configs, prompt management:** those are hosted Portkey (or Enterprise) features, not the open-source gateway. Use hosted, or pair the OSS gateway with `litellm`. -> `references/hosted-and-model-catalog.md`
2. **Want routing resilience only (fallback, load balance, retries, timeouts, conditional):** the open-source gateway is enough. -> `references/install.md`, `references/routing-and-configs.md`
3. **Nothing installed:** `npx @portkey-ai/gateway` to try, Docker with a pinned tag for a host, `deployment.yaml` for Kubernetes. -> `references/install.md`
4. **Wire the first provider:** provider header and provider key per request, or in the config. -> `references/serve-config.md`
5. **Resilience:** configs with `strategy`, `retry`, `request_timeout`, `cache`, circuit breaker. -> `references/routing-and-configs.md`
6. **Guardrails, MCP gateway, metadata:** -> `references/features.md`
7. **Clients, LiteLLM, Claude Code:** -> `references/litellm-and-clients.md`
8. **Traces and logs:** -> `references/observability.md`
9. **New release or branch change (1.x vs 2.0 pre-release):** -> `references/updating.md`
10. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, restarts, exposure and key changes need approval and an undo path (recorded image tag and digest).
- **No inbound auth in the OSS gateway.** Anyone who can reach port 8787 can route through your config. Bind to `127.0.0.1` (compose ports `127.0.0.1:8787:8787`), and front it with Caddy, Tailscale or Cloudflare Access before exposing it.
- **Provider keys stay out of output and configs in git.** Pass them from environment variables or `0600` files; the OSS gateway forwards the `Authorization` bearer to the provider.
- **Pin the image.** A release tag, ideally with digest; never `latest` in anything shared. `latest` and `main` can differ (see `references/updating.md`).
- **Know which docs apply.** `@provider-slug/model` strings, Model Catalog, saved `pc-...` config IDs, default configs on API keys, budgets and semantic cache are hosted features. The 1.x open-source gateway takes `x-portkey-provider` plus the provider key, and inline config JSON.
- **Retries and fallbacks multiply.** One layer retries; do not stack gateway retries, client retries and LiteLLM retries.
- **Verify upstream.** Versions, flags and defaults come from the repo, Docker Hub and docs.portkey.ai at use time.

## Workflows

### Install and first request (self-hosted)

- [ ] Pick the path; pin the tag; bind to loopback -> `references/install.md`, `assets/docker-compose.yaml`.
- [ ] Start it and check `GET /v1/models` or the console URL.
- [ ] One chat call with `x-portkey-provider` and the provider key -> `references/serve-config.md`.

### Add resilience

- [ ] Write a config (fallback, loadbalance, conditional) from `assets/` -> `references/routing-and-configs.md`.
- [ ] Send it inline in `x-portkey-config`; force a failure to see the fallback; read `x-portkey-last-used-option-index`.

### Connect clients

- [ ] OpenAI-compatible base URL `http://127.0.0.1:8787/v1` with headers, or the Portkey SDK -> `references/litellm-and-clients.md`.
- [ ] Stream and tool-call smoke test.

### Update or roll back

- [ ] Read release notes; record tag and digest; bump; re-run smoke tests -> `references/updating.md`.

### Troubleshoot

- [ ] `references/troubleshooting.md`.

## Reference index

- `references/install.md`: npx, Docker, Compose, Node build, Kubernetes, other targets, pinning.
- `references/serve-config.md`: ports, flags, headers, endpoints, provider keys, `conf.json`.
- `references/routing-and-configs.md`: config object, strategies, retries, timeouts, cache, circuit breaker.
- `references/hosted-and-model-catalog.md`: hosted Portkey, Model Catalog, API keys, plans versus OSS.
- `references/features.md`: guardrails, MCP gateway, prompts, metadata.
- `references/litellm-and-clients.md`: LiteLLM, SDKs, Claude Code, agents.
- `references/observability.md`: console, logs, trace IDs, metadata, OTel.
- `references/updating.md`: versions, tags, 2.0 pre-release, rollback.
- `references/troubleshooting.md`: symptom to cause to fix.

Templates: `assets/docker-compose.yaml`, `assets/config-fallback.json`, `assets/config-loadbalance.json`, `assets/config-conditional.json`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-gateway`: choose a gateway and the stack workflow around it.
- `litellm`: virtual keys, budgets and callbacks on your own host.
- `caddy`, `tailscale`, `cloudflare-tunnel`: authenticated exposure in front of the gateway.
- `llm-clients`: pointing agents, IDEs and SDKs at the gateway.
- `llm-observability`: traces and dashboards.
