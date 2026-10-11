# InferenceService with vLLM and KEDA

> Verified against KServe v0.21.0, KEDA v2.21.0, vLLM v0.31.0, 2026-10-11

Use for one model served as a Deployment per component. KServe generates the `ScaledObject`; you do not write it.

## Manifest

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen-vllm
  namespace: llm-serving
  annotations:
    serving.kserve.io/deploymentMode: "Standard"
    serving.kserve.io/autoscalerClass: "keda"
    serving.kserve.io/enable-prometheus-scraping: "true"
spec:
  predictor:
    minReplicas: 1 # raise for availability; 0 needs extra care, see tuning reference
    maxReplicas: 4 # a GPU quota or budget decision, not a default
    model:
      modelFormat:
        name: vLLM
      runtime: vllm-pinned # the runtime from install.md
      storageUri: hf://Qwen/Qwen3-0.6B
      args:
        - --max-model-len=8192
      resources:
        requests: { cpu: "4", memory: 16Gi, nvidia.com/gpu: "1" }
        limits: { cpu: "8", memory: 24Gi, nvidia.com/gpu: "1" }
    autoScaling:
      metrics:
        - type: External
          external:
            metric:
              backend: "prometheus"
              serverAddress: "http://prometheus-operated.monitoring.svc.cluster.local:9090"
              query: sum(vllm:num_requests_running{namespace="llm-serving",pod=~"qwen-vllm-predictor.*"})
            target:
              type: AverageValue # the query is a sum, so divide it by the target
              averageValue: "4" # running requests per replica; placeholder, calibrate with a load test
```

Model name, size, resource sizes and the `Value` target above are placeholders. Replace the model with the user's, size resources from the `choosing-hardware` skill, and calibrate the target.

Check the live schema before editing, because docs lag the code:

```bash
kubectl explain inferenceservice.spec.predictor.autoScaling.metrics.external --recursive | head -60
```

## Choosing the metric

All names are vLLM v0.31.0 Prometheus metrics, exposed on the runtime port 8080 at `/metrics`:

| Metric                                                                                 | Use                                                                                                        |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `vllm:num_requests_running`                                                            | Concurrency per replica. Simple, stable first choice.                                                      |
| `vllm:num_requests_waiting`                                                            | Queue depth. Scale on this to protect latency, but expect it to stay at 0 until you are already saturated. |
| `vllm:kv_cache_usage_perc`                                                             | KV pressure (a 0 to 1 ratio). Good for long-context loads.                                                 |
| `vllm:time_to_first_token_seconds` and `vllm:inter_token_latency_seconds` (histograms) | SLO alerts and dashboards. Poor as a direct trigger without a recording rule.                              |

Confirm names against your running pod, since they change between vLLM versions:

```bash
kubectl -n llm-serving port-forward deploy/qwen-vllm-predictor 8080:8080 &
curl -s localhost:8080/metrics | grep -E '^vllm:(num_requests|kv_cache)' | head
```

Use `sum(...)` or `avg(...)` deliberately. Kubernetes HPA semantics apply. With `Value` the result is compared to the target as a whole and replicas scale by that ratio (desired = ceil(current * result / target)). With `AverageValue` the result is a total divided by the target (desired = ceil(result / target)). Pick one deliberately and test scale-out with a real load.

## Prometheus must scrape the pods

`serving.kserve.io/enable-prometheus-scraping: "true"` and the runtime's `prometheus.kserve.io/port` and `path` annotations only label the pod. A Prometheus (for example kube-prometheus-stack) still needs a `PodMonitor` or annotation-based scrape config that picks them up. Check:

```bash
kubectl get podmonitor,servicemonitor -A | head
kubectl -n monitoring port-forward svc/prometheus-operated 9090:9090 &
curl -s 'localhost:9090/api/v1/query?query=vllm:num_requests_running' | jq '.data.result | length'
```

The result must be non-zero before KEDA can scale. The `prometheus-grafana-llm` skill covers the scrape setup and dashboards.

## Authenticated Prometheus

When Prometheus needs auth, put credentials in a KEDA `TriggerAuthentication` backed by a Secret you create from a `0600` file (never inline). The KServe field that references it is `authenticationRef`, a sibling of `metric` and `target` inside the `external` block (Go type `ExternalMetricSource`), holding `authModes` and an inner `authenticationRef.name`. The KServe website places `authModes` differently from the CRD, so rely on `kubectl explain` output for the exact path in your cluster version. Create the `TriggerAuthentication` in the same namespace as the `InferenceService`.

## Verify

```bash
kubectl -n llm-serving get isvc qwen-vllm
kubectl -n llm-serving get deploy,pods -l serving.kserve.io/inferenceservice=qwen-vllm
kubectl -n llm-serving get scaledobject,hpa
kubectl -n llm-serving describe scaledobject            # Ready, Active, trigger query errors in events
URL=$(kubectl -n llm-serving get isvc qwen-vllm -o jsonpath='{.status.url}'); echo "$URL"
```

Request through the cluster (adjust host or port-forward to your ingress; do not print auth headers):

```bash
kubectl -n llm-serving port-forward svc/qwen-vllm-predictor 8081:80 &
curl -s localhost:8081/openai/v1/chat/completions -H 'content-type: application/json' \
  -d '{"model":"qwen-vllm","messages":[{"role":"user","content":"Say hi"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

If the path differs, run `kubectl get svc -n llm-serving` and the `kserve` skill's endpoint section. KServe's vLLM runtime serves the OpenAI API; the exact prefix (`/openai/v1` or `/v1`) depends on the runtime, so test both before concluding failure.

For the load test and the scale-in check, use `bench.sh` from the `self-hosted-llms` skill against the service URL, then watch `kubectl get scaledobject -w` and `kubectl get pods -w` in another terminal.

## OTel metrics alternative

KServe v0.21.0 also supports an OpenTelemetry-based path with the KEDA OTel add-on (v0.0.6 in its scripts), where metrics are pushed rather than queried from Prometheus. It is an add-on to KEDA and was not exercised here. Use it only when the Prometheus trigger cannot work, and read `hack/setup/infra/manage.keda-otel-addon-helm.sh` in the KServe repo first.
