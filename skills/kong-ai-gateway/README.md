# Kong AI Gateway Skill

An agent skill for [Kong AI Gateway](https://developer.konghq.com/ai-gateway/): one OpenAI-compatible endpoint in front of cloud and self-hosted models. It covers Kong's three forms: `ai-proxy` and the prompt plugins on free Kong Gateway OSS 3.x, the paid Enterprise plugins (`ai-proxy-advanced`, token rate limits, semantic cache, guardrails, MCP), and the 2.x Konnect entity model managed with kongctl. It includes a parse-tested OSS DB-less recipe, Helm and Operator installs, balancing and failover, OpenTelemetry, upgrades and the 3.x to 2.x conversion. Every command is read-only first and never prints secrets.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill kong-ai-gateway
```

## Rules

- **Tier before design.** OSS has `ai-proxy`; failover, token limits, cache and guardrails are paid or 2.x.
- **Add inbound auth.** The proxy is open by default.
- **Keys stay out of git.** decK env templating, Vault references or kongctl `!secret`.
- **OSS Admin API has no auth.** Keep it on loopback.
- **Provider lists differ by build.** OSS 3.9.3 uses `llama2` for self-hosted OpenAI servers.
- **Pin versions.** Image tags and the Helm `image.tag`.
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): OSS, Enterprise, 2.x quickstart, Helm, Operator.
- [`references/plugins-ai-proxy.md`](references/plugins-ai-proxy.md): tier table, `ai-proxy`, upstreams, auth.
- [`references/ai-gateway-2.md`](references/ai-gateway-2.md): 2.x entities and kongctl.
- [`references/balancing-and-limits.md`](references/balancing-and-limits.md): balancer, failover, token limits.
- [`references/guardrails-cache-mcp.md`](references/guardrails-cache-mcp.md): guardrails, cache, MCP, A2A.
- [`references/observability.md`](references/observability.md): logging and OTel metrics.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): SDKs, Claude Code, LiteLLM.
- [`references/updating.md`](references/updating.md): versions, upgrades, migration.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms, logs, teardown.

Templates: `assets/docker-compose.yaml`, `assets/kong-ai-proxy.yaml`, `assets/kong-ai-proxy-advanced.yaml`, `assets/ai-gateway-2.kongctl.yaml`, `assets/helm-values-kong-ai-gateway.yaml`.

## Companion skills

- `llm-gateway`: choose a gateway.
- `litellm`: virtual keys and budgets.
- `llm-clients`: pointing agents and SDKs at the gateway.
- `opentelemetry-genai`, `prometheus-grafana-llm`, `llm-observability`: metrics and traces.
- `vllm`, `ollama`: self-hosted upstreams.

## License

MIT
