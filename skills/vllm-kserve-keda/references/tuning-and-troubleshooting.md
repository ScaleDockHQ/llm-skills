# Tuning, troubleshooting and teardown

> Verified against KServe v0.21.0, KEDA v2.21.0, vLLM v0.31.0, 2026-10-11

## Calibrate the trigger

1. Deploy with `minReplicas: 1` and a fixed `maxReplicas`.
2. Run a load at increasing concurrency against the service (`bench.sh` from the `self-hosted-llms` skill).
3. Record `vllm:num_requests_running`, `vllm:num_requests_waiting` and `vllm:kv_cache_usage_perc` per replica and p95 time to first token at each step.
4. Set the target just below the concurrency where p95 latency leaves your SLO, then add headroom for model start time.

Cold start of a vLLM replica includes image pull, model download or mount, weight load and compile or graph capture. It can take minutes for large models. Scale early rather than hard; never size the trigger so low that replicas churn.

## Knobs

| Knob                                                   | Where                                                             | Why                                                                                                                   |
| ------------------------------------------------------ | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `pollingInterval`                                      | KEDA ScaledObject (`spec.scaling.keda` for `LLMInferenceService`) | How often the query runs. Keep it above the Prometheus scrape interval.                                               |
| `initialCooldownPeriod`                                | same                                                              | Time after creation before scale-in. Use at least the model's cold start.                                             |
| `cooldownPeriod`                                       | KEDA                                                              | Wait before scaling to `idleReplicaCount` or zero.                                                                    |
| `fallback`                                             | KEDA                                                              | Replica count to hold when the trigger query fails. Set it, so a Prometheus outage does not scale you to the minimum. |
| `advanced.horizontalPodAutoscalerConfig.behavior`      | KEDA                                                              | Scale-down stabilization window to stop flapping.                                                                     |
| pause annotation `autoscaling.keda.sh/paused-replicas` | ScaledObject                                                      | Freeze replicas during maintenance or load tests.                                                                     |

Verify field names against `kubectl explain scaledobject.spec` for your KEDA version. The `keda` skill covers each field.

## Scale to zero

KEDA only scales to zero when `minReplicaCount` is 0 (or `idleReplicaCount: 0` with a higher min). For GPU LLMs that means a full cold start for the next request and no metric from a zero-replica Prometheus series. For `InferenceService` with the Prometheus trigger, an empty query result must be handled by `or vector(0)` in the query or the scaler will error. Request-driven wake-up from zero needs an HTTP add-on or Knative mode, which is outside this skill. Default to `minReplicas: 1`.

## Failure table

| Symptom                                             | Likely cause                                                                       | Check                                                                        |
| --------------------------------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `autoscalerClass: keda` ignored, no `ScaledObject`  | Not in Standard mode, or KEDA CRDs missing                                         | `kubectl get crd scaledobjects.keda.sh`, the `deploymentMode` annotation     |
| `ScaledObject` Ready False, "failed to get metrics" | Prometheus address wrong or unreachable from the `keda` namespace, or auth missing | `kubectl describe scaledobject`, `kubectl -n keda logs deploy/keda-operator` |
| `ScaledObject` Active False under load              | Query returns no series (label or pod regex mismatch) or the metric is not scraped | run the query in Prometheus directly                                         |
| Replicas stuck at max, never fall                   | Query counts waiting requests that never drain, or `cooldownPeriod` too long       | compare query to `num_requests_running`                                      |
| Flapping                                            | Target too low, no stabilization window, polling shorter than scrape               | add scale-down behaviour, raise the target                                   |
| New replicas Pending                                | No free GPU or `nvidia.com/gpu` request exceeds node capacity                      | `kubectl describe pod`, the `nvidia-gpu-operator` skill                      |
| New replicas CrashLoop, OOM at start                | `--max-model-len` or `--gpu-memory-utilization` too high for the GPU               | `kubectl logs`, the `vllm` skill                                             |
| InferenceService Ready but requests 404             | Wrong model name or path prefix                                                    | `curl .../v1/models` through the service                                     |
| Download fails with 401 or 403                      | Gated model without a token, or Secret not attached                                | storage initializer logs, the `kserve` skill                                 |
| `LLMInferenceService` stuck not Ready               | Missing Gateway API, GAIE or LWS CRDs, or no GatewayClass                          | `kubectl describe llminferenceservice`, controller logs in `kserve`          |
| KEDA upgrade to 2.21 breaks auth                    | Bound service account token audience change (KEDA security fix, CVE-2026-77524)    | KEDA 2.21 release notes, the `keda` skill                                    |
| Docs and cluster disagree                           | The KServe website lags the code (v0.20.0 references, v1alpha1 install docs)       | `kubectl explain`, the CRD in the release assets                             |

Read-only diagnostics:

```bash
kubectl -n llm-serving get isvc,llminferenceservice,scaledobject,hpa,deploy,pods
kubectl -n llm-serving describe scaledobject | tail -30
kubectl -n llm-serving get events --sort-by=.lastTimestamp | tail -20
kubectl -n kserve logs deploy/kserve-controller-manager --tail=50
kubectl -n keda logs deploy/keda-operator --tail=50
```

## Upgrade notes

- KServe: install the new release scripts over the old only after reading its release notes; CRD changes (`v1alpha2` for LLMInferenceService) can be breaking.
- KEDA: moving from 2.20.2 to 2.21.0 needs the 2.21 breaking-change review. Test on a non-production cluster first.
- vLLM: bump the pinned runtime image, run the `llm-evals` skill and a load test before switching traffic.

## Teardown

List what you created and ask for approval before each delete. Names below match the examples in this skill.

```bash
kubectl -n llm-serving delete isvc qwen-vllm            # also removes its Deployment and ScaledObject
kubectl delete clusterservingruntime vllm-pinned
kubectl -n llm-serving delete secret hf-token
kubectl delete namespace llm-serving                    # last, removes remaining objects
helm uninstall keda -n keda                             # only if you installed it and nothing else uses it
```

Uninstalling KServe or KEDA removes CRDs and every custom resource of that kind. Do that only for a cluster you are retiring, with explicit approval. GPU nodes keep costing money until you scale the node group down, so remind the user.
