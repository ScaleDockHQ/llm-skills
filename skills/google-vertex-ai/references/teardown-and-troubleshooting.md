# Teardown and troubleshooting

> Verified against Agent Platform docs (Undeploy a model and delete the endpoint, Use models in Model Garden, Error code 429, Standard PayGo), Cloud Billing and Resource Manager docs (gcloud billing projects unlink, Delete and restore projects, disable billing), Service Usage (enable and disable services), 2026-10-11

## What bills

- Deployed models on endpoints (replica-hours, including idle replicas).
- Provisioned Throughput orders (a commitment; manage in the console, cancel only per its terms).
- Batch jobs while running; tokens for online calls.
- Storage: Cloud Storage and BigQuery data used for batch, logging tables, model artifacts.
- Anything in the project besides AI: forwarding rules and static IPs for PSC, Cloud Run kill-switch functions, Pub/Sub topics.

## Teardown order

Ask before deleting. Prefer an inventory first.

```bash
P=$PROJECT_ID
for R in us-central1 europe-west4; do   # every region you used
  echo "== $R"
  gcloud ai endpoints list --project="$P" --region="$R"
  gcloud ai models list --project="$P" --region="$R"
  gcloud ai batch-prediction-jobs list --project="$P" --region="$R" 2>/dev/null
done
```

1. **Undeploy** each deployed model (required before deleting the endpoint or model):

```bash
gcloud ai endpoints describe ENDPOINT_ID --project="$P" --region="$R"     # find deployedModels[].id
gcloud ai endpoints undeploy-model ENDPOINT_ID --project="$P" --region="$R" \
  --deployed-model-id=DEPLOYED_MODEL_ID
```

2. **Delete endpoints** and uploaded **models**:

```bash
gcloud ai endpoints delete ENDPOINT_ID --project="$P" --region="$R"
gcloud ai models delete MODEL_ID --project="$P" --region="$R"
```

3. **Batch jobs**: running jobs bill. Cancel from the console or `batchPredictionJobs.cancel` (REST); `gcloud ai batch-prediction-jobs` exists for list, but confirm the cancel subcommand with `--help`. Delete job output tables and buckets you no longer need.
4. **PSC and network**: delete forwarding rules (`gcloud compute forwarding-rules delete`) and reserved IPs created for endpoints.
5. **Provisioned Throughput**: review orders in the console; they are commitments and may not be cancelable mid-term.
6. **Budgets and kill-switches**: `gcloud billing budgets list --billing-account=...`, delete budgets you created, and the Cloud Run function and Pub/Sub topic.
7. **Credentials**: remove ADC you created (`gcloud auth application-default revoke`), delete service accounts and any keys, remove IAM bindings you added.
8. **Disable the API** (optional, stops the API but does not delete resources, so do it only after steps 1-4): `gcloud services disable aiplatform.googleapis.com --project="$P"`.
9. **Nuclear option for a dedicated project**: `gcloud billing projects unlink "$P"` (stops billable services and your app; costs already accrued remain), then `gcloud projects delete "$P"`. Deletion starts a 30-day `DELETE_REQUESTED` window; restore with `gcloud projects undelete`. You cannot disable billing on a project with active committed-use discounts.

**Verify nothing still accrues:** the endpoint lists above are empty in every region; `gcloud ai models list` is empty; the billing report for the project (console Billing > Reports, filter by service) shows no new Agent Platform or Compute charges the next day; batch job lists show no `JOB_STATE_RUNNING`.

## Troubleshooting

| Symptom                                                        | Cause                                                                                                     | Fix                                                                                                             |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 429 `Resource exhausted, please try again later.`              | Shared PayGo capacity contention, not necessarily a fixed quota                                           | Use the global endpoint, backoff with jitter, smooth traffic, consider Priority PayGo or Provisioned Throughput |
| 429 `Too many requests. Exceeded the Provisioned Throughput.`  | Over your PT order in dedicated-only mode                                                                 | Raise GSUs or allow spillover by not setting the dedicated header                                               |
| 403 `PERMISSION_DENIED` on `aiplatform.endpoints.predict`      | Caller lacks `roles/aiplatform.user`, wrong project, or API not enabled                                   | `gcloud config list`, `gcloud services list --enabled --filter=name:aiplatform.googleapis.com`, grant the role  |
| 403 or "API has not been used in project" / quotas page empty  | `aiplatform.googleapis.com` not enabled                                                                   | Enable the API, wait, retry                                                                                     |
| Claude call fails with an entitlement or procurement error     | Model not enabled in Model Garden, or org policy blocks `cloudcommerceconsumerprocurement.googleapis.com` | Enable the model card (Consumer Procurement Entitlement Manager role), allow the API in org policy              |
| 404 model not found                                            | Model ID, version or location mismatch; model not offered in that location                                | Check the models page and locations table; try `global`                                                         |
| OpenAI client works for an hour then 401                       | OAuth access token expired (1 hour)                                                                       | Refresh the ADC token programmatically                                                                          |
| Empty text with `finishReason: MAX_TOKENS` on a thinking model | Output cap consumed by thinking tokens                                                                    | Remove or raise `maxOutputTokens` / `max_tokens`                                                                |
| Undeploy or delete fails                                       | Model still deployed or endpoint has traffic                                                              | Undeploy first, then delete the endpoint and model                                                              |
| Model Garden deploy fails for capacity or quota                | No GPU quota or no stock in region                                                                        | Check GPU quota, try another region or reservation                                                              |
| Old docs say "Vertex AI" and commands differ from your memory  | Rename                                                                                                    | Same product; confirm commands with `gcloud ai ... --help`                                                      |

Cross-provider cost and quota habits: `cloud-llms`. Gateway-level retries, fallbacks and budgets: `llm-gateway`.

## Sources

- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/predictions/undeploy-model
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/model-garden/use-models
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/deploy/error-code-429
- https://docs.cloud.google.com/resource-manager/docs/delete-restore-projects
- https://docs.cloud.google.com/billing/docs/how-to/modify-project
- https://cloud.google.com/sdk/gcloud/reference/billing/projects/unlink
- https://docs.cloud.google.com/service-usage/docs/enable-disable
