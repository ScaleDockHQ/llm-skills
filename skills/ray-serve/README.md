# Ray Serve

Helps an agent serve LLMs on a Ray cluster with Ray Serve LLM (vLLM engine, OpenAI-compatible endpoints) and run
that on Kubernetes with KubeRay. It covers install, `LLMConfig` and the `serve` CLI, parallelism across GPUs and
nodes, routing (prefix, KV-aware), prefill/decode, multi-LoRA, autoscaling, observability, upgrades and
troubleshooting. Verified against Ray 2.59.0 and KubeRay v1.7.1.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill ray-serve
```

## Rules

- **Ask before changing the system.** Helm releases, CRDs, RayService applies and exposure need approval.
- **Secrets stay out of output.** `HF_TOKEN` lives in a Kubernetes Secret or the environment.
- **Serve has no API key check.** Put a gateway or network policy in front; never expose the Ray dashboard.
- **Pin versions.** Match image tag, `rayVersion` and operator; check the vLLM version inside the image.
- **Mind both autoscalers.** Serve replicas and Ray worker nodes scale separately.

## References

- [`references/install.md`](references/install.md): pip, images, vLLM compatibility, KubeRay Helm.
- [`references/serve-config.md`](references/serve-config.md): `LLMConfig`, YAML, `serve` CLI.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): TP, PP, DP attention, placement groups.
- [`references/features.md`](references/features.md): routers, prefill/decode, multi-LoRA, direct streaming.
- [`references/scaling-and-tuning.md`](references/scaling-and-tuning.md): autoscaling knobs and cold start.
- [`references/kubernetes-kuberay.md`](references/kubernetes-kuberay.md): RayService, upgrades, GCS fault tolerance.
- [`references/observability.md`](references/observability.md): metrics, logs, alerts.
- [`references/updating.md`](references/updating.md): upgrades and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/litellm-gateway.md`](references/combos/litellm-gateway.md), [`references/combos/keda-vllm-pods.md`](references/combos/keda-vllm-pods.md).
- [`templates/`](templates): `serve-config.yaml`, `rayservice-llm.yaml`.

## Companion skills

- `vllm`: engine flags and parsers.
- `nvidia-gpu-operator`: GPU drivers and device plugin on Kubernetes.
- `keda`: pod autoscaling on queue and vLLM metrics.
- `gateway-api-inference-extension`: model-aware load balancing for vLLM pods.
- `litellm`: keys, budgets and fallbacks in front of the endpoint.

## License

MIT
