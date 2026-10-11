# Quotas, 429s and budgets

> Verified against Microsoft Foundry docs (Manage Azure OpenAI quota, Foundry Models quotas and limits, Azure OpenAI quotas and limits, Troubleshoot common HTTP errors, Usages - List REST reference), Azure Cost Management (budget tutorial, budget scenario), `az consumption budget` CLI reference, 2026-10-11

## How quota works

- Quota is per **subscription, region, model and deployment type**, in tokens per minute (TPM); you assign TPM to each deployment from what remains. Deleting or shrinking another deployment frees TPM.
- Quota **tiers** now exist (Free Tier and Tiers 1 to 6). Quota rises automatically with usage; initial tier depends on current usage and your Microsoft relationship. Extra quota can still be requested through the quota form; approval depends on capacity.
- Non-OpenAI Foundry models have their own default TPM, RPM and concurrency limits; read the table in the quotas page rather than copying it.
- Reaching the TPM limit in a minute returns 429 until the counter resets. The enforcement uses estimated max tokens per request, so a large `max_tokens` can consume quota even if the answer is short.

## See usage and limits

```bash
# Per-region quota usage for the subscription (REST; same data as the portal Quotas page)
az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.CognitiveServices/locations/$LOCATION/usages?api-version=2025-06-01" \
  --query "value[].{name:name.value,current:currentValue,limit:limit}" -o table

# Usage for one account
az cognitiveservices account list-usage -n "$RESOURCE" -g "$RG" -o table

# Deployments and their capacity
az cognitiveservices account deployment list -n "$RESOURCE" -g "$RG" \
  --query '[].{name:name,sku:sku.name,cap:sku.capacity}' -o table
```

The usages list returns `currentValue`, `limit`, `nextResetTime`, `quotaPeriod`, `status` and `unit` per metric. ARM read calls are themselves throttled; avoid polling them in loops. Quotas and limits page: https://learn.microsoft.com/en-us/azure/foundry/openai/quotas-limits. Foundry Models page: https://learn.microsoft.com/en-us/azure/foundry/foundry-models/quotas-limits.

## 429 handling

Response headers on Azure OpenAI deployments: `x-ratelimit-limit-requests`, `x-ratelimit-limit-tokens`, `x-ratelimit-remaining-requests`, `x-ratelimit-remaining-tokens`, `x-ratelimit-reset-requests`, `x-ratelimit-reset-tokens`, and **`retry-after-ms`** on 429s.

1. Wait the `retry-after-ms` value, then exponential backoff with jitter.
2. Lower `max_tokens` to what you need.
3. Spread load: another region or deployment (gateway load balancing, `llm-gateway`), or a data-zone or global type with higher quota.
4. Request quota through the form; or move steady load to provisioned types.

## Budgets

Azure budgets **notify; they do not stop resources or usage**. Scope them to the resource group that holds the Foundry resource.

```bash
az consumption budget create-with-rg \
  --budget-name llm-budget -g "$RG" --category Cost --amount "$AMOUNT" --time-grain Monthly \
  --time-period '{"start-date":"2026-10-01","end-date":"2027-09-30"}' \
  --notifications "{\"Key1\":{\"enabled\":\"true\",\"operator\":\"GreaterThanOrEqualTo\",\"contact-emails\":[\"$OWNER_EMAIL\"],\"threshold\":80.0,\"contact-groups\":[\"$ACTION_GROUP_ID\"]}}"

az consumption budget list -o table
```

The `az consumption` group is in preview. The start date should be the first of a month. An **action group** attached to a threshold can call a Logic App, Azure Function, webhook or Automation runbook. A documented pattern (Microsoft Community Hub, Azure OpenAI cost control) uses a runbook that disables API access when the budget breaches and a separate manual runbook to re-enable it. The simplest enforcement is disabling key auth or deleting a deployment via the runbook; test it in a non-production resource group first.

Provisioned (PTU) deployments bill whether or not you send traffic, and soft-deleted accounts keep billing provisioned deployments until purged. Look up prices on the Azure OpenAI / Foundry pricing page (https://azure.microsoft.com/pricing/details/azure-openai/ ; unverified URL, search "Azure OpenAI pricing") and do not hardcode them.

Per-key and per-team limits belong in the gateway (`llm-gateway`).

## Sources

- https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/quota
- https://learn.microsoft.com/en-us/azure/foundry/openai/quotas-limits
- https://learn.microsoft.com/en-us/azure/foundry/foundry-models/quotas-limits
- https://learn.microsoft.com/en-us/rest/api/aifoundry/accountmanagement/usages/list?view=rest-aifoundry-accountmanagement-2025-06-01
- https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/troubleshoot-errors
- https://learn.microsoft.com/en-us/cli/azure/consumption/budget?view=azure-cli-latest
- https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/cost-management-budget-scenario
- https://techcommunity.microsoft.com/blog/azureinfrastructureblog/automating-azure-openai-cost-control-using-budgets-action-groups-and-automation-/4505164
