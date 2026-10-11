# Gemini API: tiers, rate limits, billing plans and spend caps

> Verified against Gemini API docs: Rate limits, Billing, 2026-10-11

## Where to see your limits (do not copy numbers)

- AI Studio: Dashboard > Projects (tier and billing plan), Usage, Spend (monthly cap), Billing. Active rate limits per model are shown in AI Studio ("View your active rate limits").
- Rate limits are measured as requests per minute (RPM), input tokens per minute (TPM) and requests per day (RPD); some models add images per minute or tokens per day. Limits apply **per project, not per key**. RPD resets at midnight Pacific time. Preview and experimental models are more restricted. Limits are not guaranteed.
- Priority inference has its own limits (a fraction of the standard limit per the docs); Batch API has separate limits (concurrent jobs, file size, storage, enqueued tokens per model).

## Usage tiers

Tiers are set by billing history and apply at the billing-account level: Free (active project), Tier 1 (billing account linked), Tier 2 and Tier 3 (cumulative paid amounts plus days since first successful payment; thresholds and billing-tier caps are on the billing and rate-limits pages). Upgrades from Free to Tier 1 are usually instant; later upgrades take effect within about 10 minutes. Request an increase through the link on the rate-limits page; no guarantee.

## Spend-based rate limit

Paid tiers also have a rolling 10-minute spend limit (amounts per tier are on the rate-limits page). Hitting it returns `429 RESOURCE_EXHAUSTED`: wait, reduce expensive requests, or request an increase.

## Billing plans

| Plan    | How it works                                                                                                              |
| ------- | ------------------------------------------------------------------------------------------------------------------------- |
| Prepay  | Buy credits first; usage deducted in near real time; credits expire after 12 months; refunds only on switching to Postpay |
| Postpay | Costs accrue and are charged at month end or at a tier-based spend cap                                                    |

- New users default to Prepay (minimum purchase and maximum balance are on the billing page). Invoiced or offline accounts get neither Prepay nor spend caps.
- **At a zero Prepay balance every key in every project on the billing account stops with HTTP `402 Payment Required`** until credits are added. Overage is possible during the roughly 10-minute billing latency; batch and agent jobs can run beyond the balance.
- Auto-reload tops up automatically; set the **monthly auto-charge limit** (AI Studio Billing > Manage auto-reload > Monthly limit) to bound reloads.
- Google Cloud credits eligible for Gemini API are consumed before Prepay credits once a Prepay balance exists.

## Spend caps

- **Project spend cap** (experimental): AI Studio > Spend > Monthly spend cap > Edit; needs project editor, owner or admin roles. Overages occur for about 10 minutes of lag, and long-running batch or agent sessions can exceed the cap. Moving a project to another billing account keeps its cap but resets accumulated spend.
- **Billing-account tier caps**: each tier has a monthly maximum.
- Set billing alerts in the Cloud console too (the key docs recommend it).

## Checklist before traffic

- [ ] Billing plan chosen; auto-reload and monthly auto-charge limit set (Prepay) or tier cap understood (Postpay)
- [ ] Project spend cap set per project
- [ ] Cloud billing alerts configured
- [ ] Retries: backoff on 429, 408 and 5xx; never on 400, 402 or 403
- [ ] Prices: read https://ai.google.dev/gemini-api/docs/pricing; never hardcode

## Where to read more

- https://ai.google.dev/gemini-api/docs/rate-limits
- https://ai.google.dev/gemini-api/docs/billing
- https://ai.google.dev/gemini-api/docs/pricing
