# Groq limits and spend

> Verified against GroqDocs: Rate Limits, Spend Limits, Model Permissions, Projects, Billing FAQs, Your Data, Service Tiers, 2026-10-11

## Rate limits

- Measured as RPM, RPD, TPM, TPD, plus audio seconds per hour and per day (ASH, ASD); some organizations also have separate input and output token limits (ITPM, OTPM).
- Limits apply per organization, per model. You hit whichever threshold comes first. Cached tokens do not count.
- Exact values for your org are on https://console.groq.com/settings/limits. Do not hardcode numbers; the docs say the published table is a summary with exceptions. Paid plans raise limits; Enterprise can negotiate more.
- Project-level custom limits are set per model in a project (`projects`), within the organization limits.
- Headers on every response: `x-ratelimit-limit-requests` and `x-ratelimit-remaining-requests` (these two refer to requests per day), `x-ratelimit-limit-tokens` and `x-ratelimit-remaining-tokens` (tokens per minute), matching `x-ratelimit-reset-*`. `retry-after` (seconds) appears only on a 429.

```bash
curl -si https://api.groq.com/openai/v1/models -H "Authorization: Bearer $GROQ_API_KEY" | rg -i '^x-ratelimit'
```

Back off by `retry-after`. Batch and flex run against separate, higher limits.

## Spend limits

- Console: Settings, Billing, Limits (https://console.groq.com/settings/billing/limits). Requires a paid plan and organization owner permission.
- Monthly USD cap, resets on the 1st. Applies to the whole organization, all keys and endpoints; no per-key, daily or weekly limits.
- When reached, new requests fail with HTTP 400 and error code `blocked_api_access`; in-flight requests finish. Spend updates every 10 to 15 minutes, so a small overshoot is possible.
- Recovery: raise or remove the limit (immediate) or wait for the 1st.
- Alerts: add email thresholds (the docs suggest 50%, 75% and 90%). Billing emails: Settings, Billing, Manage.
- Docs suggest setting the first limit 20 to 30 percent above expected usage.
- No API for these controls appears in the docs read; set them in the console.

## Billing model

Monthly invoice in arrears, with progressive billing thresholds for new Developer-plan users (the thresholds are listed in the Billing FAQs and differ for India). Downgrading to Free issues a final invoice. Pricing: https://groq.com/pricing. Batch has a documented discount; flex matches on-demand pricing.

## Model permissions

Console: https://console.groq.com/settings/limits (organization) and https://console.groq.com/settings/project/limits (project). Strategies: "Only Allow" (everything else blocked) or "Only Block". Organization permissions cascade; projects can only narrow them. Owners configure organization level; Developer or Owner configure project level. A blocked model returns 403.

## Data controls

https://console.groq.com/settings/data-controls. Defaults: inference logs up to 30 days for reliability and abuse monitoring (opt out possible). Zero Data Retention disables features that need retention (batch, fine-tuning). Data is stored in US GCP buckets. Controls are organization-wide.

## Cost levers

- Use the smallest model that passes your evals (`llm-evals`).
- Put stable prompt prefixes first for caching on supported models.
- Use Batch for offline work, flex for tolerant high-volume work.
- Cap `max_completion_tokens`.
- For per-request attribution use a gateway (`llm-gateway`, `llm-observability`).

## Sources

- https://console.groq.com/docs/rate-limits
- https://console.groq.com/docs/spend-limits
- https://console.groq.com/docs/model-permissions
- https://console.groq.com/docs/projects
- https://console.groq.com/docs/billing-faqs
- https://console.groq.com/docs/your-data
