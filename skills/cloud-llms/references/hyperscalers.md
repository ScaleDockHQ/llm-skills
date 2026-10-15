# Hyperscaler model platforms: AWS Bedrock, Google Agent Platform, Microsoft Foundry

> Verified against AWS Bedrock User Guide (Chat Completions API), Gemini Enterprise Agent Platform docs (OpenAI compatibility, name changes), Microsoft Foundry docs (API version lifecycle / v1 API), LiteLLM v1.105.0 provider docs, 2026-10-11

Frontier and open models consumed through your own cloud account, billed on your cloud invoice, governed by your IAM and reachable over private networking.

Depth: install the `aws-bedrock` skill (`npx skills add ScaleDockHQ/llm-skills --skill aws-bedrock`), the `google-vertex-ai` skill (`npx skills add ScaleDockHQ/llm-skills --skill google-vertex-ai`) and the `azure-foundry` skill (`npx skills add ScaleDockHQ/llm-skills --skill azure-foundry`).

Naming: Google renamed Vertex AI to Gemini Enterprise Agent Platform; hosts, model IDs and auth did not change, and LiteLLM still uses the `vertex_ai/` prefix. Azure AI Foundry is now Microsoft Foundry.

## How it plugs into this stack

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

- Credentials: Bedrock uses the AWS credential chain, Vertex uses Application Default Credentials, Azure supports Entra ID. No key files in images or manifests.
- Run the gateway inside the same cloud network and use private endpoints (`security-compliance.md`), so prompts never cross the public internet.
- Azure is called by deployment name, not model name; with the v1 API no `api-version` is needed. Deleting a Foundry account soft-deletes it and provisioned deployments keep billing until purged. Claude on Foundry uses `azure_ai/claude-*`, not `azure/`.
- Pin model versions and track each platform's retirement notices; request quota before launch (`cost-and-quotas.md`).
- Use geographic or single-Region options, not global routing, for regulated data.
- A full example is in `assets/litellm-hybrid.yaml`.

## Official links

- Bedrock Chat Completions API: https://docs.aws.amazon.com/bedrock/latest/userguide/inference-chat-completions.html
- Agent Platform OpenAI compatibility: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/start/openai
- Azure OpenAI v1 API and lifecycle: https://learn.microsoft.com/en-us/azure/ai-foundry/openai/api-version-lifecycle
- LiteLLM Bedrock: https://docs.litellm.ai/docs/providers/bedrock
- LiteLLM Vertex AI: https://docs.litellm.ai/docs/providers/vertex
- LiteLLM Azure OpenAI: https://docs.litellm.ai/docs/providers/azure/
