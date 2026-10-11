# Together AI limits and spend controls

> Verified against Together docs: Spend controls, Credits, Authentication, Serverless rate limits, Manage endpoints and deployments (GPU quota troubleshooting), Cost analytics, 2026-10-11

## Rate limits

- Serverless is best-effort. The docs do not publish fixed numeric limits for self-serve accounts; high volume or bursts can return `429 Too Many Requests` or `503 Service Unavailable`. Back off exponentially and spread requests out.
- Enterprise and Scale contracts keep purchased limits until the contract ends. Hot models can carry custom limits.
- Committed throughput comes from provisioned throughput (contact sales) or dedicated endpoints, which are not rate limited like serverless.
- Batch jobs have a separate pool: see `batch-and-finetuning.md` for documented caps.

## Spend controls that exist

| Control                      | Notes                                                                                                                                                                               |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hard cut-off at zero balance | Prepaid accounts. API access stops at zero and resumes after adding credits. Metering lags, so usage can land after zero and you remain responsible for it. It is not an exact cap. |
| In-arrears cut-off           | Qualifying contracted enterprise accounts, agreed negative balance.                                                                                                                 |
| Auto-recharge                | Buys credits below a threshold. It keeps buying as you consume, so it does not cap spend. Needs a card as the default payment method; an ACH default turns it off.                  |
| Serverless access off        | Contracted accounts, via the solutions architect.                                                                                                                                   |

As of the docs read on 2026-10-11, organization and project budgets and spend alerts are listed as "coming soon". They are not available to configure. API keys have no independent spend or rate limits.

Practical setup:

- Keep auto-recharge off for experiments and add credits manually. The zero-balance cut-off affects every project in the organization, including production.
- One project per environment or workload, named keys per service. Projects share the organization's balance; they do not get separate caps.
- Dedicated endpoints and fine-tune jobs need sufficient balance to be created and keep billing until stopped or finished. Use `--inactive-timeout` and delete when done.

## Cost visibility

- Cost analytics in the console groups usage by product, line item, project or API key (project and API key grouping are in beta). Start at organization level, group by project, then drill into the key.
- `api_key_id` is supported for inference requests, so spend can be attributed per key.
- Billing usage API: `GET /v1/billing/usage` returns cost-annotated line items. It is beta and needs access enabled by support. Send `organization_id`. Current-month data can lag up to 1 hour, prior months up to 24 hours (UTC).
- The projects list and analytics can be inaccurate for projects running legacy v1 dedicated endpoints.

## GPU quota (dedicated endpoints)

Deploy or update can fail with `GPU quota exceeded` (HTTP 429), naming the GPU type and the would-be total against the limit. Lower the replica count, stop unused deployments on that GPU type, or contact support to raise the limit. If the platform itself is out of capacity (`GPU quota exceeded for H100`), retry later or contact support. Capacity shortfalls show as `DEGRADED` with `Cannot place replicas: insufficient GPU capacity`; the scheduler keeps retrying.

## Check before you deploy

```bash
tg beta endpoints ls              # what already bills
tg beta models configs <model>    # hardware per profile
```

Then look up the hardware rate on the Pricing page and multiply by `--max-replicas` for the worst case. `maxReplicas` is the ceiling on cost; `minReplicas` is the floor.

## Sources

- https://docs.together.ai/docs/billing-spend-controls
- https://docs.together.ai/docs/billing-credits
- https://docs.together.ai/docs/billing-cost-analytics
- https://docs.together.ai/docs/serverless/rate-limits
- https://docs.together.ai/docs/dedicated-endpoints/pricing
