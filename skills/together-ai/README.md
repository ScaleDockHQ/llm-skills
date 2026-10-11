# Together AI

Helps an agent use Together AI for open-model APIs: the OpenAI-compatible serverless API, dedicated model inference (endpoints and deployments), the Batch API, fine-tuning, projects and API keys, spend controls, and complete teardown of everything that bills. Covers the `tg` CLI, the `together` SDKs, and LiteLLM and OpenAI-client wiring.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill together-ai
```

## Rules

- **Ask before creating billable resources.** Dedicated deployments, fine-tune jobs, batches, clusters and credit purchases need approval and a stated stop command.
- **Secrets never touch output.** Keys come from environment variables or 0600 files and are never printed.
- **Pin versions.** Pin namespaced model IDs, SDK and CLI versions.
- **Guardrails before traffic.** Use a project and key per workload; Together has balance cut-off and cost analytics but no per-key limits.
- **Always tear down.** Dedicated endpoints bill per minute while ready; set an inactivity timeout and delete when done.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): projects, keys, CLI and SDK install, identity checks.
- [`references/serverless-api.md`](references/serverless-api.md): OpenAI compatibility, tools, structured outputs, reasoning fields.
- [`references/dedicated-inference.md`](references/dedicated-inference.md): endpoints, deployments, autoscaling, idle shutdown, v1 migration.
- [`references/batch-and-finetuning.md`](references/batch-and-finetuning.md): Batch and Files APIs, fine-tuning and deployment.
- [`references/limits-and-spend.md`](references/limits-and-spend.md): rate limits, spend controls, cost analytics, GPU quota.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries and OpenAI-compatible clients.
- [`references/teardown.md`](references/teardown.md): deleting every billable resource and revoking keys.
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
