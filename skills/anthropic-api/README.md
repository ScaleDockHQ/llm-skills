# Anthropic Claude API

Helps an agent call the first-party Claude API (api.anthropic.com) safely from code or behind a gateway: workspace-scoped keys with expiry or Workload Identity Federation, the native Messages API, the OpenAI SDK compatibility layer and its limits, streaming, tools, structured outputs, Message Batches, prompt caching, rate and spend limits, ZDR, LiteLLM routes and a verified teardown. Commands read keys from environment variables or `0600` files and never print them.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill anthropic-api
```

## Rules

- **Ask before creating billable or persistent resources.** Keys, workspaces, batches, files and limits need approval and a teardown plan.
- **Secrets never touch output.** Keys come from environment variables or `0600` files.
- **Spend limit before traffic.** A limit you set returns `400`; the tier cap returns `429` without `retry-after`.
- **Use native features deliberately.** The OpenAI layer ignores `strict`, `response_format` and caching.
- **Pin model IDs** and check `lifecycle` and `retires_at`.
- **Always tear down.** Deactivate keys, delete files and batches, archive test workspaces.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): key types, expiry, workspaces, WIF, Admin API, `ant` CLI.
- [`references/api-and-sdks.md`](references/api-and-sdks.md): Messages API, SDKs, model listing, OpenAI compatibility limits.
- [`references/features.md`](references/features.md): streaming, tools, structured outputs, Batches, caching, Files.
- [`references/limits-and-budgets.md`](references/limits-and-budgets.md): tiers, headers, ITPM and OTPM, spend and workspace limits.
- [`references/data-controls.md`](references/data-controls.md): ZDR, HIPAA readiness, Covered Models, `inference_geo`.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries and client base URLs.
- [`references/teardown.md`](references/teardown.md): revoke and delete everything.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom, cause, fix.

## Companion skills

- `cloud-llms`: choose between frontier APIs, hyperscalers and GPU rental.
- `llm-gateway` and `litellm`: one endpoint, virtual keys and budgets.
- `openai-api`, `gemini-api`, `aws-bedrock`: sibling providers.
- `structured-outputs`, `llm-clients`, `llm-evals`, `llm-observability`: schema output, clients, quality and tracing.
- `choosing-llm-hosting`, `self-hosted-llms`: when data rules out an API.

## License

MIT
