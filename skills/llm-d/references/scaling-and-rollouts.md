# Autoscaling and rollouts

> Verified against llm-d v0.10.0 (guides/workload-autoscaling, guides/rollouts, docs/operations/rollouts, release notes), 2026-10-11

## Autoscaling signals

Utilization is a lagging signal for LLMs; scale on queue depth, in-flight requests, saturation or latency.

| Path (under `guides/workload-autoscaling`)        | Signal                                                                              | Needs                                              |
| ------------------------------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------- |
| KEDA + EPP, queue depth (`keda-epp`, recommended) | Requests waiting in EPP flow control plus running requests                          | KEDA, Prometheus (no Prometheus Adapter)           |
| KEDA + EPP, saturation (`keda-epp-saturation`)    | InferencePool saturation 0.0 to 1.0+ plus running requests; leading                 | KEDA, Prometheus; scale-to-zero "needs validation" |
| Token-aware (`keda-epp-token-aware`)              | In-flight tokens divided by calibrated `peakPrefillThroughput` (seconds of backlog) | KEDA, Prometheus, one calibration run              |
| SLO-aware (`slo-aware`)                           | EPP estimated latency divided by the SLO via a recording rule                       | KEDA, Prometheus rule, predicted-latency           |
| KEDA + WVA (`wva`)                                | `wva_desired_replicas` from the Workload Variant Autoscaler                         | **Deprecated**, pinned to WVA v0.9.0               |

KEDA creates and owns the HPA that scales the model-server Deployment. The WVA path publishes a metric for a KEDA
`ScaledObject` or HPA annotated `llm-d.ai/managed: "true"`; `VariantAutoscaling` is deprecated and the repo was renamed
`llm-d/llm-d-autoscaling` in v0.10.0. KServe's `LLMInferenceService` still documents WVA (skill `kserve`).

Install order: Prometheus (and the Prometheus Operator CRDs), KEDA (skill `keda`), then the guide's overlay. Heterogeneous
pools should scale per InferencePool; keep scale-up fast and scale-down slow, and give startup time for model loading.
An experimental Kueue-based replica rebalancing section exists in the guide.

```bash
kubectl get scaledobject,hpa -n $NAMESPACE
kubectl get --raw /apis/external.metrics.k8s.io/v1beta1 | jq '.resources[].name'
```

## Rollouts

LLM requests are long, model warm-up is slow and GPUs are expensive, so avoid all-at-once replacement.

| Strategy             | How                                                                                             | Needs                    |
| -------------------- | ----------------------------------------------------------------------------------------------- | ------------------------ |
| Rolling update       | Normal Deployment update inside one InferencePool; set surge and unavailable to match free GPUs | Either router mode       |
| Blue-green           | Second complete InferencePool, HTTPRoute weights shift traffic (`blue-green-update.md`)         | Gateway mode             |
| LoRA adapter rollout | Live adapter hot-swap without dropping traffic (`adapter-rollout.md`)                           | vLLM LoRA, guide example |

For graceful rolling updates also set vLLM `--shutdown-timeout` and a `preStop` drain (see `operations.md`).

## Sources

- <https://llm-d.ai/docs/well-lit-paths/foundations/workload-autoscaling>
- <https://github.com/llm-d/llm-d/tree/release-0.10/guides/workload-autoscaling>
- <https://github.com/llm-d/llm-d/blob/release-0.10/docs/operations/rollouts/README.md>
