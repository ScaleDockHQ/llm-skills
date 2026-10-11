# Cerebras

Helps an agent use Cerebras Inference Cloud: create projects and keys, list models, call the OpenAI-compatible API, stay inside the dual-bucket rate limits, wire it into LiteLLM, and tear down keys and projects. It covers the Cloud Console, Shared Inference, the Cerebras SDKs and the shape of Dedicated Inference.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill cerebras
```

## Rules

- **Ask before billable or irreversible actions.** Credits, auto-recharge, keys, projects, Dedicated requests.
- **Never print keys.** Read them from a `0600` file or an environment variable.
- **List models live.** Model IDs are retired on a schedule; check Deprecations.
- **Set `max_completion_tokens`.** Limits are checked against the maximum output up front.
- **Tear down.** Delete keys, archive projects, cancel batches.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): organizations, projects, roles, API keys.
- [`references/api-and-compat.md`](references/api-and-compat.md): endpoints, SDKs, compatibility differences, errors.
- [`references/models-and-features.md`](references/models-and-features.md): catalog, deprecations, reasoning, structured outputs, caching, batch, Dedicated.
- [`references/limits-and-quotas.md`](references/limits-and-quotas.md): dual-bucket limits, project limits, spend control.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM and OpenAI-compatible clients.
- [`references/teardown.md`](references/teardown.md): revoke and archive.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `cloud-llms`: choose providers and hybrid routing.
- `llm-gateway`, `litellm`: one endpoint in front of Cerebras.
- `groq`, `together-ai`, `fireworks-ai`: other managed open-model APIs.
- `llm-evals`, `llm-observability`: quality and cost checks.
- `self-hosted-llms`, `vllm`: run on your own GPUs.

## License

MIT
