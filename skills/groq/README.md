# Groq

Helps an agent use GroqCloud for open-model inference: the OpenAI-compatible API and Responses API, service tiers (on-demand, flex, auto), tools and structured outputs, the Batch API, LoRA inference (Enterprise), organization spend limits, model permissions, data controls, LiteLLM wiring, and cleanup of files, batches, adapters and keys.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill groq
```

## Rules

- **Ask before billable or retained resources.** Batches, files, adapters and plan upgrades need approval.
- **Secrets never touch output.** Keys come from environment variables or 0600 files.
- **Pin versions.** Pin model IDs and SDKs; models get retired.
- **Budget before traffic.** Set the organization monthly spend limit and use one project per workload.
- **Verify per model.** Strict structured outputs, caching and built-in tools differ by model.
- **Clean up.** Delete batch files, adapters and unused keys, then list to verify.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): console, projects, keys, SDKs, data controls.
- [`references/api-and-features.md`](references/api-and-features.md): compatibility gaps, tiers, tools, structured outputs, caching.
- [`references/batch-and-lora.md`](references/batch-and-lora.md): Batch and Files APIs, LoRA adapters.
- [`references/limits-and-spend.md`](references/limits-and-spend.md): rate limits, spend limits, model permissions.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM and client settings.
- [`references/teardown.md`](references/teardown.md): cleanup.
- [`references/troubleshooting.md`](references/troubleshooting.md): errors and fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow and cost model.
- `llm-gateway`: gateway, fallbacks and budgets.
- `llm-evals`: compare quality before switching.
- `llm-observability`: traces and per-request cost.
- `llm-clients`: SDK and client wiring.
- `fine-tuning-llms`: train adapters elsewhere.
- `choosing-llm-hosting` and `self-hosted-llms`: when you need GPUs you control.

## License

MIT
