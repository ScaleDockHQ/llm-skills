---
name: kong-ai-gateway
description: Set up and operate Kong AI Gateway in three forms, ai-proxy on Kong Gateway OSS 3.x, ai-proxy-advanced and token rate limits on Enterprise, or the 2.x Konnect entity model with kongctl. Covers providers, vLLM and Ollama upstreams, auth, balancing, caching, guardrails, MCP, OTel and upgrades. Use for Kong AI Gateway, ai-proxy, kong-ai-gateway image, AIGatewayModel, or a 401/429 through Kong. Not for gateway choice (llm-gateway); for a simple proxy see litellm.
license: MIT
compatibility: Docker plus decK for the OSS DB-less recipe; Kong Gateway Enterprise needs a license; AI Gateway 2.x needs a Konnect account, a personal access token and kongctl 1.20.2 or newer. Installs, ports, secrets and Konnect changes need explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Kong AI Gateway

A working Kong AI Gateway: one OpenAI-compatible endpoint in front of cloud providers or self-hosted servers (vLLM, Ollama), with inbound auth, provider credentials, and, on paid tiers, load balancing, token limits, semantic cache, guardrails, MCP and A2A. Also how to choose among Kong's three forms, upgrade and troubleshoot.

**Scope:** this one product, which comes in three forms. Choosing a gateway belongs to `llm-gateway`; a plain Python proxy with virtual keys is `litellm`.

| Form                                   | What it is                                                                                                             | Licence and place                    |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| Plugins on Kong Gateway OSS 3.x        | `ai-proxy`, prompt plugins, request and response transformers                                                          | free, self-managed                   |
| Plugins on Kong Gateway Enterprise 3.x | adds `ai-proxy-advanced`, `ai-rate-limiting-advanced`, `ai-semantic-cache`, guardrails, `ai-mcp-proxy`, `ai-sanitizer` | licence, self-managed or Konnect     |
| AI Gateway 2.x                         | Konnect control plane with Model, Provider, Policy, MCP Server and Agent entities, `kong/kong-ai-gateway` data plane   | Konnect account, data plane anywhere |

Work through the steps in order. Load a reference only when a step names it. Docs, Docker Hub tags, Helm index and plugin schemas were read on 2026-10-11; the OSS recipe was parse-tested on `kong:3.9.3`. The Enterprise and Konnect paths were not run.

## Discover first

Read-only. Never print secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i kong || true
curl -s http://127.0.0.1:8101/ 2>/dev/null | jq -r '.version' || true       # Admin API of the assets/docker-compose.yaml recipe
curl -s http://127.0.0.1:8101/plugins/enabled 2>/dev/null | jq -r '.enabled_plugins[]' | grep '^ai-' || true
kubectl get deploy,svc -A 2>/dev/null | grep -i kong || true
helm list -A 2>/dev/null | grep -i kong || true
deck version 2>/dev/null; kongctl version 2>/dev/null
[ -n "$KONNECT_TOKEN" ] && echo "KONNECT_TOKEN set" || echo "KONNECT_TOKEN unset"      # presence only
```

Ask only what discovery cannot show: self-hosted or Konnect, Enterprise licence or not, which providers or local servers, who the clients are, whether the endpoint leaves the network, and whether token limits, cache or MCP are needed.

## Decision flow

1. **Choose the form.** Free and one host, or a need for failover, token limits, cache or guardrails? OSS gives `ai-proxy` only; those features are paid (Enterprise plugins or 2.x). A new Konnect user wanting the AI-native model takes 2.x. -> `references/plugins-ai-proxy.md` (tier table), `references/ai-gateway-2.md`
2. **Install.** OSS DB-less Docker, Enterprise Docker, 2.x quickstart, Helm (`kong/kong-ai-gateway`) or Kong Operator. -> `references/install.md`
3. **Providers, route types, self-hosted upstreams, inbound auth:** -> `references/plugins-ai-proxy.md` (3.x), `references/ai-gateway-2.md` (2.x)
4. **Balancing, fallback, token limits, cost:** -> `references/balancing-and-limits.md`
5. **Cache, guardrails, MCP, A2A:** -> `references/guardrails-cache-mcp.md`
6. **Logs, metrics, traces:** -> `references/observability.md`
7. **Clients, Claude Code, LiteLLM:** -> `references/litellm-and-clients.md`
8. **Upgrade, 3.x to 2.x migration, version lines:** -> `references/updating.md`
9. **Error or odd behavior, teardown:** -> `references/troubleshooting.md`

## Rules

- **Tier before design.** Check the plugin page's tier before promising a feature. An OSS image without the plugin fails at load; Enterprise plugins need a valid licence. What unlicensed Enterprise does was not documented in the pages read.
- **Add inbound auth.** `ai-proxy` and 2.x models without an auth strategy are open to anyone who reaches the proxy and spend your provider keys. Use `key-auth` (header name from `key_names`), OIDC or an AI Auth Strategy, with `hide_credentials: true`.
- **Keys never in files in git.** Inject with decK `${{ env "DECK_..." }}`, Vault references (`x-referenceable` fields), or kongctl `!secret {source: !env VAR}`. A rendered DB-less file contains secrets: `umask 077`, do not commit it.
- **The OSS Admin API has no auth.** Keep it on loopback (the template publishes 127.0.0.1 only); never expose 8001.
- **Provider lists differ by build.** OSS 3.9.3 rejects `vllm`; use `llama2` with `llama2_format: openai` there. Read `/schemas/plugins/ai-proxy` for the running build.
- **Payload logging is off by default.** `log_payloads` stores prompts and answers; enable only with agreement.
- **Pin versions.** Image tags (`kong:3.9.3`, `kong/kong-gateway:3.16.0.0`, `kong/kong-ai-gateway:2.2.0`) and the Helm `image.tag` (the chart default lags).
- **Ask before** installs, `docker compose down -v`, `kongctl sync` (deletes absent resources), Konnect control-plane changes and secret rotation. No prices are stored here; supply costs from your provider.
- **Verify upstream.** Field names and defaults come from the plugin reference and entity pages at use time.

## Workflows

### OSS first request

- [ ] Render the decK file from `assets/kong-ai-proxy.yaml`, validate with `kong config parse`, start `assets/docker-compose.yaml` -> `references/install.md`.
- [ ] `curl` the route on 127.0.0.1:8100; add `key-auth` before any exposure.

### Enterprise balancing and limits

- [ ] Licence in place, `assets/kong-ai-proxy-advanced.yaml` adapted, `deck gateway diff` then `sync` -> `references/balancing-and-limits.md`.

### AI Gateway 2.x

- [ ] Control plane and data plane (quickstart, Helm or Operator) -> `references/install.md`.
- [ ] `kongctl plan` then `apply` of `assets/ai-gateway-2.kongctl.yaml` -> `references/ai-gateway-2.md`.

### Troubleshoot

- [ ] Status, plugin list, headers and logs, then the symptom table -> `references/troubleshooting.md`.

## Reference index

- `references/install.md`: OSS, Enterprise, 2.x quickstart, Helm, Operator, discovery commands.
- `references/plugins-ai-proxy.md`: tier table, `ai-proxy` fields, self-hosted upstreams, prompt plugins, inbound auth.
- `references/ai-gateway-2.md`: 2.x entities, kongctl, models, providers, auth strategies, policies.
- `references/balancing-and-limits.md`: balancer, failover, circuit breaker, token rate limits, cost.
- `references/guardrails-cache-mcp.md`: guardrail plugins, semantic cache, MCP, A2A.
- `references/observability.md`: logging fields, OTel policy and metrics.
- `references/litellm-and-clients.md`: SDKs, Claude Code, LiteLLM, key header caveat.
- `references/updating.md`: version lines, upgrade steps, 3.x to 2.x conversion.
- `references/troubleshooting.md`: symptom table, logs, teardown.

Templates: `assets/docker-compose.yaml`, `assets/kong-ai-proxy.yaml`, `assets/kong-ai-proxy-advanced.yaml`, `assets/ai-gateway-2.kongctl.yaml`, `assets/helm-values-kong-ai-gateway.yaml`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-gateway`: choose a gateway and the stack workflow around it.
- `litellm`: Python proxy with virtual keys and budgets.
- `llm-clients`: pointing agents, IDEs and SDKs at the gateway.
- `opentelemetry-genai`, `prometheus-grafana-llm`, `llm-observability`: the metrics and traces Kong emits.
- `vllm`, `ollama`: common self-hosted upstreams.
