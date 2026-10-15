# Fireworks AI

Helps an agent use Fireworks AI for open-model APIs: OpenAI- and Anthropic-compatible serverless inference, tool calling and structured outputs, on-demand GPU deployments with `firectl`, the Batch API, supervised fine-tuning and LoRA hosting, quotas and monthly spend limits, and teardown of everything that bills.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill fireworks-ai
```

## Rules

- **Ask before creating billable resources.** Deployments, batch and training jobs, and reservations need approval and a stated delete command.
- **Secrets never touch output.** Keys come from environment variables or 0600 files and are never printed.
- **Pin versions.** Pin model IDs, `firectl` and SDK versions; the Python SDK is documented as alpha.
- **Guardrails before traffic.** Set the monthly spend limit and scale-to-zero, always pass a deployment shape.
- **Always tear down.** Delete deployments, jobs, datasets and keys, then verify with `firectl deployment list`.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): keys, service accounts, `firectl` install.
- [`references/serverless-api.md`](references/serverless-api.md): OpenAI and Anthropic compatibility, tools, structured outputs, service tiers.
- [`references/deployments.md`](references/deployments.md): shapes, `firectl deployment`, autoscaling, LoRA, reservations.
- [`references/batch-and-finetuning.md`](references/batch-and-finetuning.md): Batch API, datasets, SFT jobs.
- [`references/limits-and-spend.md`](references/limits-and-spend.md): adaptive rate limits, tiers, spend limit, GPU quotas.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries and SDK configuration.
- [`references/teardown.md`](references/teardown.md): deleting and stopping every billable resource.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms, causes and fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow and cost model.
- `llm-gateway`: gateway, fallbacks and budgets.
- `fine-tuning-llms`: training choices before paying for a job.
- `llm-evals`: compare models before switching.
- `llm-observability`: traces and per-request cost.
- `llm-clients`: SDK and client wiring.
- `choosing-llm-hosting` and `self-hosted-llms`: when to move off a managed API.

## License

MIT
