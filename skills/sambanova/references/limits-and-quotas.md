# SambaNova limits and quotas

> Verified against SambaNova docs (Model rate limits, API error codes, Billing mention), 2026-10-11

## Model

- Measured per user in requests per minute (RPM), requests per day (RPD) and, on the Free tier only, tokens per day (TPD). Hitting either request limit returns 429.
- Tiers: **Free** (no payment method), **Developer** (payment method linked), higher access through sales. Limits are per model and differ between Production and Preview models.
- Developer tier accounts also have a daily token ceiling across all models (documented as 20M tokens per day on 2026-10-11).
- SambaStack: limits are optional and set by the admin per user group.

The per-model numbers change; read them at https://docs.sambanova.ai/docs/en/models/rate-limits.md. On 2026-10-11 Free tier was a few requests per day per model with a TPD cap, and Developer tier was in the tens to hundreds of RPM depending on the model. Do not hardcode those figures; read the page or the response headers.

## Response headers

Every response carries limit state. Print them without printing the key:

```bash
curl -sS -D - -o /dev/null https://api.sambanova.ai/v1/chat/completions \
  -H "Authorization: Bearer $SAMBANOVA_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"gpt-oss-120b","messages":[{"role":"user","content":"ok"}],"max_tokens":1}' \
  | grep -i '^x-ratelimit'
```

Headers: `x-ratelimit-limit-requests`, `x-ratelimit-remaining-requests`, `x-ratelimit-reset-requests` (per minute) and the `-day` variants (`x-ratelimit-limit-requests-day`, ...) per day.

## 429 variants

- `insufficient_quota`: you hit the tier limit. Slow down or move to a higher tier.
- `queue_full`: too many requests in flight on the service; the server declined. Retry after a short delay or reduce concurrency.

## Spend control

No hard spend cap or budget alert is documented on the pages read. Unverified: check the Billing page in the portal. Practical controls: gateway-side budgets and RPM caps (`llm-gateway`, `litellm`), one key per app, and the request-count ceilings above.

## Raising limits

Contact the SambaNova sales team (the rate-limit page points there). Retired models may be available on SambaStack.

## Official links

- Rate limits: https://docs.sambanova.ai/docs/en/models/rate-limits.md
- Error codes: https://docs.sambanova.ai/docs/en/api-reference/using-the-api/api-error-codes.md
