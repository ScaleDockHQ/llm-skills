# DeepInfra

Helps an agent use DeepInfra: create and limit API keys, call the OpenAI and Anthropic compatible endpoints, use batch and scoped JWTs, optionally run private LLM deployments or rent GPU containers, wire it into LiteLLM and Claude Code, and shut everything billable down.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill deepinfra
```

## Rules

- **Ask before billable resources.** Deployments, containers, funds.
- **Never print keys or JWTs.** Read them from a `0600` file or an environment variable.
- **Cap spend first.** Per-key monthly limits and account limits before traffic.
- **List what is running** at the start and end of a session.
- **Always tear down.** Private deployments and containers bill per GPU-hour.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): keys, scoped JWTs, data handling.
- [`references/api-and-compat.md`](references/api-and-compat.md): endpoints, Anthropic, Batch.
- [`references/models-and-features.md`](references/models-and-features.md): model listing and features.
- [`references/limits-and-spend.md`](references/limits-and-spend.md): concurrency and spend controls.
- [`references/dedicated-and-gpu.md`](references/dedicated-and-gpu.md): private deployments and GPU containers.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM, OpenAI, Claude Code.
- [`references/teardown.md`](references/teardown.md): stop and delete.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `cloud-llms`: provider choice.
- `llm-gateway`, `litellm`: gateway in front of DeepInfra.
- `together-ai`, `fireworks-ai`, `groq`: comparable APIs.
- `llm-evals`, `llm-observability`: quality and cost.
- `fine-tuning-llms`: produce weights to deploy.
- `self-hosted-llms`, `vllm`: your own GPUs.

## License

MIT
