# Bifrost

Helps an agent install and run Bifrost, the open-source Go AI gateway: start it with npx, Docker or Kubernetes, add providers (including self-hosted vLLM and Ollama), configure it with `config.json`, issue virtual keys with budgets and rate limits, set retries and fallbacks, observe it with Prometheus and OpenTelemetry, connect Claude Code and SDKs, migrate from LiteLLM, update and tear it down.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill bifrost
```

## Rules

- **Pin versions in production.** The unversioned quick-start commands are for local evaluation.
- **Never print keys.** Use `env.NAME` references and `0600` files.
- **Turn on auth before exposing it.** The first admin needs a setup token.
- **OSS is single node.** Multi-replica HA needs Enterprise.
- **Virtual keys are deny-by-default.** Grant providers explicitly.

## References

- [`references/install.md`](references/install.md): npx, Docker, storage, Kubernetes.
- [`references/configuration.md`](references/configuration.md): flags, `config.json`, providers.
- [`references/governance.md`](references/governance.md): auth, virtual keys, budgets.
- [`references/routing-and-fallbacks.md`](references/routing-and-fallbacks.md): retries and fallbacks.
- [`references/observability.md`](references/observability.md): logs, metrics, semantic cache.
- [`references/integrations.md`](references/integrations.md): SDKs, Claude Code, LiteLLM migration.
- [`references/updating.md`](references/updating.md): releases and upgrades.
- [`references/teardown.md`](references/teardown.md): stop and delete.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `llm-gateway`, `litellm`: gateway design and the main alternative.
- `llm-observability`: wider tracing.
- `vllm`, `ollama`: self-hosted providers.
- `caddy`, `cloudflare-tunnel`, `tailscale`: exposure.

## License

MIT
