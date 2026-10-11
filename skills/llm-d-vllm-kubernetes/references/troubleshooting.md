# Troubleshooting and verification gaps

> Verified against llm-d v0.10.0, llm-d-router v0.11.0, Gateway API Inference Extension v1.5.0, 2026-10-11

## Read-only diagnostics

```bash
kubectl -n $NAMESPACE get pods,svc,inferencepool,httproute,gateway 2>/dev/null
kubectl -n $NAMESPACE describe pod -l app.kubernetes.io/name=$GUIDE_NAME-epp 2>/dev/null | tail -30
kubectl -n $NAMESPACE logs deploy/${GUIDE_NAME}-epp --tail=80
kubectl -n $NAMESPACE get events --sort-by=.lastTimestamp | tail -20
kubectl -n $NAMESPACE get deploy -o wide
helm -n $NAMESPACE status $GUIDE_NAME
helm -n $NAMESPACE get values $GUIDE_NAME -a | head -60        # may show config, review before sharing
```

## Failure table

| Symptom                                                   | Likely cause                                                                   | Check or fix                                                           |
| --------------------------------------------------------- | ------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `helm install` fails with CRD or kind not found           | GAIE CRDs missing or version mismatch                                          | `kubectl get crd                                                       | grep inference.networking`, reinstall CRDs at `GAIE_VERSION` |
| Helm fails on `ServiceMonitor`                            | Prometheus Operator CRDs absent while monitoring values are on                 | Install monitoring first, or leave `MONITORING_VALUES` empty           |
| Pods stuck `Init:0/1`                                     | Kubernetes older than the sidecar init container support (guide advises 1.33+) | `kubectl version`, upgrade or use a newer cluster                      |
| Model pods Pending                                        | Not enough GPUs for 8 replicas times TP=2                                      | reduce `replicas` and TP in the overlay, `kubectl describe pod`        |
| Model pods `ImagePullBackOff`                             | Placeholder `REPLACE_*_IMAGE` left in the manifest                             | `kubectl kustomize ...                                                 | grep REPLACE_`, add the image component                      |
| Pod `CrashLoop` on CPU nodes                              | CPU variant on a CPU without AMX or AVX512-BF16                                | use the GPU path, or a newer CPU                                       |
| Download 401 or 403                                       | Gated model, missing `llm-d-hf-token`                                          | recreate the Secret from a file, never echo it                         |
| Requests hang or 503 from the router                      | No ready endpoints in the InferencePool, labels mismatch                       | `kubectl get pods --show-labels`, check selector in router values      |
| Uneven load, some pods hot                                | `peakPrefillThroughput` wrong for this hardware                                | run `calibrate.sh`, set the measured value                             |
| Low prefix-cache hit rate                                 | Prompts not prefix-sticky, or saturation override spreading too much           | compare `vllm:prefix_cache_hits_total` to queries per pod              |
| P/D requests fail after prefill scale-down                | In-flight KV reads lost                                                        | `kv_load_failure_policy=recompute` on decode                           |
| P/D transfer slow                                         | No RDMA, TCP path, wrong UCX library                                           | `nccl-rdma-networking`, check the NIXL notes in `pd-disaggregation.md` |
| KEDA shows healthy but replicas never change              | Trigger auth failing and `fallback` serving                                    | `kubectl describe scaledobject`, trigger errors                        |
| `x509: certificate signed by unknown authority` from KEDA | CA set without `authModes`                                                     | set `authModes` on the trigger                                         |
| Two autoscalers fight                                     | An HPA plus a KEDA ScaledObject on one Deployment                              | delete the extra HPA                                                   |

## Upgrade

Read the release notes of llm-d and llm-d-router first. Use the new tag for the clone and `ROUTER_CHART_VERSION`, run `helm upgrade --dry-run` and compare `kubectl kustomize` output. The Gateway API Inference Extension CRDs move on their own version (`GAIE_VERSION`).

## Verification gaps (2026-10-11)

- The README prose of the guides says `env.sh` sets the chart to the floating `v0`; the file at `v0.10.0` sets `v0.11.0`.
- The P/D `base` overlay does not set a model-server image component; confirm the preview output before applying.
- The P/D overlay uses the floating router sidecar tag `main`.
- Default vLLM image in the guides is v0.30.0, one release behind vLLM v0.31.0. Pinning a newer image was not tested here.
- `peakPrefillThroughput` values in the repo are hardware specific.
- Saturation-based autoscaling is marked experimental upstream.
- Gateway-mode installs for specific providers (Istio, agentgateway, GKE) were not walked through.
- The stack was not run on a cluster; all commands come from upstream guides at `v0.10.0` plus read-only discovery.
