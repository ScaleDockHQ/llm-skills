# KEDA

Helps an agent autoscale LLM serving on Kubernetes with KEDA: ScaledObject and TriggerAuthentication on vLLM queue
depth (`vllm:num_requests_waiting`), KV-cache pressure, work queues and GPU metrics, with HPA tuning, fallback, scale to
zero and the HTTP add-on. Scoped to LLM autoscaling, not a general KEDA manual. Verified against KEDA v2.21.0 and HTTP
add-on v0.16.0.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill keda
```

## Rules

- **Ask before changing the system.** Helm releases, CRDs, ScaledObjects and annotations need approval.
- **Secrets stay out of output.** Credentials live in Secrets referenced by `TriggerAuthentication`.
- **One scaler per workload.** No second HPA and no KEDA on Ray Serve workers.
- **Scale to zero needs a signal that survives zero pods.** Engine metrics vanish with the last pod.
- **Thresholds come from a load test.** No guessed numbers.

## References

- [`references/install.md`](references/install.md): Helm, pinned versions, chart metrics, uninstall.
- [`references/llm-triggers.md`](references/llm-triggers.md): vLLM, DCGM, queue and metrics-api triggers.
- [`references/scaledobject-tuning.md`](references/scaledobject-tuning.md): polling, HPA behavior, fallback, pause.
- [`references/scale-to-zero.md`](references/scale-to-zero.md): activation, cold start, HTTP add-on.
- [`references/authentication.md`](references/authentication.md): TriggerAuthentication and 2.21 token audiences.
- [`references/updating.md`](references/updating.md): upgrades and 2.20 to 2.21 breaking changes.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/vllm-pods.md`](references/combos/vllm-pods.md), [`references/combos/gpu-operator-dcgm.md`](references/combos/gpu-operator-dcgm.md), [`references/combos/gaie-epp.md`](references/combos/gaie-epp.md), [`references/combos/ray-serve.md`](references/combos/ray-serve.md).
- [`templates/`](templates): `scaledobject-vllm.yaml`, `scaledobject-queue-worker.yaml`, `triggerauth-prometheus.yaml`, `values-keda.yaml`.

## Companion skills

- `vllm-kserve-keda`: KServe plus KEDA stack.
- `vllm`: engine flags and metrics.
- `nvidia-gpu-operator` and `dcgm-exporter`: GPU nodes and metrics.
- `gateway-api-inference-extension`: model-aware routing.
- `ray-serve`: Ray's own autoscaling.

## License

MIT
