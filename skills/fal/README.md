# fal

Helps an agent use fal (fal.ai): call hosted image, video, audio and 3D models through the queue API, `fal-client` or the `genmedia` CLI, reach LLMs through fal's OpenRouter-backed endpoint, deploy your own Python `fal.App` on fal GPUs, control concurrency and spend, and tear everything down. fal is genmedia-first, so for local or self-hosted media models see the `self-hosted-genmedia` skill.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill fal
```

## Rules

- **Ask before creating billable resources.** Deploys, warm runners and credit purchases need approval.
- **Secrets never print.** `FAL_KEY` lives in a `0600` file. Use narrow key presets with an expiry. Never ship it to a browser.
- **Pin versions** of `fal`, `fal-client` and app requirements.
- **Budget before traffic.** Prepaid credit, low `max_concurrency`, short `keep_alive`.
- **Mind retention.** Payloads are stored 30 days by default and CDN media expires.
- **Always tear down.** Scale to zero or delete apps, revoke keys and verify.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): keys, clients, `genmedia`, serverless CLI.
- [`references/model-apis.md`](references/model-apis.md): queue, sync, webhooks, headers, retention.
- [`references/serverless.md`](references/serverless.md): `fal.App`, deploy, scale, revisions.
- [`references/billing-and-teardown.md`](references/billing-and-teardown.md): billing, concurrency, price lookup, deletion.
- [`references/litellm-and-llms.md`](references/litellm-and-llms.md): LiteLLM and OpenAI-compatible text routes.
- [`references/troubleshooting.md`](references/troubleshooting.md): error types and fixes.

## Companion skills

- `self-hosted-genmedia`: image, video and audio models on your own GPUs.
- `cloud-llms`: compare fal with other cloud options.
- `llm-gateway`: LiteLLM routing and budgets.
- `choosing-llm-hosting`: laptop, owned GPUs or cloud.
- `llm-observability`: traces and cost.

## License

MIT
