# Portkey Skill

An agent skill for the [Portkey AI Gateway](https://github.com/Portkey-AI/gateway): the MIT-licensed Node.js gateway that routes one OpenAI-compatible API to 250+ LLMs, and the hosted Portkey platform around it. It covers install (npx, Docker, Compose, Kubernetes), headers and `x-portkey-config`, configs for fallbacks, load balancing, conditional routing, retries, timeouts and caching, the `TRUSTED_CUSTOM_HOSTS` guard for local backends, what is hosted-only (Model Catalog `@provider/model`, saved configs, budgets, logs, MCP gateway), LiteLLM and Claude Code wiring, pinned updates and troubleshooting. Every command is read-only first and never prints secrets.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill portkey
```

## Rules

- **Ask before changing the system.** Installs, exposure and key changes need approval.
- **No inbound auth in the open-source gateway.** Bind to loopback and authenticate in front.
- **Pin the image.** Release tag plus digest; `main` and `latest` can differ.
- **Know hosted from open source.** Model Catalog, saved configs and budgets are hosted features.
- **One retry owner.** Do not stack gateway, client and LiteLLM retries.
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): npx, Docker, Compose, Node, Kubernetes.
- [`references/serve-config.md`](references/serve-config.md): flags, headers, endpoints, env vars, custom hosts.
- [`references/routing-and-configs.md`](references/routing-and-configs.md): strategies, retries, timeouts, cache.
- [`references/hosted-and-model-catalog.md`](references/hosted-and-model-catalog.md): hosted platform and plan differences.
- [`references/features.md`](references/features.md): guardrails, MCP gateway, metadata.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): SDKs, LiteLLM, Claude Code.
- [`references/observability.md`](references/observability.md): console, headers, logs.
- [`references/updating.md`](references/updating.md): versions, 2.0 pre-release, rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

Templates: [`assets/docker-compose.yaml`](assets/docker-compose.yaml), [`assets/config-fallback.json`](assets/config-fallback.json), [`assets/config-loadbalance.json`](assets/config-loadbalance.json), [`assets/config-conditional.json`](assets/config-conditional.json).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `llm-gateway`: choose a gateway.
- `litellm`: virtual keys, budgets, callbacks.
- `caddy`, `tailscale`, `cloudflare-tunnel`: authenticated exposure.
- `llm-clients`: connect agents, IDEs and SDKs.
- `llm-observability`: traces and dashboards.

## License

MIT
