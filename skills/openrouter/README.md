# OpenRouter Skill

An agent skill for using [OpenRouter](https://openrouter.ai/docs), the hosted gateway that exposes hundreds of models through one OpenAI-compatible API. It covers keys and credit limits, model IDs and variants (`:free`, `:nitro`, `:floor`, `:exacto`), provider routing and `models` fallbacks, data controls (ZDR, guardrails, regional domains), BYOK, presets and response caching, Broadcast and generation stats, LiteLLM and Claude Code wiring, teardown and error troubleshooting (402, 403, 429, 503). OpenRouter cannot be self-hosted, so there is no install workflow. Every command is read-only first and never prints secrets.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill openrouter
```

## Rules

- **Ask before spending or retaining.** Credits, auto top-up, BYOK, guardrails and ZDR changes need approval.
- **Limit every key.** One key per workload, each with a credit limit.
- **Be explicit about data.** Set `data_collection`, `zdr` or a guardrail before sensitive prompts.
- **Route with intent.** `order`, `sort` and `allow_fallbacks` change load balancing and failure behavior.
- **Never hardcode prices or quotas.** Read them from the API.
- **Secrets never touch output.**

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): account, keys, base URLs, management keys.
- [`references/api-and-models.md`](references/api-and-models.md): endpoints, model IDs, variants, errors.
- [`references/routing-and-fallbacks.md`](references/routing-and-fallbacks.md): provider object, sort, fallbacks, routers.
- [`references/data-controls.md`](references/data-controls.md): ZDR, guardrails, BYOK, regions.
- [`references/limits-and-budgets.md`](references/limits-and-budgets.md): credit, budget and rate limits, workspaces.
- [`references/features.md`](references/features.md): presets, caching, structured outputs, tools.
- [`references/observability.md`](references/observability.md): Broadcast, generation stats, router metadata.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM, Claude Code, SDKs.
- [`references/teardown.md`](references/teardown.md): keys, BYOK, presets, credits.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms, causes, fixes.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `llm-gateway`: choose a gateway.
- `litellm`: self-hosted gateway that can front OpenRouter.
- `cloud-llms`: direct provider accounts.
- `llm-clients`: connect agents, IDEs and SDKs.
- `llm-observability`: traces and dashboards.

## License

MIT
