# Setup, resources and authentication

> Verified against Microsoft Foundry docs (What is Microsoft Foundry, Quickstart: Set up Foundry resources, Create a Foundry resource, Azure OpenAI v1 API, Configure keyless authentication with Entra ID, Disable local authentication, Azure OpenAI role-based access control), az CLI reference for `az cognitiveservices account`, 2026-10-11

## Naming

Docs map the old names: Azure AI Studio / Azure AI Foundry -> **Microsoft Foundry**; Azure AI Services -> **Foundry Tools**; Hub + Azure OpenAI + Azure AI Services resources -> one **Foundry resource** with projects; monthly `api-version` -> v1 stable routes (`/openai/v1/`); Assistants API -> Responses API (Agents v2). Docs live under both `learn.microsoft.com/en-us/azure/ai-foundry/` and `.../azure/foundry/`; the pages are the same product. CLI and ARM still say `Microsoft.CognitiveServices/accounts` and `az cognitiveservices`.

Source: https://learn.microsoft.com/en-us/azure/ai-foundry/what-is-azure-ai-foundry

## Create the resource

Ask first: creating a resource adds a billable resource (pay-per-token models cost nothing idle; provisioned types do).

```bash
az login
az account set --subscription "$SUBSCRIPTION_ID"
az group create --name "$RG" --location "$LOCATION"

az cognitiveservices account create \
  --name "$RESOURCE" --resource-group "$RG" \
  --kind AIServices --sku S0 --location "$LOCATION" \
  --custom-domain "$RESOURCE" \
  --assign-identity --allow-project-management true

az cognitiveservices account show -n "$RESOURCE" -g "$RG" \
  --query '{kind:kind,state:properties.provisioningState,endpoint:properties.endpoint}' -o table
```

Documented details: `--custom-domain` must be globally unique (`CustomDomainInUse` otherwise); `--assign-identity` is needed for project management; `--allow-project-management` cannot be changed after creation. Always create `kind` `AIServices` for Foundry. Projects: `az cognitiveservices account project delete` exists for removal; creation is covered in https://learn.microsoft.com/en-us/azure/foundry/how-to/create-projects.

Endpoints: the v1 OpenAI base URL is `https://$RESOURCE.openai.azure.com/openai/v1/` (also `https://$RESOURCE.services.ai.azure.com/openai/v1/`).

## Entra ID (preferred)

Roles on the resource (or its resource group): **Cognitive Services OpenAI User** (inference, role ID `5e0bd9bd-7b93-4f28-af87-19fc36ad61bd` per the keyless page), **Cognitive Services OpenAI Contributor** (assistants and more), **Cognitive Services Contributor**, **Cognitive Services Usages Reader**. Subscription-level Owner and Contributor are inherited and take priority.

```bash
RID=$(az cognitiveservices account show -n "$RESOURCE" -g "$RG" --query id -o tsv)
ME=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --role "Cognitive Services OpenAI User" \
  --assignee-object-id "$ME" --assignee-principal-type User --scope "$RID"
```

(Flag names follow `az role assignment create`; the docs example uses `--assignee` and `--scope`. Role assignments take a few minutes to propagate.)

Token scope for the v1 API and OpenAI SDK: `https://ai.azure.com/.default`. REST test (token held in a variable, not printed):

```bash
TOKEN=$(az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv)
curl -sS "https://$RESOURCE.openai.azure.com/openai/v1/responses" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"model":"'"$DEPLOYMENT"'","input":"Say hello"}' | jq -r '.output_text // .'
```

Managed identity: enable it on the host (VM, App Service, AKS workload identity), assign the same role to that identity, and for a user-assigned identity set `AZURE_CLIENT_ID` so `DefaultAzureCredential` picks it. `az login --tenant <id>` fixes "wrong tenant" token failures locally.

## API keys

Keys are the simple path for tests. The header is `api-key: <key>` on REST, or `api_key` in the OpenAI client with the v1 `base_url`. Keys can be read with `az cognitiveservices account keys list` or from the portal; both print secrets, so capture them straight into a `0600` file or secret store:

```bash
umask 077
az cognitiveservices account keys list -n "$RESOURCE" -g "$RG" --query key1 -o tsv > ~/.config/azure-foundry.key
export AZURE_OPENAI_API_KEY=$(cat ~/.config/azure-foundry.key)   # never echo
```

## Disable key auth (enforce Entra)

- Azure Policy: "Azure AI Services resources should have key access disabled (disable local authentication)", at subscription or resource group scope.
- Bicep/ARM property `disableLocalAuth: true`.
- PowerShell: `Set-AzCognitiveServicesAccount -ResourceGroupName <rg> -Name <name> -DisableLocalAuth $true`.

Propagation can take minutes to hours. Confirm by sending a request with an old key: expect HTTP 401 `Access denied due to invalid subscription key or wrong API endpoint`. Before disabling, make sure every caller (gateway, CI) uses Entra, or it breaks.

## Sources

- https://learn.microsoft.com/en-us/azure/ai-foundry/what-is-azure-ai-foundry
- https://learn.microsoft.com/en-us/azure/foundry/tutorials/quickstart-create-foundry-resources
- https://learn.microsoft.com/en-us/azure/ai-services/multi-service-resource
- https://learn.microsoft.com/en-us/azure/ai-foundry/openai/api-version-lifecycle
- https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/managed-identity
- https://learn.microsoft.com/en-us/azure/developer/ai/keyless-connections
- https://learn.microsoft.com/en-us/azure/ai-services/disable-local-auth
- https://learn.microsoft.com/en-us/cli/azure/cognitiveservices/account
