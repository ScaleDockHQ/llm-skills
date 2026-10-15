# Gateway API Inference Extension

Helps an agent put an inference-aware load balancer in front of vLLM or SGLang pods on Kubernetes: the
`InferencePool` API, an `HTTPRoute` from a Gateway, and the Endpoint Picker (EPP) that now ships from llm-d-router
with its Helm charts. It covers install order, model-server requirements, routing and flow-control config, HA, metrics,
migration from the old GAIE charts and troubleshooting. Verified against GAIE v1.6.2 and llm-d router v0.11.0.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill gateway-api-inference-extension
```

## Rules

- **Ask before changing the system.** CRDs are cluster-wide; Helm releases and routes change live traffic.
- **Pin versions.** CRD manifest, chart `--version`, EPP image tag; never `main`.
- **One EPP, one base model per pool,** and the selector must match pod labels exactly.
- **Choose the failure mode on purpose.** API default `FailClose`; the chart sets `FailOpen`.
- **No client auth in the router.** Authenticate at the Gateway or in front.

## References

- [`references/install.md`](references/install.md): CRDs, gateways, router charts, standalone mode.
- [`references/inferencepool-and-routes.md`](references/inferencepool-and-routes.md): pool, route, pod requirements.
- [`references/epp-and-routing.md`](references/epp-and-routing.md): plugins, priorities, flow control, HA, sizing.
- [`references/observability.md`](references/observability.md): metrics and status.
- [`references/updating.md`](references/updating.md): upgrades and chart migration.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/vllm-pods.md`](references/combos/vllm-pods.md), [`references/combos/litellm-in-front.md`](references/combos/litellm-in-front.md).
- [`templates/`](templates): pool, route, chart values, vLLM Deployment.

## Companion skills

- `llm-d-vllm-kubernetes`: the full llm-d stack.
- `vllm`: model server flags and metrics.
- `prefix-aware-routing`: technique-level routing guidance.
- `keda`: scale the pool on queue and GPU metrics.
- `litellm`: keys and budgets in front.

## License

MIT
