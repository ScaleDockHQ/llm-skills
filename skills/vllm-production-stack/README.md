# vLLM production-stack

Teaches an agent to deploy and run the vLLM project's production-stack Helm chart (`vllm-stack`) on Kubernetes: a
router plus per-model serving engines with LMCache KV offload, routing logics, KEDA autoscaling and Grafana. It covers
install, `values.yaml`, routing, features, scaling, upgrades and troubleshooting, verified against chart 0.1.13.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill vllm-production-stack
```

## Rules

- **Ask before changing the cluster.** Show `helm template` or a dry run and the uninstall command first.
- **Pin chart and images.** Chart defaults use `latest` tags.
- **Secrets by reference.** `hf_token` and `vllmApiKey` use Secret names and keys, never inline values.
- **Match routing to the engine image.** `kvaware` and offload need an LMCache-enabled image.
- **Mind the chart schema.** 0.1.13 rejects `priority` and `loadaware` routing in values.

## References

- [`references/install.md`](references/install.md): Helm repo, versions, prerequisites, operator alternative.
- [`references/values.md`](references/values.md): `servingEngineSpec`, `modelSpec`, `routerSpec`, secrets.
- [`references/routing.md`](references/routing.md): routing logics and their requirements.
- [`references/features.md`](references/features.md): LMCache, LoRA, tools, sleep mode, Ray.
- [`references/scaling-and-observability.md`](references/scaling-and-observability.md): KEDA, metrics, dashboards.
- [`references/updating.md`](references/updating.md): upgrade and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/`](templates/): minimal and prefix-aware plus KEDA values.

## Companion skills

- `vllm`: engine flags and parsers. `npx skills add ScaleDockHQ/llm-skills --skill vllm`
- `llm-d`: scheduler-based alternative. `npx skills add ScaleDockHQ/llm-skills --skill llm-d`
- `kserve`: CRD-based platform. `npx skills add ScaleDockHQ/llm-skills --skill kserve`
- `keda`: event-driven autoscaling. `npx skills add ScaleDockHQ/llm-skills --skill keda`

## License

MIT
