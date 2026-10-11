# Controls: caching, limits, retries and routing

> Verified against Cloudflare AI Gateway docs (changelog through 2026-10-06), 2026-10-11

Sources: features/caching, features/rate-limiting, features/spend-limits, features/dynamic-routing, configuration/manage-gateway, configuration/request-handling, features/guardrails, features/dlp under <https://developers.cloudflare.com/ai-gateway/>.

## Caching

Off by default. Text and image responses only, and only for identical requests. The default key is a SHA-256 over provider, endpoint, model, the provider authentication header and the full body, so any change (messages, tools, parameters) is a new entry. Enable globally in Settings > Cache Responses (or `cache_ttl` on create/update), or per request with `cf-aig-cache-key` plus optional `cf-aig-cache-ttl` (minimum 60 s, maximum one month). Pick a custom key that groups only requests with equivalent responses; sharing a key across different prompts serves wrong answers. Bypass with `cf-aig-skip-cache: true`. Semantic caching is not offered (docs say it is planned). Confirm with the `cf-aig-cache-status` response header.

## Rate limiting

Requests per time window with a fixed or sliding technique, set per gateway (`rate_limiting_interval`, `rate_limiting_limit`, `rate_limiting_technique`). Over-limit requests get `429`. It limits request count, not cost.

## Spend limits

Dollar budgets over rolling or fixed windows, up to 20 rules per gateway, for Unified Billing and BYOK requests on models with known pricing. Scope each rule by provider, model or a custom metadata key, either **split by value** (a bucket per value) or **filter by value** (applies only to one value). Over-budget requests get `429`. Enforcement is eventually consistent: the request's cost is recorded after it finishes, so bursts can overshoot. Per-user budgets use `cf.user_id` (Access-protected custom domain) or your own metadata such as `user_id` sent in `cf-aig-metadata`.

```bash
curl -sS -X POST "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/ai/v1/chat/completions" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
  -H 'cf-aig-metadata: {"user_id":"u-123","env":"staging"}' \
  -d '{"model":"openai/<model>","messages":[{"role":"user","content":"ping"}],"max_tokens":16}' >/dev/null
```

## Retries and timeouts

Gateway-level retries (Settings > Retry Requests): up to 5 attempts, base delay 0.1 to 60 s, backoff constant, linear or exponential. Per request on provider endpoints use `cf-aig-max-attempts`, `cf-aig-retry-delay`, `cf-aig-backoff`. `cf-aig-request-timeout` (ms) measures time to first byte; a stream that starts in time is not cut. The final attempt waits for completion however long it takes. Cross-provider failover needs dynamic routing.

## Dynamic routing

A named, versioned flow used as `model: dynamic/<route>`. Nodes: Start, Conditional (on body, headers or metadata), Percentage (A/B and rollouts), Model, Rate Limit, Budget Limit, End. Create under gateway > Dynamic Routes, save a version, deploy it, roll back from Versions. Prerequisites in the docs: authenticated gateway and BYOK keys stored for the upstream providers. Pass metadata (for example plan or org) so conditions can use it. Call it through REST (with `cf-aig-gateway-id`), the binding or the compat endpoint.

## Guardrails and DLP

Guardrails screen prompts and responses against content categories with flag or block actions, and DLP policies detect sensitive data and log or block it. Both write to logs and add latency; read `features/guardrails` and `features/dlp` for supported model types and limits before enabling, and ask the user first.
