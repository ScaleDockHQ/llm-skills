# Azure Foundry

Helps an agent deploy and call models on Microsoft Foundry (formerly Azure AI Foundry and Azure OpenAI) and serve custom models on Azure Machine Learning online endpoints. It covers the `az` CLI, deployment types, the v1 API with the OpenAI SDK, Entra ID auth, quotas and 429 handling, budgets, private networking, LiteLLM wiring and a verified teardown. The `.openai.azure.com` host and `az cognitiveservices` commands survived the rebrand, so old and new names both work as search terms.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill azure-foundry
```

## Rules

- **Ask before creating billable resources.** Resources, deployments, PTUs, endpoints, role assignments and budgets need approval.
- **Entra ID over keys.** Assign `Cognitive Services OpenAI User`; disable key auth where policy allows.
- **Secrets never touch output.** Keys go straight into `0600` files or unprinted variables.
- **Call the deployment name, not the model name.**
- **Budgets and quota checks come before traffic.** Azure budgets alert but do not stop usage.
- **Always tear down.** Deleting an account soft-deletes it, and provisioned charges continue until purged.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): rename, resource creation, Entra ID, roles, keys.
- [`references/api-and-deployments.md`](references/api-and-deployments.md): deployment types, `az` deploy commands, v1 API calls, batch.
- [`references/azure-ml-endpoints.md`](references/azure-ml-endpoints.md): managed online endpoints for custom models.
- [`references/limits-and-budgets.md`](references/limits-and-budgets.md): quota model, usage, 429 headers, budgets and action groups.
- [`references/private-access-and-data.md`](references/private-access-and-data.md): private endpoints, residency, policy.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries and OpenAI SDK setup.
- [`references/teardown-and-troubleshooting.md`](references/teardown-and-troubleshooting.md): teardown order and error table.

## Companion skills

- `cloud-llms`: cross-provider cloud workflow.
- `llm-gateway`: one endpoint, keys, routing and fallbacks.
- `choosing-llm-hosting`: cloud versus local versus owned GPUs.
- `self-hosted-llms`: the serving stack behind a custom endpoint.
- `llm-evals`: compare models before committing.
- `llm-observability`: tracing and cost dashboards.

## License

MIT
