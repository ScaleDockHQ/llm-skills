# Scaling, rollouts and caching

> Verified against KServe v0.21.0 (website llmisvc autoscaling, canary-rollout, lora-adapters, kv-cache-offloading, localmodel docs; repo samples), 2026-10-11

## WVA autoscaling for LLMInferenceService

WVA (Workload Variant Autoscaler, from the llm-d project) computes the replica count from inference metrics.
Setting `spec.scaling` makes KServe create a `VariantAutoscaling` object plus an actuator (HPA or KEDA
`ScaledObject`) that applies `wva_desired_replicas` with target 1. `spec.scaling` and `spec.replicas` are
mutually exclusive.

Prerequisites: the WVA controller (install per <https://llm-d.ai/docs/guides/workload-autoscaling>), Prometheus
scraping the pods and WVA, and either Prometheus Adapter (HPA) or KEDA.

| Aspect           | HPA actuator                                                       | KEDA actuator                                                                  |
| ---------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| Needs            | Prometheus Adapter external-metric rule for `wva_desired_replicas` | KEDA plus `autoscaling-wva-controller-config` key in `inferenceservice-config` |
| Scale to idle    | No (min 1)                                                         | Yes, `idleReplicaCount`                                                        |
| Metric outage    | HPA goes Unknown                                                   | Configurable fallback replicas                                                 |
| Model load grace | No                                                                 | `initialCooldownPeriod`                                                        |

```yaml
spec:
  scaling:
    minReplicas: 1
    maxReplicas: 5
    wva:
      hpa: {} # or: keda: {}   (exactly one)
```

Prefill/decode services scale each pool (`PrefillScalingReady` condition). Install helper scripts in the v0.21.0
release: `llmisvc-autoscaling-hpa-dependency-install.sh` and `llmisvc-autoscaling-keda-dependency-install.sh`.
Read the WVA install guide before running them.

## Canary rollout (LLMInferenceService)

Every member of a rollout declares `spec.router.route.group` (a string) and `spec.router.route.weight`
(proportional, not percent). The webhook labels members `serving.kserve.io/routing-group`; each service owns an
HTTPRoute with the same weighted backends.

```bash
kubectl patch llmisvc my-model-v2 -n ns --type merge -p '{"spec":{"router":{"route":{"weight":3}}}}'
kubectl get llmisvc -n ns -L serving.kserve.io/routing-group
```

Start the canary at `weight: 1`, not `0`; a dark deploy can cause transient connection failures when raised later.
Promote by force-stopping the old version (frees GPUs, keeps the object for rollback), decommission later.
Condition `GroupReady` (and `GroupDegraded` when members diverge) appear on every member. This needs the Gateway API
HTTPRoute path, so it applies to the managed router. Release v0.21.0 also added canary traffic splitting to
RawDeployment `HTTPRoute`s of `InferenceService`.

## LocalModelCache (InferenceService only)

Caches model files on node-local NVMe so replicas and restarts skip the download. Support for
`LLMInferenceService` is documented as planned, not available.

1. Enable: set `"enabled": true` in the `localModel` key of the `inferenceservice-config` ConfigMap
   (default job namespace `kserve-localmodel-jobs`).
2. Create credentials Secrets in the job namespace, or a `ClusterStorageContainer` with
   `workloadType: localModelDownloadJob` (takes precedence over inline credentials).
3. Create a `LocalModelNodeGroup` (local PV storage class, per-node size), then a `LocalModelCache`
   (cluster scope) or `LocalModelNamespaceCache` naming `sourceModelUri`, `modelSize` and `nodeGroups`.
4. Check: `kubectl get localmodelcache`, `kubectl get localmodelnode`.

Install it with `--type kserve,localmodel` (see `install.md`).

## LoRA adapters

`spec.model.lora.adapters[]` with `name` and `uri` (`hf://`, `s3://`, `pvc://`) on an `LLMInferenceService`; vLLM
loads them at startup and requests choose an adapter by its `name` as `model`. Sample:
`docs/samples/llmisvc/lora-adapters`. Budget GPU memory for base model plus adapters.

## KV cache offloading

Sample `docs/samples/llmisvc/kv-cache-offloading` offloads evicted blocks GPU -> CPU RAM -> disk. Disk tier options
from its README: a shared RWX PVC (`secondary.fileSystem.pvc.ref`, for example CephFS, shared across replicas) or
an `emptyDir` (single replica, lost on pod restart). Pair it with the `kv-cache-offloading` skill for the engine side.

## Sources

- <https://kserve.github.io/website/docs/model-serving/generative-inference/llmisvc/autoscaling/llmisvc-autoscaling>
- <https://kserve.github.io/website/docs/model-serving/generative-inference/llmisvc/canary-rollout>
- <https://kserve.github.io/website/docs/model-serving/generative-inference/modelcache/localmodel>
- <https://github.com/kserve/kserve/tree/v0.21.0/docs/samples/llmisvc>
