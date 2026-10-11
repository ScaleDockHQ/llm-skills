# CoreWeave: limits, quotas and billing

> Verified against CoreWeave docs: Usage information and limits (Serverless), Dedicated Inference Billing and Scaling, Create a Node Pool (quotas), Spot Node Pools, release notes on Billing insights (2026-04-20) and FOCUS usage export API (2026-09-11), 2026-10-11

| Product              | Billing basis                                                                      | Limits and caps                                                                    | Where to see them                                                             |
| -------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Serverless Inference | Per token, prepaid credits                                                         | Concurrency per project and per user; default spend caps by tier                   | Forge Billing page; usage-limits doc; `429` and `402` errors                  |
| Dedicated Inference  | GPU-hour (on demand) or node-based for reserved nodes                              | Inference GPU quota per org and instance type; no scale-to-zero (`min` at least 1) | Support ticket for quota; `cwic inference deployment parameters`; Billing doc |
| Capacity claims      | GPU-hour while the claim exists, even idle                                         | Availability in the zone                                                           | Terraform `coreweave_inference_capacity_claim` and API                        |
| CKS Node Pools       | Compute billing by instance, reservations apply; spot is pay-as-you-go preemptible | Quota per instance type, compute class and zone                                    | `kubectl get nodepool` (QUOTA column), `kubectl describe nodepool`            |

## Check quota before creating

- CKS: apply the Node Pool with a small `targetNodes` first; `kubectl get nodepool` shows `CAPACITY` (for example `Sufficient`, `QueuedAwaitingCapacity`) and `QUOTA` (`Under` or `Over`). The pool is filled only up to quota. Contact your CoreWeave representative to change quota.
- Dedicated Inference: the first deployment fails with `organization has no GPU quota for it` if quota is missing.
- Serverless: tier caps in the docs on 2026-10-11 were Free 100 USD per month, Pro 6,000 USD per month, Enterprise 700,000 USD per year; re-read the page and request changes through your account executive or Forge support.

## Budget controls

- Serverless: the tier spending cap is the hard stop; keep prepaid balance low for experiments; rate-limit in LiteLLM.
- Dedicated: keep `min` and `max` low, avoid capacity claims for experiments, and delete the deployment when idle since it cannot scale to zero.
- CKS: set `targetNodes` to the minimum, use `autoscaling` with a `maxNodes` ceiling, prefer spot only for interruptible work, and delete empty Node Pools.
- Always keep a teardown reminder; no documented hard monthly cap exists for CKS or Dedicated. Unverified: ask your account team about spend alerts.

## See spend

- Cloud Console: Billing insights page (billable usage, measured usage and exclusions by resource type, added April 2026) and the Usage by Product and Zone Grafana dashboard.
- FOCUS usage export API (public preview, September 2026) exports hourly usage in FOCUS JSON or CSV; read the release note before using it.
- Serverless: Forge Billing page.

Prices: use the CoreWeave pricing page and the Available models page; do not hardcode rates.

## Sources

- https://docs.coreweave.com/products/inference/serverless/usage-limits
- https://docs.coreweave.com/products/inference/billing
- https://docs.coreweave.com/products/inference/scaling
- https://docs.coreweave.com/products/cks/nodes/create
- https://docs.coreweave.com/release-notes/billing-insights
- https://docs.coreweave.com/release-notes/focus-export-api
