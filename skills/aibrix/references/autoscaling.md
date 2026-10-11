# Autoscaling

> Verified against AIBrix v0.7.0 (docs, samples, chart, release assets), 2026-10-11

`PodAutoscaler` (`autoscaling.aibrix.ai/v1alpha1`) scales a Deployment, StormService or fleet. `scaleTargetRef.name`
must equal the target's name.

| `scalingStrategy` | Notes                                                                           |
| ----------------- | ------------------------------------------------------------------------------- |
| `HPA`             | Vanilla Kubernetes HPA behaviour                                                |
| `KPA`             | Knative-style, stable and panic windows, faster scale-up                        |
| `APA`             | AIBrix Pod Autoscaler: HPA-like with fluctuation tolerance to avoid oscillation |

Metric sources (`spec.metricsSources`): `pod` (scrape the engine `/metrics`, with `protocolType: http`, `port`,
`path`, `targetMetric`, `targetValue`) or `resource` (cpu). Any vLLM metric works.

```yaml
apiVersion: autoscaling.aibrix.ai/v1alpha1
kind: PodAutoscaler
metadata:
  name: deepseek-r1-distill-llama-8b-apa
  annotations:
    autoscaling.aibrix.ai/scale-up-tolerance: "0.1"
    autoscaling.aibrix.ai/scale-down-tolerance: "0.2"
spec:
  scalingStrategy: APA
  minReplicas: 1
  maxReplicas: 8
  metricsSources:
    - {
        metricSourceType: pod,
        protocolType: http,
        port: "8000",
        path: metrics,
        targetMetric: gpu_cache_usage_perc,
        targetValue: "0.5",
      }
  scaleTargetRef:
    {
      apiVersion: apps/v1,
      kind: Deployment,
      name: deepseek-r1-distill-llama-8b,
    }
```

## Annotations (prefix `autoscaling.aibrix.ai/`)

`max-scale-up-rate` (2), `max-scale-down-rate` (2), `scale-up-tolerance` (0.1, KPA/APA), `scale-down-tolerance` (0.1),
`panic-threshold` (2.0, KPA), `scale-up-cooldown-window` (0s), `scale-down-cooldown-window` (300s), `scale-to-zero`
(false; still bounded by `minReplicas`). Quote values in YAML.

## More

- **Multi-metric** APA and **StormService role-level** scaling (`subTargetSelector` plus annotation
  `autoscaling.aibrix.ai/storm-service-mode: "pool"`) are in `samples/autoscaling/`.
- **Optimizer-based** (GPU optimizer, profiling, heterogeneous GPUs): `samples/autoscaling/optimizer-kpa.yaml`.
- For event-driven or Prometheus-query scaling outside AIBrix, see skill `keda`.

```bash
kubectl get podautoscaler; kubectl describe podautoscaler <name>
```

## Sources

- <https://aibrix.readthedocs.io/latest/features/autoscaling/metric-based-autoscaling.html>
- <https://github.com/vllm-project/aibrix/tree/v0.7.0/samples/autoscaling>
