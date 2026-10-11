# Fireworks AI limits and spend controls

> Verified against Fireworks docs: Account quotas, Serverless Rate Limits, Reserved Throughput, Spend Limits (Nexus per-user limits), firectl quota list and quota update pages, 2026-10-11

## See your limits

```bash
firectl quota list        # rate limits, GPU quotas, spend limit and usage, serverless and on-demand
```

Your current per-model serverless limits are also on the Serverless dashboard: https://app.fireworks.ai/dashboard/serverless. REST equivalents: List Quotas, Get Quota, Update Quota in the API reference.

## Serverless rate limits (adaptive)

- Three metrics, each with its own limit, all in tokens per minute: total prompt TPM (cached plus uncached), uncached prompt TPM, and generated TPM.
- Limits are **adaptive**: they start at a default and grow in steps when usage stays above half the current limit (increase of 25%, at most once every 15 minutes) up to a ceiling, then shrink slowly when unused, and reset after 72 hours without traffic. Ramp traffic gradually; a sudden jump produces 429s.
- The ceiling depends on **model size tier** (small, medium, large by total parameters) and your **spending tier**. The table of ceilings is on https://docs.fireworks.ai/serverless/rate-limits; read it there rather than copying numbers.
- `429 Too Many Requests` means you exceeded an adaptive limit. `503 Service Overloaded` is load shedding; Priority tier makes it less likely (`service_tier: "priority"`, see `serverless-api.md`).
- Reserved Throughput adds a reserved amount on top of the adaptive limit: https://docs.fireworks.ai/serverless/reserved-throughput.

## Account-wide request limits

All API usage shares one request-rate envelope. Per the docs, accounts without a payment method or credits have a very low request rate, and funded accounts have a fixed account-wide ceiling that is not adaptive. The exact RPM values are on https://docs.fireworks.ai/guides/quotas_usage/account-quotas; `firectl quota list` shows what applies to you.

## Spending tiers

Tiers (1 to 4, then unlimited by contact) unlock higher quotas and serverless ceilings by adding credits or spending. For legacy self-serve postpaid accounts the tier also caps the monthly spend limit. Prepaid accounts can set a limit independently of tier. Criteria and amounts: the Account quotas page.

## Monthly spend limit (the hard guardrail)

```bash
firectl quota list
firectl quota update monthly-spend-usd --value <AMOUNT_USD>
```

- Warning email at 80% of the limit by default; add other amounts on the Billing page.
- At 100% **all API requests pause**: serverless inference, deployments and training. Raise the limit to resume; if credits are also depleted, add credits.
- Adding credits does not raise or reset the limit. Auto Reload buys credits when the balance is low and does not change the limit.
- Enterprise accounts get informational spend alerts that do not pause service.

## Per-user limits (Nexus)

Per-user spend caps on supported serverless models exist on request (account default, group limit, user override; groups come from SCIM-synced identity providers; at most 9 group limits). They are per user, not shared budgets. See https://docs.fireworks.ai/nexus/usage-limits.

## On-demand GPU quotas

On-demand deployments use GPU quota per GPU type and placement, not rate limits. Defaults and per-placement values are in the Account quotas and Regions pages and in `firectl quota list`. Request more via https://fireworks.ai/company/contact-us. Training jobs use a separate training GPU quota that requires a payment method; a job rejected with HTTP 403 `quota_exceeded` or `tier_required` needs a payment method or freed GPUs.

## Cost visibility

Usage and billing exports: https://docs.fireworks.ai/accounts/exporting-billing-metrics, https://docs.fireworks.ai/accounts/exporting-usage-costs and the Usage and Cost Breakdown page. REST: Get Account Usage, billing summary, Query Usage Costs.

## Practical setup

1. Set `monthly-spend-usd` to a figure 20 to 30% above expected use.
2. Use scale-to-zero and a low `--max-replica-count` on every deployment.
3. One service account and key per workload, with expiry for test keys.
4. Check `firectl deployment list` as part of every session that may have started GPUs.

## Sources

- https://docs.fireworks.ai/guides/quotas_usage/account-quotas
- https://docs.fireworks.ai/serverless/rate-limits
- https://docs.fireworks.ai/serverless/reserved-throughput
- https://docs.fireworks.ai/nexus/usage-limits
- https://docs.fireworks.ai/tools-sdks/firectl/commands/quota-update
