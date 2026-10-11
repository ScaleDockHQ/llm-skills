# LiteLLM and client configuration

> Verified against LiteLLM docs (Azure OpenAI provider page, config.yaml) and LiteLLM source `llms/azure/common_utils.py`, Microsoft Foundry v1 API docs, 2026-10-11

## LiteLLM entries

Route: `azure/<deployment-name>` (the deployment name, not the model name). Claude models served through Foundry use a different route, `azure_ai/claude-*`, per the LiteLLM Azure page.

```yaml
model_list:
  - model_name: gpt-azure
    litellm_params:
      model: azure/<deployment-name>
      api_base: https://<resource>.openai.azure.com/
      api_version: "<api-version>" # see v1 note below
      api_key: os.environ/AZURE_API_KEY # or Entra, below

  # Entra ID with a service principal (LiteLLM builds the token provider)
  - model_name: gpt-azure-entra
    litellm_params:
      model: azure/<deployment-name>
      api_base: https://<resource>.openai.azure.com/
      api_version: "<api-version>"
      tenant_id: os.environ/AZURE_TENANT_ID
      client_id: os.environ/AZURE_CLIENT_ID
      client_secret: os.environ/AZURE_CLIENT_SECRET
      azure_scope: os.environ/AZURE_SCOPE # LiteLLM default: https://cognitiveservices.azure.com/.default

litellm_settings:
  enable_azure_ad_token_refresh: true # fall back to DefaultAzureCredential (managed identity, az login)
```

Notes:

- With `enable_azure_ad_token_refresh: true` and no key, LiteLLM uses `DefaultAzureCredential` (managed identity on AKS or a VM, env vars, Azure CLI session).
- **v1 API:** the Azure OpenAI v1 routes need no dated `api-version`. LiteLLM's source routes `api_version` values such as `v1` through the plain `OpenAI` client at `<api_base>/openai/v1/`, but the LiteLLM provider page examples still show dated versions. Treat `api_version: "v1"` as unverified in the docs: check https://docs.litellm.ai/docs/providers/azure/ for your LiteLLM version, and test.
- Entra token scope: LiteLLM defaults to `https://cognitiveservices.azure.com/.default`; Microsoft's v1 docs use `https://ai.azure.com/.default`. Both are documented by their owners; if one gets 401, try the other.
- Multiple regions: same `model_name` across several deployments gives load balancing and spreads 429 pressure (see `llm-gateway`).
- Custom Azure ML endpoints: `openai/<served-name>` with `api_base` and `api_key: os.environ/AML_KEY`, only if the container serves OpenAI routes.

## OpenAI SDK

Use the `OpenAI` client with `base_url=https://<resource>.openai.azure.com/openai/v1/`; `api_key` can be a key or a token-provider callable from `azure-identity` for auto-refresh (full example in `api-and-deployments.md`). JS, Go, Java and C# equivalents are in the v1 API page. Environment shortcut: `OPENAI_BASE_URL` and `OPENAI_API_KEY`.

## Anthropic and other partner models

Foundry hosts Anthropic and other partner models (the quotas docs list Anthropic models). Their endpoints, deployment `--model-format` and compatible routes are model-specific; read the model card in the Foundry catalog and the LiteLLM page before wiring. A gateway can expose `/v1/messages` in front of whichever route works (`llm-gateway`).

## Sources

- https://docs.litellm.ai/docs/providers/azure/
- https://docs.litellm.ai/docs/proxy/configs
- https://github.com/BerriAI/litellm/blob/c274cf32/litellm/llms/azure/common_utils.py
- https://learn.microsoft.com/en-us/azure/ai-foundry/openai/api-version-lifecycle
