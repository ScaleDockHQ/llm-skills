# LLM Gateway Skill

An agent skill for putting one OpenAI- and Anthropic-compatible endpoint in front of many local and cloud model providers. It walks an AI coding agent through choosing a gateway, installing the [LiteLLM proxy](https://github.com/BerriAI/litellm) with Postgres, registering models with stable aliases and explicit capabilities, issuing virtual keys with budgets, configuring retries and fallbacks, bridging Anthropic `/v1/messages` and OpenAI `/v1/responses` clients onto chat-completions backends, upgrading safely, and fixing the common failure modes. Every command is read-only first and never prints secrets.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill llm-gateway
```

## Rules

- **Clients see stable names.** Aliases like `coder`, never provider model IDs.
- **Pin the gateway image.** Release tag plus digest; never `latest`.
- **One master key, many virtual keys.** Admin key stays in the secret store; every consumer gets its own scoped key.
- **Config-only before code.** `model_info`, `drop_params`, aliases and fallbacks before any Python hook.
- **Every model has model_info.** Context window, output limit, tools, vision, reasoning.
- **Secrets never touch output.** `os.environ/` references, env files outside git, `jq` filters on every JSON dump.
- **Measure before and after.** Latency, errors and a real tool call around every change.

## References

The LiteLLM files below are short stack notes; each ends with a pointer to the `litellm` skill for depth (`npx skills add ScaleDockHQ/llm-skills --skill litellm`).

- [`references/choosing-a-gateway.md`](references/choosing-a-gateway.md): LiteLLM, OpenRouter, Portkey, Envoy AI Gateway (Agent Router), Kong, Cloudflare compared.
- [`references/litellm-setup.md`](references/litellm-setup.md): Docker install, Postgres, master and salt keys, config sections, health endpoints.
- [`references/models-and-providers.md`](references/models-and-providers.md): `model_list`, provider prefixes, `model_info`, aliases, dropping and passing params.
- [`references/keys-budgets.md`](references/keys-budgets.md): virtual keys, teams, budgets, rate limits, revocation, master key rotation.
- [`references/routing-fallbacks.md`](references/routing-fallbacks.md): routing strategies, retries, timeouts, fallbacks, cooldowns.
- [`references/api-bridging.md`](references/api-bridging.md): Anthropic Messages and OpenAI Responses clients over chat-only backends, with a keep-alive field lesson.
- [`references/hooks-and-callbacks.md`](references/hooks-and-callbacks.md): built-in callbacks, Prometheus, last-resort custom hooks.
- [`references/operations.md`](references/operations.md): pinning, upgrades and rollback, migrations, backups, logs.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

Templates: [`assets/litellm-config.yaml`](assets/litellm-config.yaml), [`assets/docker-compose.yaml`](assets/docker-compose.yaml), [`assets/litellm.env.example`](assets/litellm.env.example).

## Companion skills

From [ScaleDockHQ/llm-skills](https://github.com/ScaleDockHQ/llm-skills); install any of them with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `choosing-llm-hosting`: decide where models run.
- `litellm`: LiteLLM proxy in depth; the LiteLLM reference files here are short stack notes pointing to it.
- `self-hosted-llms`: engines and llama-swap behind the gateway on servers.
- `local-llms`: laptop and desktop backends.
- `cloud-llms`: hosted provider accounts and pricing.
- `llm-clients`: connect agents, IDEs, chat UIs and SDKs to the gateway.
- `llm-observability`: traces, spend dashboards, alerts.
- `llm-evals`: quality checks before and after routing changes.

## Credits

Built on the official documentation of [LiteLLM](https://docs.litellm.ai/), [OpenRouter](https://openrouter.ai/docs), [Portkey](https://github.com/Portkey-AI/gateway), [Agent Router / Envoy AI Gateway](https://github.com/theagentrouter/agent-router), [Kong AI Gateway](https://developer.konghq.com/ai-gateway/), [Cloudflare AI Gateway](https://developers.cloudflare.com/ai-gateway/) and the [Claude Code gateway guide](https://code.claude.com/docs/en/llm-gateway).

## License

MIT
