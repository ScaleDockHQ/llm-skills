# SambaNova

Helps an agent use SambaNova SambaCloud: create keys, list models, call the OpenAI, Responses and Anthropic Messages endpoints, respect tier limits and deprecations, wire it into LiteLLM and coding tools, and revoke keys. SambaStack is covered only as the dedicated route.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill sambanova
```

## Rules

- **Ask before billable or account changes.** Payment method, keys, sales contact.
- **Never print keys.** Keys are shown once; store them in a `0600` file or an environment variable.
- **List models live and read the deprecation page.** Retired models return `410`.
- **Preview models are not for production.**
- **Tear down.** Delete keys and remove them from configs.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): products, keys, tiers.
- [`references/api-and-compat.md`](references/api-and-compat.md): endpoints, compatibility, errors.
- [`references/models-and-features.md`](references/models-and-features.md): models, deprecations, caching.
- [`references/limits-and-quotas.md`](references/limits-and-quotas.md): tiers, headers, 429 variants.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM, OpenAI and Anthropic clients.
- [`references/teardown.md`](references/teardown.md): cleanup.
- [`references/troubleshooting.md`](references/troubleshooting.md): error table.

## Companion skills

- `cloud-llms`: provider choice and hybrid routing.
- `llm-gateway`, `litellm`: gateway in front of SambaNova.
- `cerebras`, `groq`, `together-ai`: other fast managed APIs.
- `llm-evals`, `llm-observability`: quality and cost.
- `self-hosted-llms`: owned GPUs.

## License

MIT
