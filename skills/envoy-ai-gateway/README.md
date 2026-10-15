# Envoy AI Gateway Skill

An agent skill for [Envoy AI Gateway](https://github.com/theagentrouter/agent-router), renamed **Agent Router** in v1.2.0: the Apache-2.0 gateway built on Envoy Gateway that routes OpenAI- and Anthropic-compatible traffic by model name to cloud providers, self-hosted servers and InferencePools, and fronts MCP servers. It covers the Kubernetes install (Envoy Gateway values, CRDs and controller charts), standalone `aigw run`, AIGatewayRoute, AIServiceBackend and BackendSecurityPolicy, upstream auth, priority fallback, token rate limits and QuotaPolicy, MCPRoute, InferencePool, metrics, traces, access logs, the compatibility matrix and upgrades. Every command is read-only first and never prints secrets.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill envoy-ai-gateway
```

## Rules

- **Ask before changing the cluster.** Helm installs, upgrades, exposure and secrets need approval.
- **Route by `x-ai-eg-model`.** No matching rule gives 404.
- **Raise the Envoy buffer limit.** The 32 KiB default breaks LLM payloads.
- **No inbound auth by default.** Add a SecurityPolicy or keep it internal.
- **Quota fails open.** Deploy its rate-limit service or set the deny flag.
- **Pin versions.** Chart and image tags explicit; check the compatibility matrix.
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): Kubernetes and standalone install, test route, uninstall.
- [`references/providers-and-auth.md`](references/providers-and-auth.md): resources, schemas, backends, TLS, credentials.
- [`references/routing-and-fallback.md`](references/routing-and-fallback.md): matching, priority, fallback, aliases, mutations.
- [`references/limits-and-quota.md`](references/limits-and-quota.md): token rate limits and QuotaPolicy.
- [`references/mcp-and-inference.md`](references/mcp-and-inference.md): MCPRoute and InferencePool.
- [`references/observability.md`](references/observability.md): metrics, tracing, access logs.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): SDKs, Claude Code, LiteLLM, agents.
- [`references/updating.md`](references/updating.md): compatibility, upgrade order, rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

Templates: `assets/gateway-vllm.yaml`, `assets/docker-compose.yaml`, `assets/fallback-policy.yaml`, `assets/quota-policy.yaml`.

## Companion skills

- `llm-gateway`: choose a gateway.
- `gateway-api-inference-extension`: InferencePool and endpoint picking.
- `litellm`: virtual keys and budgets without Kubernetes.
- `llm-clients`: pointing agents and SDKs at the gateway.
- `prometheus-grafana-llm`, `llm-observability`: dashboards and traces.

## License

MIT
