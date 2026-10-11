# DeepInfra limits and spend control

> Verified against DeepInfra docs (Rate Limits, Authentication, Deploy Private Models, Custom LLMs, GPU Instances, API reference: Set Key Limit, Set Config, Usage), 2026-10-11

## Rate limit: concurrency, not RPM

- Default: **200 concurrent requests per model** per account. Two models in parallel can run 400 total.
- Throughput depends on request duration: shorter requests mean higher effective RPM.
- Over the limit: HTTP 429 with a `Rate limited` message. Retry after a short delay, slow down, or request an increase (Dashboard, Account; API: `request-rate-limit-increase`). A busy model can also return 429 below your limit while it autoscales; retry briefly.
- For batch-like loads use a token-bucket to stay below 200 concurrent requests, or use the Batch API, which does not touch real-time limits (extra batch limits in `api-and-compat.md`).

## Spend controls (set them before traffic)

| Control               | How                                                                                                                                                                                                                  |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Per-key monthly limit | `POST /payment/key-limits` with `{"token_id": "<id>", "limit": 25}` (USD per month). `null` or a negative number removes it; `0` blocks the key. `GET /payment/key-limits` lists limit and spend this month per key. |
| Account usage limit   | `POST /payment/config` with `{"limit": 100}` (USD; negative means no limit; unset means unchanged). `GET /payment/config` reads it. Also in Dashboard billing settings.                                              |
| Scoped JWT cap        | `spending_limit` when creating the JWT (`setup-and-auth.md`).                                                                                                                                                        |
| Gateway budgets       | LiteLLM budgets and RPM caps (`llm-gateway`, `litellm`).                                                                                                                                                             |

These billing routes show a `session` cookie parameter next to bearer security in the OpenAPI document. If a bearer key is rejected, set the limit in the Dashboard instead (https://deepinfra.com/dash/billing).

```bash
# list per-key limits and month-to-date spend
curl -sS https://api.deepinfra.com/payment/key-limits -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq .

# find token ids first
curl -sS https://api.deepinfra.com/v1/api-tokens -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq '.[] | {name, token_id, fragment}'
```

## Per-GPU-hour resources

Private deployments and GPU containers bill by the GPU-hour while running, independent of traffic. Deployments are invoiced weekly in a separate invoice. The docs warn a forgotten 2-GPU deployment over a weekend costs on the order of 256 USD at 2 USD per GPU-hour (their illustration). Private deployments are limited to 4 GPUs per user by default; contact DeepInfra for more.

## Usage and cost reporting

- Per response: `usage.estimated_cost`.
- API: `GET /payment/usage` (tokens and inference), `GET /payment/usage/rent` (rented GPU time), per-key usage routes (`usage-api-token`, `usage-api-token-by-id`), invoices (`list-invoices`). Check each page in the Billing section of the API reference for parameters.
- Dashboard: usage and billing pages.

## Official links

- Rate limits: https://docs.deepinfra.com/account/rate-limits.md
- Set key limit: https://docs.deepinfra.com/api-reference/billing/set-key-limit.md
- Private models: https://docs.deepinfra.com/private-models/overview.md
