# Quotas, consumption options and budgets

> Verified against Agent Platform docs (Generative AI quotas and system limits, Standard PayGo, Priority PayGo, Use Provisioned Throughput, Error code 429), Cloud Quotas (View and manage quotas), Cloud Billing docs (budgets, programmatic notifications, disable billing with notifications), gcloud billing budgets create reference, 2026-10-11

## See your limits (no numbers copied here)

- Console: IAM & Admin > **Quotas & System Limits**, filter Service = Agent Platform API (the API must be enabled or quotas do not show). Roles: Quota Viewer (`roles/servicemanagement.quotaViewer`) to read, Quota Administrator (`roles/servicemanagement.quotaAdmin`) to change.
- CLI: `gcloud quotas info ...` and `gcloud quotas preferences ...` (beta commands component may be needed). Cloud Quotas API for automation. Reference: https://docs.cloud.google.com/docs/quotas/view-manage
- Generative AI quota page lists metrics (for example `aiplatform.googleapis.com/global_embed_content_requests_per_minute_per_base_model`) and which ones cannot be raised from the console (multimodal input quotas: contact your account team): https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/quotas
- Tuned-model inference shares the base model quota. GPU quotas for self-deployed endpoints live in Compute-style quota entries per region; check before deploying.
- A quota override below the default caps usage on services that support overrides (see "Create a quota override" on the Cloud Quotas page).

## Consumption options for Gemini

| Option                 | What it is                                                                               | Notes                                                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Standard PayGo         | Shared capacity, no commitment. Usage tiers raise your baseline by rolling 30-day spend. | A 429 means contention on shared capacity, not a fixed quota.                                                            |
| Priority PayGo         | More consistent performance without commitment. Opt in per request with a header.        | Header `X-Vertex-AI-LLM-Shared-Request-Type: priority`; add `X-Vertex-AI-LLM-Request-Type: shared` to use only Priority. |
| Provisioned Throughput | Reserved throughput (GSUs). Overage spills to PayGo by default.                          | Set `X-Vertex-AI-LLM-Request-Type: shared` to bypass the order; `dedicated` mode returns 429 over quota.                 |
| Batch                  | 50% discount, asynchronous (see `api-and-models.md`).                                    | Shared pool; may queue.                                                                                                  |

Check which tier served a request: response `traffic_type` is `ON_DEMAND_PRIORITY` (priority) or `ON_DEMAND` (downgraded to Standard). Provisioned traffic shows a `request_type` dimension of `dedicated`, `spillover` or `shared` in metrics. Look up prices on the Agent Platform pricing page; do not hardcode them.

## 429 handling

Messages: `Resource exhausted, please try again later.` (PayGo) and `Too many requests. Exceeded the Provisioned Throughput.` (PT).

1. Use the **global** endpoint instead of a regional one. It routes to the region with capacity.
2. Retry with truncated exponential backoff and jitter.
3. Smooth traffic. Second-level spikes can throttle even when the per-minute average is under baseline.
4. If you need consistency: Priority PayGo, or Provisioned Throughput for assured capacity.
5. Request a quota increase only for quotas that are real fixed limits.

Capacity-related 429s without a Provisioned Throughput subscription do not count against the SLA error rate.

## Budgets and spend control

A Cloud Billing budget **alerts; it does not stop spending**. Notifications lag actual cost, so a kill-switch can still overshoot. Set the budget below funds you cannot lose.

```bash
# Alert budget scoped to one project, with Pub/Sub for automation
gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT_ID" \
  --display-name="llm-budget-$PROJECT_ID" \
  --budget-amount="$AMOUNT" \
  --filter-projects="projects/$PROJECT_ID" \
  --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0 \
  --notifications-rule-pubsub-topic="projects/$ADMIN_PROJECT/topics/budget-alerts"

gcloud billing budgets list --billing-account="$BILLING_ACCOUNT_ID"
```

- `--threshold-rule` can be repeated; `percent` is a 0.0 to 1.0 fraction (0.5 is 50%), and `basis=forecasted-spend` alerts on forecast. `--budget-amount` can include a currency such as `100.75USD`. The disable-billing tutorial's script shows `percent=100`; trust the gcloud reference above and check the budget in the console after creating it.
- Budget notifications reach Pub/Sub several times a day (at-least-once, possibly out of order).
- Optional kill-switch: a Cloud Run function subscribed to the topic unlinks the project from billing when cost exceeds the budget. That terminates **all** services in the project, including free-tier ones, and nothing can be restarted until billing is relinked. Only do this in a dedicated project. Docs: https://docs.cloud.google.com/billing/docs/how-to/disable-billing-with-notifications
- Per-key and per-team limits belong in the gateway (`llm-gateway`), not in Google budgets.
- Cost for idle endpoints is replica-hours: min replicas of 1 bills continuously.

## Sources

- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/quotas
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/deploy/error-code-429
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/deploy/standard-paygo
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/deploy/priority-paygo
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/provisioned-throughput/use-provisioned-throughput
- https://docs.cloud.google.com/docs/quotas/view-manage
- https://docs.cloud.google.com/billing/docs/how-to/budgets
- https://docs.cloud.google.com/sdk/gcloud/reference/billing/budgets/create
