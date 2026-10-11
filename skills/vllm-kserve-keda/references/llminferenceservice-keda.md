# LLMInferenceService with direct KEDA

> Verified against KServe v0.21.0 (CRD types, release notes), KEDA v2.21.0, llm-d v0.10.0, 2026-10-11

`LLMInferenceService` (`serving.kserve.io/v1alpha2`) is KServe's llm-d based resource: it brings a Gateway API route, a Gateway API Inference Extension scheduler (InferencePool and endpoint picker), optional prefill/decode split and multi-node via LeaderWorkerSet. Use it when you need KV-cache-aware routing; use `InferenceService` otherwise.

## Prerequisites

Gateway API CRDs, Gateway API Inference Extension, LeaderWorkerSet and a Gateway controller (Istio, Envoy Gateway or similar). KServe lists these as the core dependencies. Check them:

```bash
kubectl get crd | grep -E 'gateway.networking.k8s.io|inference.networking|leaderworkerset'
kubectl get gatewayclass
```

Install with the release assets `llmisvc-dependency-install.sh` and `llmisvc-full-install-with-manifests.sh`, plus `llmisvc-autoscaling-keda-dependency-install.sh` for the KEDA side. Download and read them before running, as in `install.md`. Resource and CRD names for the dependencies are in the `gateway-api-inference-extension` skill.

## Scaling block

KServe v0.21.0 adds `spec.scaling.keda` to `LLMInferenceService`. This is described in the CRD types and release notes; the website docs on 2026-10-11 only showed the WVA path, and no upstream sample existed. The shape below follows the CRD and must be checked on your cluster:

```bash
kubectl explain llminferenceservice.spec.scaling --api-version=serving.kserve.io/v1alpha2 --recursive
```

```yaml
spec:
  scaling:
    minReplicas: 2
    maxReplicas: 8 # placeholder, a budget decision
    keda:
      pollingInterval: 15
      initialCooldownPeriod: 300
      idleReplicaCount: 0 # must be less than minReplicas, so only valid with minReplicas > 0
      triggers: # standard KEDA ScaleTriggers, at least one
        - type: prometheus
          metadata:
            serverAddress: http://prometheus-operated.monitoring.svc.cluster.local:9090
            query: sum(vllm:num_requests_running{namespace="llm-serving"})
            threshold: "4" # calibrate
```

Treat `idleReplicaCount`'s constraint as written in the CRD docs; do not assume scale-to-zero works with the router in front without testing it.

## Prefill and decode

When `spec.prefill` is configured you scale decode and prefill as separate workloads. Their load signals differ: prefill saturates on queued prompt tokens and time to first token, decode on running requests and KV usage. Give each its own trigger and target. Scale-down of prefill replicas can fail in-flight KV transfers; on the engine side llm-d recommends `kv_load_failure_policy=recompute` on decode instances (llm-d docs, `docs/operations/disaggregation/vllm.md`). See the `llm-d-vllm-kubernetes` and `disaggregated-serving` skills for the engine details.

## WVA is deprecated

KServe v0.21.0 still pins and documents the llm-d Workload Variant Autoscaler (v0.9.0), but the llm-d project marks WVA deprecated (v0.9.0 was its final release). Prefer direct KEDA, or KEDA fed by endpoint-picker metrics (`llm-d-vllm-kubernetes`). Do not start a new deployment on WVA without telling the user.

## Verify

```bash
kubectl -n llm-serving get llminferenceservice
kubectl -n llm-serving get llminferenceservice <name> -o json | jq '.status.conditions'
kubectl -n llm-serving get scaledobject,inferencepool,httproute
kubectl get pods -n llm-serving -o wide
```

All conditions should be True, the `ScaledObject` Ready, and the Gateway address assigned.

## Gaps

- No upstream example of `spec.scaling.keda` was found; the manifest above is derived from the CRD types.
- Controller behaviour with `idleReplicaCount` and the scheduler was not tested.
- If `kubectl explain` disagrees with this file, trust the cluster.
