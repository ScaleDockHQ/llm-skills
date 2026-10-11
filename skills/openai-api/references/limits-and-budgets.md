# OpenAI API: limits, tiers and spend controls

> Verified against OpenAI docs: Rate limits, Spend limits, Admin APIs guide, Production best practices, 2026-10-11

## Where to see your limits (do not copy numbers)

- Console: Settings > Organization > Limits shows rate limits per model at your tier, shared limits across model families and the long-context limits for models that have them.
- Response headers on generation requests: `x-ratelimit-limit-requests`, `x-ratelimit-limit-tokens`, `x-ratelimit-remaining-requests`, `x-ratelimit-remaining-tokens`, `x-ratelimit-reset-requests`, `x-ratelimit-reset-tokens`, and project-scoped `x-ratelimit-*-project-tokens` when a project token limit applies. `Retry-After` can accompany `429` and `503`.
- Fine-tuning limits: `GET /v1/fine_tuning/model_limits`.

```bash
# Show rate-limit headers from a tiny, billable call (ask first)
curl -sS -D - -o /dev/null https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d "$(jq -n --arg m "$OPENAI_MODEL" '{model:$m,input:"hi",max_output_tokens:16}')" | grep -i -E '^(x-ratelimit|retry-after)'
```

## How limits work

- Metrics: RPM, RPD, TPM, TPD, IPM (images) and audio minutes per minute for some streaming audio models. You can hit any of them first.
- Defined per organization and per project, and vary by model. Some model families share one limit.
- Batch API queue limits count queued input tokens per model; completed batch tokens stop counting.
- Vector store ingestion is rate limited per vector store ID; for large ingests prefer the file-batches endpoint.
- Usage tiers: Free, then paid Build, Launch and Grow. The organization moves up automatically as total credit purchases reach thresholds, and each tier has a monthly usage limit. Thresholds are on the rate-limits page; read them there.
- OpenAI also sets an **approved monthly usage limit** per organization, separate from the spend limits you configure.

## Ramp rules (the `slow_down` error)

- `429` with code `slow_down` means traffic rose too fast, even when within RPM and TPM. `503` with `server_is_overloaded` means the model is temporarily overloaded.
- Rule of thumb from the docs: once you reach about 1 million input tokens per minute, increase traffic by no more than 50% every 15 minutes (varies by model).
- Follow `Retry-After` (a minimum), add jitter, cap attempts and total retry time, and do not retry quota or billing errors. Official SDKs retry eligible `429` and `503` automatically; avoid nested retry loops by disabling one layer.
- Handle both `429` and `503` in SDK error handlers (`RateLimitError` and `InternalServerError` in Python and TypeScript).
- Enterprise capacity options (Scale Tier, Reserved Tier for GPT-5.6 and later) exist for predictable capacity; ask OpenAI sales, the handling of `slow_down` stays the same.

## Spend controls

| Control          | Effect at the amount                 | Use                                  |
| ---------------- | ------------------------------------ | ------------------------------------ |
| Spend alert      | Notification only; traffic continues | Early warning                        |
| Hard spend limit | Affected requests return `429`       | Enforce a monthly org or project cap |

- Set them in the console: Organization limits > Spend > Edit spend limit (monthly amount, then **Enforce a hard limit**), or Project settings > Limits.
- An organization hard limit covers all projects; a project hard limit covers that project only. Enforcement is not instantaneous, so recorded spend can slightly exceed the cap.
- Raising or removing the limit resumes traffic after it propagates; otherwise it resets next month.

Set an organization hard limit with the Admin API (amount in cents):

```bash
curl -sS -X POST https://api.openai.com/v1/organization/spend_limit \
  -H "Authorization: Bearer $OPENAI_ADMIN_KEY" -H "Content-Type: application/json" \
  -d '{"threshold_amount": 10000, "currency": "USD", "interval": "month"}'   # example: 100 USD per month
```

Project spend alerts are available through the Admin API (amounts in cents); read the Admin APIs guide for the current endpoint and SDK method. Combine with a gateway budget (`llm-gateway`) so per-team caps exist as well.

## Restoring traffic

Check `error.code`:

- `organization_spend_limit_exceeded` or `project_spend_limit_exceeded`: raise or remove the limit, or wait for the monthly reset.
- `organization_usage_limit_exceeded`: request a higher approved usage limit.
- `credit_balance_exhausted`: add credits.
- Request or token rate-limit codes: follow the ramp rules above.

## Cost control checklist

- [ ] Alert and hard limit set per project before traffic.
- [ ] `max_output_tokens` set; stream only where it helps.
- [ ] Batch for non-interactive work; cache-friendly prompt layout.
- [ ] Smaller model for easy tasks, verified with evals (`llm-evals`).
- [ ] Look prices up on the API pricing page linked from the OpenAI docs; never hardcode them.

## Where to read more

- https://developers.openai.com/api/docs/guides/rate-limits
- https://developers.openai.com/api/docs/guides/spend-limits
- https://developers.openai.com/api/docs/guides/admin-apis
