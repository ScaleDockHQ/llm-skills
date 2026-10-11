---
name: cloudflare-ai-gateway
description: Operate Cloudflare AI Gateway, a managed proxy that adds logging, caching, rate and spend limits, retries and dynamic routing in front of OpenAI, Anthropic, Workers AI and other providers. Use when the user mentions AI Gateway, gateway.ai.cloudflare.com, cf-aig-* headers, cf-aig-authorization, Unified Billing, BYOK stored keys, dynamic/<route>, or a 401, 429 or 404 through the gateway. For other gateways use llm-gateway, litellm or vercel-ai-gateway; for tunnels use cloudflare-tunnel.
license: MIT
compatibility: Needs a Cloudflare account, an API token in an environment variable or a 0600 file, curl and jq; wrangler is optional. Ask the user before enabling Unified Billing, loading credits, turning on caching or logging of prompts, storing provider keys, or deleting a gateway.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Cloudflare AI Gateway

Put Cloudflare's hosted gateway between an app and its model providers: one authenticated endpoint, request logs and cost analytics, optional caching, rate and spend limits, retries and fallbacks, and a clean teardown.

**Scope:** the hosted AI Gateway service (REST API at `api.cloudflare.com`, provider-native URLs at `gateway.ai.cloudflare.com`, the Workers AI binding), gateway settings, BYOK, Unified Billing, limits, logging and routing. Out of scope: self-hosted gateways (`litellm`, `llm-gateway`, `bifrost`), exposing your own servers (`cloudflare-tunnel`), Workers or Wrangler development in general.

Work through the steps in order. Load a reference only when a step names it. The docs change often (the changelog had entries through 2026-10-06), so read the live page when a detail matters.

## Discover first

Read-only. Nothing here prints a token.

```bash
env | cut -d= -f1 | grep -E '^(CLOUDFLARE|CF_AIG|OPENAI|ANTHROPIC)' || echo "no related env vars"
command -v curl jq wrangler

# Account and gateways (needs AI Gateway - Read)
curl -sS "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/ai-gateway/gateways" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq '.result[] | {id, authentication, collect_logs, cache_ttl, rate_limiting_limit}'
```

An empty list means no gateway exists yet. The `default` gateway is created on the first authenticated request, so a first call can create one.

## Decision flow

1. No gateway or token yet: `references/setup-and-auth.md`.
2. New integration: call the REST API (`/ai/v1/chat/completions`). The older `gateway.ai.cloudflare.com/.../compat` URL still works but is deprecated for single-model calls (`references/endpoints-and-usage.md`).
3. Existing SDK that must keep the provider's own schema: provider-native URL `.../v1/{account_id}/{gateway_id}/{provider}`.
4. Who pays: request header key, stored key (BYOK) or Cloudflare credits (Unified Billing). Precedence is in `references/setup-and-auth.md`.
5. Cost or abuse control: spend limits, rate limiting, caching (`references/controls.md`).
6. Resilience: retries, timeouts, dynamic routes with fallbacks (same file).
7. Visibility and privacy: logs, metadata, payload opt-out (`references/observability.md`).
8. Done or idle: `references/teardown.md`.

## Rules

- **Ask before anything that costs money or stores data.** Unified Billing credits, auto top-up, caching, log payload retention, stored provider keys.
- **Secrets never touch output.** `CLOUDFLARE_API_TOKEN`, the gateway token and provider keys come from env vars or `0600` files. Never paste them in chat, URLs or logs.
- **Authenticate every gateway.** Unauthenticated gateways accept anything and inflate logs; the auto-created `default` gateway has authentication on.
- **Tokens are account-scoped.** `AI Gateway Run` works on every gateway in the account, including those with stored keys. Isolate tenants with separate accounts or the Worker binding.
- **Spend limits are soft.** Enforcement is eventually consistent, so a burst can overshoot. Combine with provider-side limits.
- **Check the credential path.** A request with no provider key and no stored key falls through to Unified Billing and bills Cloudflare credits. Turn on "Require provider credentials" when that is unwanted.
- **Do not hardcode prices.** Read live rates from the dashboard or provider docs.

## Workflows

### 1. Create and authenticate a gateway

- [ ] Account ID, API token with `AI Gateway - Read/Edit` (and `Run` for clients) -> `references/setup-and-auth.md`
- [ ] Create a named gateway or rely on `default`; turn authentication on.
- [ ] Verify: the `curl` list above shows it, and a call without a token fails.

### 2. Send traffic

- [ ] REST `/ai/v1/chat/completions` with `model: <provider>/<model>` -> `references/endpoints-and-usage.md`
- [ ] Verify: the request appears in the dashboard Logs, with `cf-aig-cache-status` if caching is on.

### 3. Limit cost and abuse

- [ ] Spend limit rules (up to 20 per gateway), rate limit, optional cache -> `references/controls.md`
- [ ] Verify: an over-limit request returns `429`.

### 4. Make it resilient

- [ ] Retries (up to 5 attempts), request timeout, dynamic route with fallback -> `references/controls.md`

### 5. Connect clients and gateways

- [ ] OpenAI SDK, Claude Code, LiteLLM -> `references/litellm-and-clients.md`

### 6. Tear down

- [ ] Delete test gateways, revoke tokens, remove stored keys, stop auto top-up -> `references/teardown.md`

### 7. Troubleshoot

- [ ] `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: account, tokens, gateway creation, authentication, BYOK, Unified Billing, credential precedence.
- `references/endpoints-and-usage.md`: REST API, provider-native URLs, compat endpoint, Worker binding, request headers.
- `references/controls.md`: caching, rate limiting, spend limits, retries, timeouts, dynamic routing, guardrails, DLP.
- `references/observability.md`: logs, payload opt-out, custom metadata, custom costs, analytics.
- `references/litellm-and-clients.md`: OpenAI SDK, Claude Code, LiteLLM, AI SDK.
- `references/teardown.md`: delete and revoke.
- `references/troubleshooting.md`: symptom to fix.

## Companion skills

- `llm-gateway`: gateway design across products. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `litellm`: self-hosted proxy, can sit behind or in front of AI Gateway. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `cloudflare-tunnel`: expose your own model servers. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloudflare-tunnel`.
- `llm-observability`: wider tracing and cost checks. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
- `cloud-llms`: provider choice. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
