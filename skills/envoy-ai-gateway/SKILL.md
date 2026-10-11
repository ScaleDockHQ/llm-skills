---
name: envoy-ai-gateway
description: Install and operate Envoy AI Gateway, now renamed Agent Router (aigw), a Kubernetes and standalone gateway on Envoy Gateway for LLM and MCP traffic. Covers AIGatewayRoute, AIServiceBackend, BackendSecurityPolicy, fallback, token rate limits, QuotaPolicy, InferencePool and Helm upgrades. Use for Envoy AI Gateway, Agent Router, aigw run, x-ai-eg-model, MCPRoute, ai-gateway-helm, or a 429/413 through it. Not for gateway choice (llm-gateway); for a simple proxy see litellm.
license: MIT
compatibility: Kubernetes 1.32+ with Helm and kubectl for the full gateway, or Linux/macOS (or Docker) for standalone aigw. Needs outbound access to providers. Cluster installs, exposure, secrets and Envoy Gateway changes need explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Envoy AI Gateway (Agent Router)

A working Envoy AI Gateway: one OpenAI- and Anthropic-compatible endpoint, built on Envoy Gateway, that routes by model name to cloud providers, self-hosted servers (vLLM, Ollama) or InferencePools, with upstream credentials, fallback, token-based limits, metrics, traces and an MCP gateway. Also the know-how to run it standalone with `aigw run`, upgrade it and troubleshoot it.

**Scope:** this one product. The project was renamed **Agent Router** in v1.2.0 (2026-10-07; repo `theagentrouter/agent-router`, site theagentrouter.ai; old `envoyproxy/ai-gateway` links redirect). The API group `aigateway.envoyproxy.io`, CRDs, Helm charts, images and the `aigw` CLI keep their names, so this skill uses both names. Choosing a gateway belongs to `llm-gateway`. For a gateway without Kubernetes and with virtual keys and budgets, use `litellm`.

Work through the steps in order. Load a reference only when a step names it. Docs, release notes and the v1.2.0 repo were read on 2026-10-11.

## Discover first

Read-only. Never print secret values.

```bash
kubectl config current-context && kubectl version -o json | jq -r '.serverVersion.gitVersion'
helm list -A 2>/dev/null | grep -Ei 'aieg|ai-gateway|gateway-helm|^eg\b' || true
kubectl get crd 2>/dev/null | grep -E 'aigateway.envoyproxy.io|gateway.envoyproxy.io|inference.networking' || true
kubectl get deploy -n envoy-ai-gateway-system -o wide 2>/dev/null
kubectl get deploy -n envoy-gateway-system -o wide 2>/dev/null
kubectl get aigatewayroutes,aiservicebackends,backendsecuritypolicies,mcproutes -A 2>/dev/null
command -v aigw && aigw version
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i 'ai-gateway' || true
gh api repos/theagentrouter/agent-router/releases/latest --jq '.tag_name + " " + .published_at'
```

Ask only what discovery cannot show: Kubernetes or a single host, which providers or self-hosted servers, where keys live, who the clients are, whether the endpoint leaves the cluster, and whether token limits or MCP are needed.

## Decision flow

1. **No Kubernetes, want to try it or run it on one host:** standalone `aigw run` (port 1975). -> `references/install.md`
2. **Kubernetes cluster:** install Envoy Gateway with the project's values file, then the two AI Gateway charts. A clean Envoy Gateway is required; an existing customized one can conflict. -> `references/install.md`
3. **Add a provider or backend (OpenAI-compatible, Bedrock, Azure, Vertex, Anthropic, vLLM):** AIServiceBackend plus Backend plus BackendSecurityPolicy. -> `references/providers-and-auth.md`
4. **Routing, fallback, model aliases, header and body mutation:** -> `references/routing-and-fallback.md`
5. **Per-tenant token limits or a provider budget:** usage-based rate limits (Envoy Gateway ratelimit plus Redis) versus QuotaPolicy (dedicated service plus Redis). -> `references/limits-and-quota.md`
6. **Agents and tools (MCP) or GPU pools with endpoint picking:** -> `references/mcp-and-inference.md`
7. **Metrics, traces, access logs:** -> `references/observability.md`
8. **Clients, LiteLLM, Claude Code, Goose:** -> `references/litellm-and-clients.md`
9. **Upgrade, compatibility, v1alpha1 to v1beta1:** -> `references/updating.md`
10. **Error or odd behavior (404, 413, 429, 5xx, fallback not firing):** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the cluster.** Helm installs, Envoy Gateway upgrades, Gateway exposure and secrets need approval and an undo path (`helm history`, recorded chart versions).
- **Route by `x-ai-eg-model`.** The gateway copies the request's `model` into that header; AIGatewayRoute rules match on it. A model with no matching rule gets 404.
- **Raise the Envoy buffer limit.** Envoy Gateway defaults to 32 KiB. A `ClientTrafficPolicy` with `bufferLimit` (the project example uses 50Mi) is needed for normal prompts and responses.
- **No inbound auth by default.** Anyone who can reach the Gateway can spend your provider keys. Add Envoy Gateway SecurityPolicy (JWT, API key, ext auth) or keep it cluster-internal and bind `aigw` to loopback.
- **Keys live in Kubernetes Secrets or env vars.** Never in manifests in git; prefer short-lived cloud identity (AWS OIDC/IRSA, Azure Entra, GCP workload federation) over long-lived keys.
- **Quota fails open.** `QuotaPolicy` without its dedicated rate-limit service does not enforce anything unless `controller.quotaRateLimitFailureModeDeny` is `true`.
- **Pin versions.** Chart and image versions are explicit (`v1.2.0`); `latest` and `v0.0.0-latest` move. Check the compatibility matrix before bumping Envoy Gateway or Gateway API.
- **Use v1beta1.** `AIGatewayRoute`, `AIServiceBackend`, `BackendSecurityPolicy`, `GatewayConfig` and `MCPRoute` are v1beta1; v1alpha1 is deprecated. `QuotaPolicy` is v1alpha1 only.
- **Verify upstream.** Versions, fields and defaults come from the repo and docs at use time.

## Workflows

### Standalone first request

- [ ] Run `aigw run` with `OPENAI_BASE_URL` and `OPENAI_API_KEY` env vars or a config file -> `references/install.md`.
- [ ] `curl http://127.0.0.1:1975/v1/chat/completions` with the backend's model; check `:1064/health` and `/metrics`.

### Kubernetes install and first route

- [ ] Preflight and install in order (Envoy Gateway, CRDs chart, controller chart) -> `references/install.md`.
- [ ] Apply `assets/gateway-vllm.yaml` (edit host, model, namespace); wait for the Envoy pod and test through port-forward.
- [ ] Add fallback or credentials -> `references/routing-and-fallback.md`, `references/providers-and-auth.md`.

### Add token limits

- [ ] Choose the policy -> `references/limits-and-quota.md`; install Redis and the addon values; verify with a tenant header.

### Upgrade or roll back

- [ ] Read the release notes and compatibility table; upgrade CRDs chart first, then the app chart -> `references/updating.md`.

### Troubleshoot

- [ ] `kubectl describe` the route, backend and policy; read controller and extproc logs -> `references/troubleshooting.md`.

## Reference index

- `references/install.md`: Kubernetes (Envoy Gateway values, CRDs, controller), standalone `aigw`, Docker, test upstream.
- `references/providers-and-auth.md`: CRDs, schemas, backends, TLS, security policies, per-request credentials.
- `references/routing-and-fallback.md`: route matching, priority and weight, fallback retry policy, aliases, mutations.
- `references/limits-and-quota.md`: llmRequestCosts, usage-based rate limits, QuotaPolicy.
- `references/mcp-and-inference.md`: MCPRoute, `aigw` MCP, InferencePool.
- `references/observability.md`: Prometheus metrics, OTel tracing, access logs, GatewayConfig.
- `references/litellm-and-clients.md`: LiteLLM, SDKs, Claude Code, agents.
- `references/updating.md`: compatibility matrix, upgrade order, v1.2.0 breaking changes, rollback.
- `references/troubleshooting.md`: symptom to cause to fix.

Templates: `assets/gateway-vllm.yaml`, `assets/docker-compose.yaml`, `assets/fallback-policy.yaml`, `assets/quota-policy.yaml`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-gateway`: choose a gateway and the stack workflow around it.
- `gateway-api-inference-extension`: InferencePool and the endpoint picker in depth.
- `litellm`: a Python proxy with virtual keys and budgets, no Kubernetes needed.
- `llm-clients`: pointing agents, IDEs and SDKs at the gateway.
- `prometheus-grafana-llm`, `llm-observability`: dashboards and traces for the metrics it emits.
- `vllm`, `ollama`: common self-hosted backends.
