# LiteLLM Skill

An agent skill for running the [LiteLLM proxy](https://github.com/BerriAI/litellm) as a self-hosted gateway: one OpenAI- and Anthropic-compatible endpoint in front of local engines and 100+ cloud providers. It covers install (Docker Compose with Postgres, pip, Helm), `config.yaml`, model aliases with `model_info`, virtual keys, teams and budgets, routing and fallbacks, `/v1/messages` and `/v1/responses` bridging, callbacks and hooks, Langfuse and Prometheus, pinned updates with rollback, and troubleshooting. Every command is read-only first and never prints secrets.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill litellm
```

## Rules

- **Clients see aliases.** Never provider model IDs.
- **Pin the image.** Release tag plus digest; never `latest` or `main-stable`.
- **Master key is admin-only.** Consumers get scoped virtual keys; keys go to `0600` files.
- **Never change the salt key** once credentials are stored in the database.
- **Every model has `model_info`**, and local models have explicit zero cost.
- **Config before code.** Hooks are the last resort.
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): Docker, Compose, pip/uv, Helm, secrets, image tags.
- [`references/configuration.md`](references/configuration.md): config sections, endpoints, health, tuning.
- [`references/models-and-providers.md`](references/models-and-providers.md): `model_list`, `model_info`, param dropping.
- [`references/keys-budgets.md`](references/keys-budgets.md): teams, virtual keys, budgets, master key rotation.
- [`references/routing-fallbacks.md`](references/routing-fallbacks.md): strategies, retries, fallbacks, cooldowns.
- [`references/api-bridging.md`](references/api-bridging.md): Messages and Responses clients over chat backends.
- [`references/callbacks-and-hooks.md`](references/callbacks-and-hooks.md): callbacks and custom hooks.
- [`references/observability.md`](references/observability.md): Langfuse, OTel, Prometheus, logs.
- [`references/updating.md`](references/updating.md): release cycle, upgrade, rollback, migrations, backups.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/`](references/combos): llama-swap, Langfuse, Claude Code.

Templates: [`assets/litellm-config.yaml`](assets/litellm-config.yaml), [`assets/docker-compose.yaml`](assets/docker-compose.yaml), [`assets/litellm.env.example`](assets/litellm.env.example).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `llm-gateway`: choose a gateway and the stack workflow around it.
- `llama-swap`: swapper behind LiteLLM.
- `self-hosted-llms`: engines and the full server stack.
- `llm-clients`: connect agents, IDEs and SDKs.
- `llm-observability`: dashboards and alerts.
- `cloud-llms`: provider accounts and pricing.

## License

MIT
