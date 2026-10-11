# OpenAI API

Helps an agent call the first-party OpenAI API (api.openai.com) safely from code or behind a gateway: project-scoped keys, Responses and Chat Completions, streaming, function calling, Structured Outputs, Batch, prompt caching, rate-limit and spend controls, data retention and Zero Data Retention, LiteLLM routes, and a verified teardown. Commands read keys from environment variables or `0600` files and never print them.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill openai-api
```

## Rules

- **Ask before creating billable or persistent resources.** Keys, projects, batches, files and stored responses need approval and a teardown plan.
- **Secrets never touch output.** Keys come from environment variables or `0600` files.
- **Budget controls before traffic.** Spend alerts only notify; a hard limit returns `429`.
- **Pin model snapshots** and re-list `/v1/models` for shutdown dates.
- **Never hardcode prices or limits.** Read the pricing page, console Limits page and rate-limit headers.
- **Always tear down.** Revoke test keys, delete files, batches and stored responses.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): organizations, projects, keys, expiry, Admin API.
- [`references/api-and-sdks.md`](references/api-and-sdks.md): Responses and Chat Completions, SDKs, model listing.
- [`references/features.md`](references/features.md): streaming, tools, Structured Outputs, Batch, caching, files.
- [`references/limits-and-budgets.md`](references/limits-and-budgets.md): tiers, headers, ramp rules, spend limits.
- [`references/data-controls.md`](references/data-controls.md): retention, ZDR, `store`, residency.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries and client base URLs.
- [`references/teardown.md`](references/teardown.md): revoke keys and delete stored objects.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom, cause, fix.

## Companion skills

- `cloud-llms`: choose between frontier APIs, hyperscalers and GPU rental.
- `llm-gateway` and `litellm`: one endpoint, virtual keys and budgets.
- `anthropic-api`, `gemini-api`: the sibling frontier APIs.
- `structured-outputs`, `llm-clients`, `llm-evals`, `llm-observability`: schema output, client config, quality and tracing.
- `choosing-llm-hosting`, `self-hosted-llms`: when data rules out an API.

## License

MIT
