# Autoscaling with KEDA and router (EPP) metrics

> Verified against llm-d v0.10.0 (guides/workload-autoscaling), llm-d-router v0.11.0, KEDA v2.21.0 (guide links KEDA 2.20 docs), 2026-10-11

llm-d scales model-server Deployments with KEDA reading signals the EPP emits, instead of CPU or GPU use (which stays high at both low and high concurrency). Source: `guides/workload-autoscaling/` in the llm-d repo.

## WVA status

The Workload Variant Autoscaler is deprecated: v0.9.0 was the final release, its guide assets are pinned to it, and Replica Rebalancing is removed. New deployments use KEDA plus EPP; existing WVA users migrate to the saturation overlay of the KEDA plus EPP guide. Prometheus Adapter is also marked as planned for deprecation. KServe v0.21.0 still documents WVA; see the `vllm-kserve-keda` skill for that side.

## Paths

| Path                           | Signals                                                               | Status                                    |
| ------------------------------ | --------------------------------------------------------------------- | ----------------------------------------- |
| KEDA plus EPP, queue (default) | `llm_d_epp_flow_control_queue_size`, `llm_d_epp_request_running`      | Recommended, has nightly e2e on OpenShift |
| KEDA plus EPP, saturation      | `llm_d_epp_flow_control_pool_saturation`, `llm_d_epp_request_running` | Marked experimental in the guide          |
| Token-aware                    | tokens of outstanding work, `peakPrefillThroughput`, decode KV        | Separate guide: `keda-epp-token-aware`    |
| SLO-aware                      | EPP estimated TTFT or TPOT over an SLO, via a recording rule          | Separate guide: `slo-aware`               |
| WVA                            | desired-replica metric                                                | Deprecated                                |

## Prerequisites

1. The optimized baseline from `install-baseline.md`, with monitoring enabled and Prometheus scraping the EPP. Confirm the target is up before configuring KEDA.
2. KEDA installed (the `keda` skill, or `helm install keda kedacore/keda -n keda --create-namespace --version <pinned>` after `helm search repo kedacore/keda --versions`). On OpenShift use the Custom Metrics Autoscaler Operator.
3. The router upgraded with the autoscaling overlay (it turns on EPP flow control, which both signals need).

```bash
export TRIGGER=queue ENV=existing        # queue|saturation, existing|ocp
export MONITORING_NAMESPACE=llm-d-monitoring KEDA_NAMESPACE=keda
export OVERLAY_ROOT=${REPO_ROOT}/guides/workload-autoscaling/keda-epp/optimized-baseline

helm upgrade optimized-baseline ${ROUTER_STANDALONE_CHART} \
  -f ${REPO_ROOT}/guides/recipes/router/base.values.yaml \
  -f ${REPO_ROOT}/guides/optimized-baseline/router/optimized-baseline.values.yaml \
  -f ${REPO_ROOT}/guides/recipes/router/features/monitoring.values.yaml \
  -f ${OVERLAY_ROOT}/router.values.yaml \
  -n ${NAMESPACE} --version ${ROUTER_CHART_VERSION}
kubectl logs deployment/optimized-baseline-epp -n ${NAMESPACE} | grep "Flow Control enabled"
kubectl get servicemonitor -n ${NAMESPACE}
```

## Validate the metrics first

```bash
kubectl port-forward -n ${NAMESPACE} service/optimized-baseline-epp 9091:9090 &
curl -s localhost:9091/metrics | grep -E 'llm_d_epp_flow_control_queue_size|llm_d_epp_flow_control_pool_saturation|llm_d_epp_request_running'
kill %1
```

Then run the PromQL from the guide in Prometheus. Each query must return a scalar or single-element vector. Edit label selectors (`namespace`, `service`, `model_name`, and `inference_pool` for saturation) to match your live series; do not copy them. If a series is absent, check the Prometheus target rather than treating absence as zero.

## Apply

Pick one overlay (`k8s-queue`, `k8s-saturation`, `ocp-queue`, `ocp-saturation`) and never two on one Deployment:

```bash
kubectl kustomize ${OVERLAY_ROOT}/k8s-${TRIGGER} | less      # review the ScaledObject and queries
kubectl apply -n ${NAMESPACE} -k ${OVERLAY_ROOT}/k8s-${TRIGGER}
kubectl get scaledobject,hpa -n ${NAMESPACE}
```

The overlay targets `optimized-baseline-nvidia-gpu-vllm-decode`, ScaledObject `optimized-baseline-keda-epp`, HPA `keda-hpa-optimized-baseline`. Change the target to your Deployment. KEDA owns the HPA; do not create another.

Guide defaults, all to be tuned: min replicas 1, max 8 (queue) or 10 (saturation), queue threshold 1, pool-saturation threshold 0.7, running-request threshold 16, polling 15s, cooldown 300s, scale-up and scale-down stabilization 300s (size near the model's cold start). All triggers use `AverageValue`, so thresholds are per replica and the HPA uses the largest desired count across triggers.

## Prometheus access and fallback

- Generic Kubernetes overlay talks plain HTTP to the bundled kube-prometheus-stack inside the cluster, with no auth. If yours needs a token, mTLS or basic auth, add a `TriggerAuthentication` and set `authModes` on the trigger. KEDA ignores a CA in `TriggerAuthentication` unless `authModes` is set, which causes `x509: certificate signed by unknown authority`.
- OpenShift overlays use the Thanos querier with `authModes: bearer` and a dedicated read-only ServiceAccount. Thanos returns 401 for unauthenticated queries and KEDA silently serves `fallback` replicas when a trigger errors, so a broken auth setup can look healthy while scaling nothing. Check `kubectl describe scaledobject` for trigger errors.
- Give every namespace its own ClusterRoleBinding name on shared clusters.

## Saturation detector

The EPP default `utilization-detector` uses queue depth and KV pressure and is recommended. `concurrency-detector` counts in-flight requests, reacts instantly but misses KV pressure and treats cheap cache hits as load; prefer the default unless you have a reason.

## Scale-to-zero and cold start

The guide notes that the polling interval governs checks while the target is at zero replicas and that cooldown controls scaling to zero. A GPU vLLM replica takes minutes to load; keep `minReplicaCount: 1` for interactive services unless the user accepts a cold start.

## Verify

Generate load with repeated and long prompts (`bench.sh` from the `self-hosted-llms` skill) and watch:

```bash
kubectl get scaledobject,hpa -n ${NAMESPACE} -w
kubectl top pods -n ${NAMESPACE} 2>/dev/null | head
```

Pass criteria: `ScaledObject` Ready, ACTIVE flips under load, replicas rise, TTFT stays inside the SLO, and replicas return to the minimum after the stabilization windows. Thresholds from other models or GPUs do not transfer; repeat the calibration.
