# OpenRouter routing and fallbacks

> Verified against OpenRouter API v1 (docs: routing/provider-selection, routing/model-fallbacks, routing/routers/auto-router, routing/model-variants), 2026-10-11

## Default behavior

Per model, OpenRouter load balances across providers: it first prefers providers without significant outages in the last 30 seconds, then picks among the lowest-cost candidates weighted by the inverse square of price, and keeps the rest as fallbacks. Requests with `tools` or `max_tokens` are routed only to providers that support them (best effort). Setting `sort` or `order` disables this load balancing.

## The `provider` object

| Field                                               | Default   | Purpose                                                      |
| --------------------------------------------------- | --------- | ------------------------------------------------------------ |
| `order`                                             | none      | Provider slugs to try in order                               |
| `only` / `ignore`                                   | none      | Allow or skip provider slugs for this request                |
| `allow_fallbacks`                                   | `true`    | Allow backup providers when the preferred one fails          |
| `require_parameters`                                | `false`   | Only providers that support every parameter in the request   |
| `data_collection`                                   | `"allow"` | `"deny"` excludes providers that may store data              |
| `zdr`                                               | unset     | Restrict to Zero Data Retention endpoints                    |
| `enforce_distillable_text`                          | unset     | Only models that allow text distillation                     |
| `quantizations`                                     | none      | For example `["int4","int8"]`                                |
| `sort`                                              | none      | `"price"`, `"throughput"`, `"latency"`, or `{by, partition}` |
| `preferred_min_throughput`, `preferred_max_latency` | none      | Soft thresholds, number or percentile object (p50 to p99)    |
| `max_price`                                         | none      | Maximum pricing you accept for the request                   |

Example, predictable and strict:

```bash
curl -fsS https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"<author>/<slug>","messages":[{"role":"user","content":"ping"}],
       "provider":{"order":["<provider-slug>"],"allow_fallbacks":false,"require_parameters":true,"data_collection":"deny"}}' \
  | jq '{model, provider, usage}'
```

Find provider slugs in the model's endpoints listing (`/api/v1/models/{author}/{slug}/endpoints`). With `allow_fallbacks: false` a provider outage is an error, which is correct for compliance pinning and wrong for availability.

Shortcuts: `:nitro` (throughput sort plus priority tier), `:floor` (price sort plus flex tier), `:exacto` (tool-calling quality sort). These change the billed rate when a tier endpoint serves the request; the response reports the tier.

## Model fallbacks

Send `models` as an ordered list. If the first model errors (context length validation, moderation flag, rate limit, downtime), the next is tried; if the last also fails you get that error. You are billed for the model that finally served the request, shown in the response `model` field.

```json
{
  "models": ["<primary-model>", "<backup-model>"],
  "messages": [{ "role": "user", "content": "hi" }]
}
```

With the OpenAI SDK pass `models` in `extra_body`. On `/api/v1/messages` use `fallbacks: [{"model": "..."}]` instead. Limits there: each entry accepts only `model`, at most 3 entries, and it cannot be combined with `models` (400 on violation). Because a fallback can be a different family, check tools, context and output format work on every entry.

## Routers

`openrouter/auto` classifies the prompt and picks a model from aggregate spend rankings, honoring account restrictions, guardrails, ZDR and any `allowed_models` setting; it can switch models between turns unless session stickiness holds the conversation to one. Good for exploration, poor for reproducible evaluation. Other routers (free, fusion, pareto and others) are documented under routing/routers; read the page before using one in production.

## Verify

- [ ] The response `model` and `provider` fields match the intent. Opt in to routing detail with the `X-OpenRouter-Metadata: enabled` header and read `openrouter_metadata`.
- [ ] A forced failure (invalid first model or `ignore` of the first provider) falls through as designed.
