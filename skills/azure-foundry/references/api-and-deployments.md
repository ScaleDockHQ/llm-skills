# Deployment types, az deployments and the v1 API

> Verified against Microsoft Foundry docs (Understanding deployment types, Azure OpenAI v1 API, Quickstart: Set up Foundry resources, Automate deployments with quota), az CLI reference for `az cognitiveservices`, 2026-10-11

## Deployment types

Choose by data residency and billing. Start with Global Standard unless you have a reason not to (newest models first, lowest price, broadest regions, highest default quota).

| Type                  | `--sku-name`                 | Processing                 | Billing                                             |
| --------------------- | ---------------------------- | -------------------------- | --------------------------------------------------- |
| Global Standard       | `GlobalStandard`             | Any Azure region           | Pay per token                                       |
| Global Provisioned    | `GlobalProvisionedManaged`   | Any Azure region           | Reserved PTU                                        |
| Global Batch          | `GlobalBatch`                | Any Azure region           | 50% discount, 24 hr                                 |
| Data Zone Standard    | `DataZoneStandard`           | Within US, EU or APAC zone | Pay per token                                       |
| Data Zone Provisioned | `DataZoneProvisionedManaged` | Within data zone           | Reserved PTU                                        |
| Data Zone Batch       | `DataZoneBatch`              | Within data zone           | 50% discount                                        |
| Standard              | `Standard`                   | Within Azure geography     | Pay per token                                       |
| Regional Provisioned  | `ProvisionedManaged`         | Within Azure geography     | Reserved PTU                                        |
| Developer             | `DeveloperTier`              | Any region                 | Fine-tune evaluation only, 24-hour lifetime, no SLA |

Not every model supports every type; check availability by type and region. Data at rest stays in the resource's geography; inference processing follows the type. Global Standard also supports request-level Flex (lower cost, delay tolerant) and Priority processing tiers. "Instant access" (preview) lets you call supported models by name with no deployment. Provisioned types are reserved-capacity commitments billed per PTU-hour; use only after measuring steady load, and find PTU minimums in the provisioned throughput concepts page linked from the deployment types doc (unverified URL: search "Provisioned throughput concepts" on learn.microsoft.com). Restrict types org-wide with Azure Policy on `Microsoft.CognitiveServices/accounts/deployments/sku.name`.

## Find and create a deployment

```bash
# What is deployable in a region (name, version, skus)
az cognitiveservices model list --location "$LOCATION" \
  --query "[?model.name=='$MODEL'].{version:model.version,skus:join(',',model.skus[].name)}" -o table

# Create. Capacity for Standard types is thousands of TPM (10 = 10K TPM)
az cognitiveservices account deployment create \
  --name "$RESOURCE" --resource-group "$RG" \
  --deployment-name "$DEPLOYMENT" \
  --model-name "$MODEL" --model-version "$MODEL_VERSION" --model-format OpenAI \
  --sku-name GlobalStandard --sku-capacity 10

az cognitiveservices account deployment show -n "$RESOURCE" -g "$RG" --deployment-name "$DEPLOYMENT" \
  --query properties.provisioningState -o tsv
```

The quickstart deploys `gpt-5-mini` version `2025-08-07` as `GlobalStandard` with capacity 10. Pin the version you tested. `--model-format` is the provider: `OpenAI` for OpenAI models; the docs list others such as `Microsoft`, `Meta`, `DeepSeek`, `xAI`, `Mistral AI`, `Cohere`, `AI21 Labs`, `Core42`. Error `DeploymentModelNotSupported` means the model, version or SKU is not available in your region: use the list command. A new deployment can take up to about five minutes before `DeploymentNotFound` stops. There is also `az cognitiveservices account list-models -n ... -g ...`, `list-skus` and `list-usage`.

Limits seen in the docs: Foundry resources per region per subscription and maximum deployments per resource are fixed limits (see the quotas page); do not assume them.

## v1 API (no api-version)

`base_url = https://<resource>.openai.azure.com/openai/v1/` with the plain `OpenAI()` client. Pass the **deployment name** as `model`. The Responses API is recommended for Azure OpenAI models; Chat Completions also works, and partner models that speak v1 chat completions (DeepSeek, Grok and others) work through the same base URL. Preview features are opt-in via feature headers or `alpha` paths, not api-version.

```python
import os
from openai import OpenAI
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

token_provider = get_bearer_token_provider(DefaultAzureCredential(), "https://ai.azure.com/.default")

client = OpenAI(
    base_url=f"https://{os.environ['AZURE_RESOURCE']}.openai.azure.com/openai/v1/",
    api_key=token_provider,           # callable: automatic refresh
)
r = client.responses.create(model=os.environ["AZURE_DEPLOYMENT"], input="This is a test.")
print(r.output_text)

# Chat Completions on the same client
c = client.chat.completions.create(model=os.environ["AZURE_DEPLOYMENT"],
                                   messages=[{"role": "user", "content": "Hello"}])
```

Key auth form: `OpenAI(api_key=os.environ["AZURE_OPENAI_API_KEY"], base_url=...)`, or set `OPENAI_BASE_URL` and `OPENAI_API_KEY`.

```bash
curl -sS "https://$RESOURCE.openai.azure.com/openai/v1/chat/completions" \
  -H "api-key: $AZURE_OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"'"$DEPLOYMENT"'","messages":[{"role":"user","content":"Hello"}]}' | jq -r '.choices[0].message.content'
```

Model-specific parameters follow the model: for example reasoning models use `max_completion_tokens` rather than `max_tokens` (documented in the api-version changelog).

## Batch

Batch deployment types (`GlobalBatch`, `DataZoneBatch`) have their own enqueued-token quota, a 24-hour target turnaround with no real-time SLA, and 50% lower cost than Global Standard. You send a file of requests instead of one at a time. Create a batch-type deployment of the model, then use the Batch API on the v1 route; find the current Batch API request format on learn.microsoft.com (unverified: search "Azure OpenAI Batch" in the Foundry docs).

## Sources

- https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types
- https://learn.microsoft.com/en-us/azure/ai-foundry/openai/api-version-lifecycle
- https://learn.microsoft.com/en-us/azure/foundry/tutorials/quickstart-create-foundry-resources
- https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/automate-quota-deployments
- https://learn.microsoft.com/en-us/cli/azure/cognitiveservices/account
