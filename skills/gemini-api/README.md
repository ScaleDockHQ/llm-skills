# Google Gemini API

Helps an agent call the Gemini Developer API (generativelanguage.googleapis.com) safely from code or behind a gateway: restricted auth keys, Prepay and Postpay billing, tiers and spend caps, `generateContent` and the Interactions API, the OpenAI compatibility layer, streaming, structured output, Batch, context caching, Files, paid vs unpaid data terms, LiteLLM routes and a clean teardown. Commands read keys from environment variables or `0600` files and never print them.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill gemini-api
```

## Rules

- **Ask before creating billable or persistent resources.** Keys, projects, credits, auto-reload, caches, files and batches need approval and a teardown plan.
- **Secrets never touch output.** Send keys in the `x-goog-api-key` header from environment variables or `0600` files.
- **No sensitive data on free quota.** Only paid services keep content out of product improvement.
- **Know the Prepay stop.** A zero balance returns `402` for every key on the billing account.
- **Spend caps lag.** Treat them as experimental, especially with batch jobs.
- **Always tear down.** Delete files and caches, check batches, disable keys.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): key types, projects, restrictions, leak response.
- [`references/api-and-sdks.md`](references/api-and-sdks.md): generateContent, Interactions API, OpenAI compatibility.
- [`references/features.md`](references/features.md): streaming, tools, structured output, Batch, caching, Files.
- [`references/limits-and-budgets.md`](references/limits-and-budgets.md): tiers, rate limits, billing plans, spend caps.
- [`references/data-controls.md`](references/data-controls.md): paid vs unpaid terms, grounding storage, retention.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries and client base URLs.
- [`references/teardown.md`](references/teardown.md): disable keys and delete stored objects.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom, cause, fix.

## Companion skills

- `cloud-llms`: choose between frontier APIs, hyperscalers and GPU rental.
- `llm-gateway` and `litellm`: one endpoint, virtual keys and budgets.
- `google-vertex-ai`: Gemini on Google Cloud with IAM and regions.
- `openai-api`, `anthropic-api`: sibling providers.
- `structured-outputs`, `llm-clients`, `llm-evals`, `llm-observability`: schema output, clients, quality and tracing.
- `choosing-llm-hosting`, `self-hosted-llms`: when data rules out an API.

## License

MIT
