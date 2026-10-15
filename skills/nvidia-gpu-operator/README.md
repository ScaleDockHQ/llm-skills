# NVIDIA GPU Operator

Helps an agent prepare Kubernetes GPU nodes for LLM serving with the NVIDIA GPU Operator: install variants and driver
ownership, verification, time-slicing and MIG, DCGM exporter metrics, driver upgrade policy, CRD handling and
troubleshooting. Verified against GPU Operator v26.7.1.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill nvidia-gpu-operator
```

## Rules

- **Ask before changing the system.** The operator installs drivers and edits runtime config on nodes.
- **Pin the chart version** and handle CRDs explicitly on upgrade; Helm does not upgrade them.
- **One GPU manager per node.** Use `driver.enabled=false` and `toolkit.enabled=false` for preinstalled stacks.
- **Time-slicing is not isolation.** Use MIG for tenants that must not affect each other.
- **Secrets stay out of output.** Pull secrets and license tokens live in Secrets.

## References

- [`references/install.md`](references/install.md): platform fit, variants, verification.
- [`references/sharing-mig.md`](references/sharing-mig.md): time-slicing and MIG.
- [`references/observability.md`](references/observability.md): DCGM exporter and node signals.
- [`references/upgrading.md`](references/upgrading.md): upgrade, driver rollout, uninstall.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/vllm-on-gpu-operator.md`](references/combos/vllm-on-gpu-operator.md), [`references/combos/keda-dcgm.md`](references/combos/keda-dcgm.md).
- [`templates/`](templates): smoke test, time-slicing, values, NVIDIADriver.

## Companion skills

- `vllm`, `ray-serve`: workloads on the GPU nodes.
- `dcgm-exporter`: GPU metrics in depth.
- `keda`: scale on queue and GPU metrics.
- `gateway-api-inference-extension`: route to the pods.

## License

MIT
