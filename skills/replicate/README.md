# Replicate

Helps an agent use Replicate: run hosted models through the predictions API or the replicate clients, push your own with Cog, run deployments, verify webhooks, keep spend bounded and delete what you stop using. Replicate is part of Cloudflare and keeps its brand and API. It has no documented OpenAI-compatible endpoint, so chat goes through LiteLLM's `replicate/` provider.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill replicate
```

## Rules

- **Ask before creating billable resources.** Deployments, private models, warm instances and top-ups.
- **Secrets never print.** The `r8_` token lives in a `0600` file or `REPLICATE_API_TOKEN`.
- **Pin versions.** Community models need a version ID, and Cog and clients are pinned.
- **Spend controls before traffic.** Small prepaid balance, `Cancel-After`, `max_instances`.
- **Outputs expire after an hour** through the API, so download them.
- **Always tear down.** Delete deployments, versions and models you created and verify.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): token, clients, CLI, MCP.
- [`references/predictions-api.md`](references/predictions-api.md): endpoints, headers, files, webhooks, retention.
- [`references/deployments-and-cog.md`](references/deployments-and-cog.md): deployments API, hardware, Cog push.
- [`references/billing-and-teardown.md`](references/billing-and-teardown.md): billing, limits, spend controls, deletion.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM, Cloudflare AI Gateway, SDK use.
- [`references/troubleshooting.md`](references/troubleshooting.md): error codes and cold starts.

## Companion skills

- `cloud-llms`: compare Replicate with other cloud options.
- `llm-gateway`: LiteLLM routing and budgets.
- `self-hosted-genmedia`: image, video and audio models on your own GPUs.
- `choosing-llm-hosting`: laptop, owned GPUs or cloud.
- `llm-observability`: traces and cost.

## License

MIT
