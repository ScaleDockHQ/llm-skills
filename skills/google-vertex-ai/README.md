# Google Vertex AI

Helps an agent use Google Cloud Vertex AI, renamed Gemini Enterprise Agent Platform in 2026: call Gemini, Claude and open models, serve a custom model on a managed GPU endpoint, and wire either into a LiteLLM gateway or OpenAI clients. It covers `gcloud` and Application Default Credentials, the OpenAI-compatible endpoint, quotas and consumption options, batch inference, private access, budgets, and teardown. The product kept its API host, `gcloud ai` commands and model IDs through the rename, so both names work as search terms.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill google-vertex-ai
```

## Rules

- **Ask before creating billable resources.** Endpoints, Provisioned Throughput, batch jobs, partner-model enablement and billing changes need approval.
- **Prefer ADC and impersonation over key files.** No service-account keys in repos or images.
- **Secrets never touch output.** Tokens are produced inline or read from env vars and `0600` files.
- **Budget alerts and quota checks come before traffic.** A Cloud Billing budget alerts but does not cap spend.
- **Pin model IDs and choose the location on purpose.** `global` is for capacity, not for regulated data.
- **Always tear down.** Undeploy, delete and verify in every region used.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): the rename, project setup, ADC, impersonation, roles, locations.
- [`references/api-and-models.md`](references/api-and-models.md): Gemini, OpenAI-compatible endpoint, Claude, open MaaS models, batch.
- [`references/custom-endpoints.md`](references/custom-endpoints.md): Model Garden deploy, endpoints, calling and traffic splits.
- [`references/limits-and-budgets.md`](references/limits-and-budgets.md): quotas, PayGo tiers, Provisioned Throughput, 429s, budgets.
- [`references/private-access-and-data.md`](references/private-access-and-data.md): PSC, VPC Service Controls, residency, data retention.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries, OpenAI SDK, Anthropic and Claude Code.
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
