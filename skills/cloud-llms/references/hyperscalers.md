# Hyperscaler model platforms: AWS Bedrock, Google Agent Platform, Microsoft Foundry

> Verified against AWS Bedrock User Guide (model access, Chat Completions API, cross-Region inference, interface VPC endpoints, data protection, quotas), Gemini Enterprise Agent Platform docs (OpenAI compatibility, quotas, zero data retention, name changes), Microsoft Foundry docs (overview, API version lifecycle / v1 API, deployment types), LiteLLM v1.105.0 provider docs, 2026-10-11

## What it is and when to choose it

Frontier and open models consumed through your own cloud account, billed on your cloud invoice, governed by your IAM and reachable over private networking. Choose this tier when you already have a cloud contract, need a BAA or residency controls, or want to avoid separate vendor contracts.

Naming in 2026: Google renamed Vertex AI to **Gemini Enterprise Agent Platform** ("Agent Platform"); the API host (`{location}-aiplatform.googleapis.com` / `aiplatform.googleapis.com`), model IDs and auth did not change, and tools such as LiteLLM still use the `vertex_ai/` prefix. Azure AI Foundry is now **Microsoft Foundry**; Azure OpenAI models are deployed and called through it.

## Install / setup

### AWS Bedrock

1. Pick the Region. Model availability differs by Region.
2. Model access: many models are enabled by default when the caller has AWS Marketplace permissions (`aws-marketplace:Subscribe`, `aws-marketplace:Unsubscribe`, `aws-marketplace:ViewSubscriptions`). The first invocation of a third-party model starts a subscription in the background, which can take minutes; until it completes you may see `AccessDeniedException`. Some models need additional account-level access.
3. IAM: grant `bedrock:InvokeModel` (and streaming variants) on the specific model or inference profile ARNs, not `*`.
4. Endpoints: native APIs are `InvokeModel` and `Converse` on `bedrock-runtime`. An OpenAI Chat Completions endpoint is also available:
   - `https://bedrock-runtime.<region>.amazonaws.com/openai/v1` (recommended; SigV4 or Bedrock API key)
   - `https://bedrock-mantle.<region>.api.aws/v1` (compatibility option when a model or feature is not on `bedrock-runtime`)
5. Cross-Region inference: inference profiles route to other Regions within a geography (geographic profiles, IDs prefixed for example `us.` or `eu.`) or worldwide (global profiles). Use geographic or single-Region invocation when residency matters.

```bash
aws bedrock list-foundation-models --region <region> --query 'modelSummaries[].modelId' --output text
aws service-quotas list-service-quotas --service-code bedrock --region <region> --query 'Quotas[].[QuotaName,Value]' --output text | head -40
```

### Gemini Enterprise Agent Platform (Vertex AI)

1. Pick the project and location (a region, or `global` where supported).
2. Enable the API and grant the serving identity a role that allows prediction on the platform (least privilege; avoid project Owner/Editor).
3. Use Application Default Credentials or workload identity, not service-account key files.
4. Endpoints: native `generateContent` for Gemini; partner and open models through Model Garden / Model as a Service. An OpenAI-compatible endpoint exists:
   `https://aiplatform.googleapis.com/v1/projects/<project>/locations/<location>/endpoints/openapi` (bearer token from `gcloud auth print-access-token`).

```bash
gcloud services list --enabled --filter='name:aiplatform.googleapis.com' --format='value(name)'
```

### Microsoft Foundry (Azure OpenAI)

1. Create a Foundry resource in the chosen region and deploy a model. The **deployment type** decides where processing happens: Global Standard, Data Zone Standard, Standard (regional), Global/Data Zone/Regional Provisioned, Global/Data Zone Batch, Developer.
2. Clients call the **deployment name**, not the model name.
3. The v1 API base URL is `https://<resource>.openai.azure.com/openai/v1/` (also reachable as `https://<resource>.services.ai.azure.com/openai/v1/`). Prefer Microsoft Entra ID (managed identity) over API keys.

```bash
az cognitiveservices account list --query '[].{name:name,kind:kind,location:location}' -o table
az cognitiveservices account deployment list -g <resource-group> -n <resource> --query '[].{name:name,model:properties.model.name,sku:sku.name}' -o table
```

## Minimal working config (LiteLLM)

```yaml
model_list:
  - model_name: frontier-bedrock
    litellm_params:
      model: bedrock/<inference-profile-or-model-id>
      aws_region_name: <region>
  - model_name: frontier-vertex
    litellm_params:
      model: vertex_ai/<model-id>
      vertex_project: <project>
      vertex_location: <location>
  - model_name: frontier-azure
    litellm_params:
      model: azure/<deployment-name>
      api_base: https://<resource>.openai.azure.com/
      api_version: "<api-version>"
      api_key: os.environ/AZURE_API_KEY
```

Credentials: Bedrock uses the standard AWS credential chain (instance role, `AWS_PROFILE`, or LiteLLM's `aws_role_name` / `aws_profile_name` parameters); Vertex uses Application Default Credentials; Azure also supports Entra ID (see LiteLLM's Azure page for `azure_ad_token` and client-credential options). A fuller example is in `assets/litellm-hybrid.yaml`.

## How it plugs into the stack

- Gateway entries as above; clients keep calling aliases.
- Private path: run the gateway inside the same cloud network and use private endpoints (`security-compliance.md`), so prompts never cross the public internet.
- API coverage: native APIs on all three; OpenAI Chat Completions endpoints on all three (Bedrock `/openai/v1`, Agent Platform `endpoints/openapi`, Foundry `/openai/v1/`). Anthropic Messages-shaped access to Claude models is available on Bedrock and Agent Platform through their native APIs; a gateway can expose `/v1/messages` in front of them (`llm-gateway`).

## Operating

- **Quotas**: Bedrock quotas (tokens and requests per minute per model) are in Service Quotas, and the applied values can be lower than published defaults depending on account history. Agent Platform has per-model quotas plus shared pay-as-you-go capacity; request increases in the console. Foundry quotas are per region, per model and deployment type. Request increases before launch (`cost-and-quotas.md`).
- **Provisioned capacity** (Bedrock provisioned throughput, Agent Platform provisioned throughput, Foundry provisioned deployments) is a commitment billed per hour. Use it only when measured steady load justifies it.
- **Model lifecycle**: each platform retires model versions on its own schedule; pin versions and track retirement notices.

## Tuning knobs worth knowing

- Bedrock: geographic vs global cross-Region inference profiles; Converse API for a uniform request shape; Bedrock API keys for quick tests only, IAM roles for production.
- Agent Platform: `global` vs regional location (availability and residency); context caching for Gemini.
- Foundry: deployment type (residency vs capacity), batch deployments for offline work, per-deployment rate limits.

## Known pitfalls

- Using a global routing option for regulated data that must stay in one geography.
- Calling Azure with the model name instead of the deployment name.
- Missing Marketplace permissions on Bedrock, producing `AccessDeniedException` after an initial success.
- Service-account key files committed or baked into images.
- Assuming a new model is available in your region on launch day.
- Old docs and tools say "Vertex AI" and "Azure AI Foundry"; the products and API hosts are the same.

## Official links

- Bedrock model access: https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html
- Bedrock Chat Completions API: https://docs.aws.amazon.com/bedrock/latest/userguide/inference-chat-completions.html
- Bedrock cross-Region inference: https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html
- Bedrock PrivateLink: https://docs.aws.amazon.com/bedrock/latest/userguide/vpc-interface-endpoints.html
- Bedrock quotas: https://docs.aws.amazon.com/bedrock/latest/userguide/quotas.html
- Bedrock data protection: https://docs.aws.amazon.com/bedrock/latest/userguide/data-protection.html
- Agent Platform OpenAI compatibility: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/start/openai
- Agent Platform quotas: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/quotas
- Agent Platform zero data retention: https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention
- Vertex AI to Agent Platform name changes: https://docs.cloud.google.com/gemini-enterprise-agent-platform/vertex-ai-name-changes
- Microsoft Foundry overview: https://learn.microsoft.com/en-us/azure/ai-foundry/what-is-azure-ai-foundry
- Azure OpenAI v1 API and lifecycle: https://learn.microsoft.com/en-us/azure/ai-foundry/openai/api-version-lifecycle
- Foundry deployment types: https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types
- LiteLLM Bedrock: https://docs.litellm.ai/docs/providers/bedrock
- LiteLLM Vertex AI: https://docs.litellm.ai/docs/providers/vertex
- LiteLLM Azure OpenAI: https://docs.litellm.ai/docs/providers/azure/
