# Routing, scaling, operations and troubleshooting

> Verified against NVIDIA Dynamo v1.5.1 docs and examples, TensorRT-LLM 1.3.0rc25 (bundled), 2026-10-11

## KV-aware routing

Two topologies exist; pick one request path and never both:

1. **Dynamo Frontend routing** (recommended unless you need Gateway API). The Frontend tokenizes the request, scores workers by KV cache overlap and load, and forwards. Router settings belong on the Frontend component only.
2. **Gateway API with the Dynamo EPP** when a platform Gateway must own ingress, auth and rate limits. Needs Gateway API, GAIE and a Dynamo endpoint picker (`gateway-api-routing` docs in the Dynamo repo). For the router side of llm-d instead, use `llm-d-vllm-kubernetes`.

Template `deploy/disagg_router.yaml` differs from `disagg.yaml` in three places: the Frontend gets `DYN_ROUTER_MODE=kv`, the prefill worker gets `--publish-events-and-metrics`, and prefill runs 2 replicas. A DGD that mirrors it, as a patch idea:

```yaml
- name: Frontend
  type: frontend
  podTemplate:
    spec:
      containers:
        - name: main
          image: nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1
          env:
            - { name: DYN_ROUTER_MODE, value: kv }
# prefill args additionally: --publish-events-and-metrics
```

The Frontend docs also show a `--router-mode kv` flag; read `docs/fern/pages/kubernetes/kv-aware-routing/dynamo-frontend.md` for the full flag list and defaults before tuning. KV routing pays off with repeated prefixes and several workers; with unique prompts it adds overhead. The `prefix-aware-routing` skill has the concepts.

## Scaling

- **Planner** (in a `DynamoGraphDeploymentRequest`, fields under `spec.features.planner`): `optimization_target` is `throughput` (default; static thresholds on queue depth and KV utilization), `latency` (earlier scale-up), `load`, or `sla` (targets TTFT and ITL, models engine performance, needs profiling data or AIConfigurator and Prometheus). `enable_throughput_scaling` and `enable_load_scaling` only matter with `sla`. `deploy/disagg_planner.yaml` is the template with Planner and Prometheus. This path was read, not run here.
- **KEDA or HPA** on Prometheus metrics for DGD components is documented as needing kube-prometheus-stack. The exact scaling-adapter wiring for a `DynamoGraphDeployment` was not verified; read the Dynamo docs section and the `keda` skill before relying on it.
- Scale prefill and decode pools by their own signals: prefill by queued prompt tokens and TTFT, decode by running requests, KV usage and ITL. Keep the ratio from measurements, not from the template's 1:1 or 2:1.
- Do not add an HPA to a component the Planner already scales.

## Fault tolerance

The Dynamo docs cover graceful shutdown, request migration and request rejection (`docs/fern/pages/kubernetes/fault-tolerance/`). Test a prefill pod deletion under load to see how in-flight requests behave on your version.

## Failure table

| Symptom                                                                                     | Likely cause                                      | Check or fix                                                                            |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Workers hang after sustained load, log `num_fitting_reqs=0 ... may not have enough kvCache` | `max_tokens_in_buffer` below the max input length | raise it above the longest input (for example 65536) in both engine YAMLs, restart pods |
| Disaggregated requests fail, no transfer                                                    | `cache_transceiver_config` missing                | add `backend: DEFAULT` (or `UCX`/`NIXL`) to prefill and decode YAML                     |
| TTFT of tens of seconds                                                                     | KV transfer fell back to TCP                      | worker logs for transport, fix RDMA (`kv-transfer-and-networking.md`)                   |
| `The NVIDIA driver on your system is too old`                                               | Image CUDA newer than host driver                 | check driver against the image matrix, upgrade the driver or choose another tag         |
| Pods `ImagePullBackOff`                                                                     | NGC tag unavailable, or missing pull secret       | `kubectl describe pod`, confirm tag in the NGC catalog                                  |
| Operator error on multinode                                                                 | Neither Grove nor LWS installed                   | `install-platform.md` multinode section                                                 |
| Decode multinode crashes loading NIXL                                                       | Plugin ABI mismatch                               | set `NIXL_PLUGIN_DIR` on decode only                                                    |
| `NCCL error 'unhandled system error'` on GB200                                              | No ComputeDomain                                  | add ComputeDomain and claims                                                            |
| Hang on a local `docker run --network host`                                                 | Undiagnosed MPI behaviour                         | use explicit port mappings (local only)                                                 |
| DGD rejected by API                                                                         | Wrong API version or schema                       | `kubectl explain` on the installed CRD, use `v1beta1` fields                            |
| Model download 401/403 or rate limited                                                      | Token missing, or many pods downloading at once   | check `hf-token-secret`, use shared storage                                             |
| Second operator conflicts                                                                   | Cluster-wide operator already installed           | use the existing one                                                                    |

Read-only diagnostics:

```bash
kubectl get dynamographdeployment,pods -n $NAMESPACE -o wide
kubectl describe dynamographdeployment <name> -n $NAMESPACE | tail -40
kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp | tail -20
kubectl logs -n $NAMESPACE deploy/dynamo-platform-dynamo-operator-controller-manager --tail=60 2>/dev/null
kubectl exec -n $NAMESPACE <worker-pod> -- nvidia-smi --query-gpu=name,driver_version,memory.used,memory.total --format=csv
```

## Upgrades

Dynamo supports mixed versions between frontends and workers across an N-2 release window, but not direct prefill-to-decode protocols. Upgrade prefill and decode to the same image tag together. Read the release notes, `helm show values` the new chart, and apply CRD changes before workloads.

## Teardown

```bash
kubectl delete dynamographdeployment <name> -n $NAMESPACE        # ask first; also removes its pods
kubectl delete configmap nvidia-config -n $NAMESPACE             # only if you created it
```

Then follow the uninstall section of `install-platform.md` if the platform is being retired. Scale down GPU nodes afterwards.

## Verification gaps (2026-10-11)

- The TRT-LLM inside Dynamo 1.5.1 is `1.3.0rc25` (a release candidate), and Dynamo pins vLLM `v0.28.0`; the `tensorrt-llm` skill documents v1.2.1 and the `vllm` skill v0.31.0. Engine flags may differ.
- `nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1` appears in repo YAML; the NGC registry cannot be listed anonymously, so the tag was not confirmed from the registry.
- Kubernetes docs mix `v1alpha1` and `v1beta1`; the install page shows chart version 1.2.1 in an example.
- The driver matrix in the TRT-LLM overview lists 1.4.0; the 1.5.1 row was not verified.
- A `1.5.1-efa` image tag was not confirmed.
- Multinode, Planner, AIConfigurator, Gateway API routing and KEDA/HPA scaling for DGDs were read but not run.
- Nothing was deployed on a cluster; commands come from upstream files at tag v1.5.1 plus read-only checks.
