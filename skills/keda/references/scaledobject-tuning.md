# ScaledObject tuning for LLM replicas

> Verified against KEDA v2.21.0, 2026-10-11

LLM replicas are slow to start (image pull, weight load, CUDA graphs: minutes) and expensive to leave idle. Scale out
eagerly, scale in slowly.

## Fields that matter

| Field                                    | Default | LLM advice                                                                                                                      |
| ---------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `pollingInterval`                        | 30 s    | 15-30 s. While replicas >= 1 the HPA polls via the metrics server (kube-controller-manager sync period, 15 s default) not this. |
| `cooldownPeriod`                         | 300 s   | Only the wait before going to 0. Set it longer than your cold start if you scale to zero.                                       |
| `initialCooldownPeriod`                  | 0       | Set to a few minutes so a fresh ScaledObject does not scale a loading model to 0.                                               |
| `minReplicaCount`                        | 0       | Use 1 or more for interactive serving. 0 means a cold start per wake-up.                                                        |
| `maxReplicaCount`                        | 100     | Set to the GPUs you can actually schedule.                                                                                      |
| `idleReplicaCount`                       | ignored | Only 0 is supported (HPA limitation).                                                                                           |
| `fallback`                               | none    | `failureThreshold`, `replicas`, `behavior`; applies to Value/AverageValue triggers, not CPU or memory.                          |
| `advanced.restoreToOriginalReplicaCount` | false   | Set true if deleting the ScaledObject should restore the Deployment's own count.                                                |

## HPA behavior (the real scale-in control)

```yaml
advanced:
  horizontalPodAutoscalerConfig:
    behavior:
      scaleUp:
        stabilizationWindowSeconds: 0
        policies:
          - { type: Pods, value: 2, periodSeconds: 60 } # add at most 2 pods a minute
      scaleDown:
        stabilizationWindowSeconds: 900 # 15 min of lower demand before shrinking
        policies:
          - { type: Pods, value: 1, periodSeconds: 300 } # then one pod per 5 min
```

The HPA name defaults to `keda-hpa-<scaledobject>`. A pod that is still loading its model counts as a replica but
serves nothing, so a too-fast scale-up can overshoot: cap the rate with a `scaleUp` policy.

## Fallback

```yaml
fallback:
  failureThreshold: 3
  replicas: 3
  behavior: currentReplicasIfHigher # static (default) | currentReplicas | currentReplicasIfHigher | currentReplicasIfLower | scalingModifiers
```

After `failureThreshold` consecutive failed reads (Prometheus down) KEDA reports a synthetic metric so the HPA holds
or moves to the fallback count instead of freezing. `currentReplicasIfHigher` avoids shrinking during an outage.

## Pause, force, and manual control

Annotations on the ScaledObject (remove them to resume):

- `autoscaling.keda.sh/paused: "true"` freezes at the current count. `autoscaling.keda.sh/paused-replicas: "N"` scales to N and freezes.
- `autoscaling.keda.sh/paused-scale-in: "true"` blocks scale-in (and scale to zero). `autoscaling.keda.sh/paused-scale-out: "true"` blocks scale-out.
- `autoscaling.keda.sh/force-activation: "true"` treats all triggers as active (wakes from zero for a demo or warm-up).
- `scaledobject.keda.sh/transfer-hpa-ownership: "true"` plus `advanced.horizontalPodAutoscalerConfig.name` adopts an existing HPA.

## Caching and composing

- `useCachedMetrics: true` on a trigger reuses the value for the polling interval, reducing Prometheus load. Not for cpu, memory or cron.
- `advanced.scalingModifiers` merges named triggers into one metric:

```yaml
advanced:
  scalingModifiers:
    formula: "waiting + running / 8" # expr language; result is one number
    target: "4"
    activationTarget: "1"
    metricType: AverageValue
triggers:
  - {
      type: prometheus,
      name: waiting,
      metadata:
        {
          serverAddress: "...",
          query: "sum(vllm:num_requests_waiting)",
          threshold: "1",
        },
    }
  - {
      type: prometheus,
      name: running,
      metadata:
        {
          serverAddress: "...",
          query: "sum(vllm:num_requests_running)",
          threshold: "1",
        },
    }
```

With `fallback.behavior: scalingModifiers`, a failing trigger becomes `nil` so a formula such as `a ?? b ?? 8` can route
around it.

## Measure

- Load test with realistic prompts and watch `kubectl get hpa -w`, pod readiness times and p95 latency together.
- KEDA metrics (enable them in the chart): `keda_scaler_active`, `keda_scaler_metrics_value`,
  `keda_scaler_detail_errors_total`, `keda_scaler_metrics_latency_seconds`, `keda_scaled_object_errors_total`,
  `keda_scaler_empty_upstream_responses_total` (a Prometheus query that returned nothing: usually a wrong label).
- Alert when the HPA sits at `maxReplicas` with waiting > 0, and on any non-zero error rate.
