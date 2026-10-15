---
name: helicone
description: Use Helicone (helicone.ai), the open-source LLM observability platform and OpenAI-compatible AI gateway, for request logging, cost tracking, sessions, caching, rate limits and provider fallbacks, and know it has been in maintenance mode since Mintlify bought it in March 2026. Use when the user mentions Helicone, HELICONE_API_KEY, ai-gateway.helicone.ai, Helicone-* headers, helicone-all-in-one, or migrating off Helicone. For alternatives use litellm, langfuse, llm-gateway or llm-observability.
license: MIT
compatibility: Needs a Helicone account and API key in an environment variable or a 0600 file, curl and jq; Docker for self-hosting. Ask the user before adding credits, enabling caching or request body logging, storing provider keys, or exposing a self-hosted instance.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Helicone

Log, observe and route LLM traffic through Helicone, and judge whether to start (or stay) given its maintenance-mode status.

**Scope:** the hosted Helicone platform and its AI Gateway (`https://ai-gateway.helicone.ai`), Helicone request headers (sessions, properties, user ids, cache, rate limits), BYOK vs credits, and Docker self-hosting of the observability stack. Out of scope: other gateways (`litellm`, `bifrost`, `llm-gateway`), tracing platforms (`langfuse`, `llm-observability`).

**Status check first.** On 2026-03-03 Mintlify acquired Helicone. The team states the services stay live in maintenance mode: security updates, new-model support and bug and performance fixes continue, with no new features or roadmap. There is no announced shutdown date. The main repo (`Helicone/helicone`, Apache-2.0) still had commits in September 2026; the separate Rust gateway repo (`Helicone/ai-gateway`, GPL-3.0) had no pushes after 2025-11-21 and no releases. Recommend Helicone for existing deployments or short horizons, and plan an exit (`references/migration.md`) for anything long-lived.

Work through the steps in order. Load a reference only when a step names it. Docs move, so check the live page for headers and limits.

## Discover first

Read-only. Nothing here prints a key.

```bash
env | cut -d= -f1 | grep -E '^(HELICONE|OPENAI|ANTHROPIC)' || echo "no related env vars"
command -v curl jq docker

# Maintenance status (public)
gh api repos/Helicone/helicone --jq '{archived,pushed_at,license:.license.spdx_id}'
curl -sSL https://www.helicone.ai/blog/joining-mintlify | sed 's/<[^>]*>/ /g' | grep -i -m3 'maintenance'

# Self-hosted instance, if any
docker ps --filter ancestor=helicone/helicone-all-in-one --format '{{.Names}} {{.Ports}}'
curl -sS http://localhost:8585/healthcheck
```

## Decision flow

1. New project with a long horizon: prefer an actively developed gateway or tracer (`litellm`, `bifrost`, `langfuse`). Continue only if the user wants Helicone anyway.
2. Existing Helicone use: keep it, pin your integration, and write an exit plan (`references/migration.md`).
3. Start with the gateway: key, base URL, credits or BYOK (`references/setup-and-auth.md`).
4. Add observability metadata: sessions, properties, user ids (`references/features.md`).
5. Cost and abuse controls: cache and rate-limit headers (`references/features.md`).
6. Routing and fallbacks: `references/gateway-and-routing.md`.
7. Own the data: self-host (`references/self-hosting.md`).
8. LiteLLM or other clients: `references/litellm-and-clients.md`.
9. Done: `references/teardown.md`.

## Rules

- **State the maintenance status.** Tell the user plainly before recommending a new adoption.
- **Secrets never touch output.** `HELICONE_API_KEY` and provider keys come from env vars or `0600` files. Do not put keys in URLs; some legacy Helicone integrations embed the key in the base URL path, so avoid them.
- **Ask before money or data.** Credits, body logging, caching (cache keys include the auth header), stored provider keys.
- **Do not hardcode prices or model lists.** The registry at helicone.ai/models and the dashboard are live.
- **Self-hosted defaults are unsafe.** The all-in-one image defaults `BETTER_AUTH_SECRET` to `change-me-in-production` and MinIO credentials to `minioadmin`; set real values before any non-local use.
- **Header values are strings.** Send numbers and booleans as strings in Helicone headers.

## Workflows

### 1. Start with the gateway

- [ ] Create an API key in Helicone settings; store it in a `0600` file -> `references/setup-and-auth.md`
- [ ] OpenAI SDK with `base_url=https://ai-gateway.helicone.ai` and `api_key=$HELICONE_API_KEY`.
- [ ] Verify: the request shows in the Requests tab within seconds.

### 2. Observe

- [ ] Sessions, properties, user ids -> `references/features.md`

### 3. Control

- [ ] Caching, rate limits, provider order and exclusions -> `references/features.md`, `references/gateway-and-routing.md`

### 4. Self-host (optional)

- [ ] Docker all-in-one, secrets, public URLs, gateway alongside -> `references/self-hosting.md`

### 5. Exit or tear down

- [ ] `references/migration.md`, `references/teardown.md`, `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: account, keys, credits vs BYOK, base URL.
- `references/gateway-and-routing.md`: model strings, provider locking, fallback chains, failover triggers.
- `references/features.md`: sessions, properties, user metrics, caching, rate limits, header list.
- `references/self-hosting.md`: Docker, ports, env vars, security.
- `references/litellm-and-clients.md`: LiteLLM, OpenAI SDK, other clients.
- `references/migration.md`: leaving Helicone.
- `references/teardown.md`: delete and revoke.
- `references/troubleshooting.md`: symptom to fix.

## Companion skills

- `litellm`: self-hosted gateway with a Helicone callback path. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `bifrost`: actively developed open-source gateway. Install: `npx skills add ScaleDockHQ/llm-skills --skill bifrost`.
- `langfuse`: open-source tracing. Install: `npx skills add ScaleDockHQ/llm-skills --skill langfuse`.
- `llm-observability`: choosing observability. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
- `llm-gateway`: gateway design. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
