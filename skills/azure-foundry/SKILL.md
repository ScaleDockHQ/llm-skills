---
name: azure-foundry
description: Use Microsoft Foundry, formerly Azure AI Foundry and Azure OpenAI, to deploy and call GPT, Claude and open models with the az CLI, deployment types, the v1 API, Entra ID auth, quotas, budgets, Azure ML online endpoints and teardown. Use for Azure OpenAI, AIServices resource, az cognitiveservices, openai.azure.com, DeploymentNotFound 404, 401 invalid subscription key, 429 retry-after-ms, PTU, LiteLLM azure/. For cross-provider choices use cloud-llms, for gateways use llm-gateway.
license: MIT
compatibility: Needs the Azure CLI (az, with the ml extension for online endpoints), bash, curl and jq, plus network access to Azure. Creating resources, deployments, endpoints, budgets and role assignments needs the user's explicit approval. Works on macOS and Linux.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Azure Foundry (Microsoft Foundry and Azure OpenAI)

Deploy and call models through Microsoft Foundry with Entra ID auth, quota and budget controls in place before traffic, a LiteLLM or OpenAI-client connection, and a verified teardown. Also covers serving your own model on Azure Machine Learning managed online endpoints.

**Naming (verified 2026-10-11):** Azure AI Studio and Azure AI Foundry are now **Microsoft Foundry**; Azure AI Services is now **Foundry Tools**; the old Azure OpenAI resource is a **Foundry resource** (`kind` `AIServices`). Azure OpenAI models are deployed and called through it. The `.openai.azure.com` host, `az cognitiveservices` commands and the "Azure OpenAI" name still appear in docs and tools. Microsoft's docs offer an upgrade of an Azure OpenAI resource to a Foundry resource that preserves endpoint, keys and state.

**Scope:** Foundry resources and model deployments (OpenAI, Anthropic and other partner models), deployment types, the v1 API with the OpenAI SDK, Entra ID and keys, quotas and 429s, budgets, private networking, Azure ML online endpoints for custom models, teardown.

Out of scope: choosing clouds or tiers (`cloud-llms`, `choosing-llm-hosting`), gateway features (`llm-gateway`), Foundry Agent Service and hosted agents design, the serving engine (`self-hosted-llms`), evals (`llm-evals`), tracing (`llm-observability`).

Work through the steps in order. Load a reference only when a step names it. Take flags and URLs from the references or the linked docs.

## Discover first

Read-only. Nothing here prints a key.

```bash
command -v az && az version --query '"azure-cli"' -o tsv
az extension list --query "[?name=='ml'].version" -o tsv 2>/dev/null
az account show --query '{subscription:name,id:id,tenant:tenantId}' -o tsv 2>/dev/null

# Foundry / Azure OpenAI resources and their deployments
az cognitiveservices account list \
  --query "[?kind=='AIServices' || kind=='OpenAI'].{name:name,rg:resourceGroup,loc:location,kind:kind}" -o table 2>/dev/null
az cognitiveservices account deployment list -g "$RG" -n "$RESOURCE" \
  --query '[].{name:name,model:properties.model.name,version:properties.model.version,sku:sku.name,cap:sku.capacity}' -o table 2>/dev/null

# Soft-deleted accounts that may still bill (provisioned deployments)
az cognitiveservices account list-deleted -o table 2>/dev/null

# Azure ML online endpoints (billable per instance)
az ml online-endpoint list -g "$RG" -w "$WS" -o table 2>/dev/null

# Env var NAMES only
env | cut -d= -f1 | grep -E '^(AZURE_|OPENAI_|LITELLM)' | sort
```

Note: subscription, existing resources and deployment types, whether key auth is on, soft-deleted accounts, and whether an Azure ML workspace exists. Ask only for what is missing: workload, data residency (global, data zone or geography), budget ceiling, model.

## Decision flow

1. Hosted GPT, Claude or open models, pay per token: Foundry resource + `GlobalStandard` deployment (`references/api-and-deployments.md`).
2. Residency requirement: Data Zone or regional types (`references/api-and-deployments.md`, `references/private-access-and-data.md`).
3. Steady, latency-sensitive load: provisioned (PTU) types. Offline work: Batch types (50% discount, 24-hour target).
4. A model Foundry does not host, custom weights: Azure ML managed online endpoint (`references/azure-ml-endpoints.md`).
5. Private only: disable public network access and add a private endpoint (`references/private-access-and-data.md`).
6. Cross-cloud or quick test only: see `cloud-llms` for cheaper paths.

## Rules

- **Ask before creating billable resources.** Resources, deployments, PTUs, endpoints, role assignments and budgets need approval and an undo path.
- **Entra ID over keys.** Assign `Cognitive Services OpenAI User` to the calling identity; disable key auth where policy allows (`references/setup-and-auth.md`).
- **Secrets never touch output.** Do not run `az cognitiveservices account keys list` or `az ml online-endpoint get-credentials` without redirecting into a `0600` file or a variable that is not printed.
- **Calls use the deployment name,** not the model name.
- **Budgets and quota checks before traffic.** Budgets alert but do not stop usage (`references/limits-and-budgets.md`).
- **Pin model and version.** Deployments take an explicit model version; track retirement.
- **Always tear down.** Deleting an account soft-deletes it; provisioned charges continue until purged (`references/teardown-and-troubleshooting.md`).
- **Verify upstream.** Foundry docs are mid-migration (new vs classic, `ai-foundry` vs `foundry` URLs). Re-read the linked page before relying on a flag.

## Workflows

### Set up and authenticate

- [ ] Resource group, Foundry resource (`--kind AIServices`), custom domain -> `references/setup-and-auth.md`
- [ ] Role assignment and `az login`; keys optional
- [ ] Verify: token or key reaches `GET .../openai/v1/models` or a one-line response.

### Deploy and call

- [ ] List models in region, pick deployment type, deploy -> `references/api-and-deployments.md`
- [ ] Call through the v1 API with the OpenAI SDK
- [ ] Verify: `provisioningState` is `Succeeded` and a request returns text.

### Connect to the gateway

- [ ] LiteLLM `azure/<deployment>` with `api_base` and Entra or key auth -> `references/litellm-and-clients.md`
- [ ] Verify: the alias answers through the gateway.

### Serve a custom model

- [ ] Azure ML endpoint and deployment YAML, GPU instance type, quota -> `references/azure-ml-endpoints.md`
- [ ] Verify: scoring URI answers; note billing starts at the deployment.

### Scale and control cost

- [ ] Check usage and TPM per deployment, request quota, consider PTU or batch -> `references/limits-and-budgets.md`
- [ ] Create a budget with an action group; optionally automate disabling key auth.

### Update

- [ ] New model version as a second deployment, shift traffic in the gateway, delete the old one. Azure ML: blue/green `--traffic` split -> `references/azure-ml-endpoints.md`

### Tear down

- [ ] Delete deployments, endpoints, projects, resource or resource group, purge soft-deleted accounts, remove budgets and role assignments -> `references/teardown-and-troubleshooting.md`
- [ ] Verify: lists empty, `az group exists` is false, no deleted accounts.

### Troubleshoot

- [ ] 401, 403, 404 DeploymentNotFound, 429, DeploymentModelNotSupported -> `references/teardown-and-troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: rename, resource creation, Entra ID, roles, keys, disabling key auth.
- `references/api-and-deployments.md`: deployment types, az deploy commands, v1 API calls, models, batch.
- `references/azure-ml-endpoints.md`: managed online endpoints for custom models, auth modes, vLLM pattern.
- `references/limits-and-budgets.md`: quota model, usage commands, 429 headers, budgets, action groups.
- `references/private-access-and-data.md`: private endpoint, residency, policy controls.
- `references/litellm-and-clients.md`: LiteLLM entries, OpenAI SDK with v1 base URL, Claude on Foundry.
- `references/teardown-and-troubleshooting.md`: teardown order and error table.

## Companion skills

- `cloud-llms`: cross-provider cloud workflow. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: one endpoint, keys, routing and fallbacks. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `choosing-llm-hosting`: cloud vs local vs owned GPUs. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`.
- `self-hosted-llms`: the serving stack for Azure ML endpoints. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `llm-evals`: compare models before committing. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `llm-observability`: tracing and cost dashboards. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
