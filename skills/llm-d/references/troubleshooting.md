# Troubleshooting llm-d

> Verified against llm-d v0.10.0 (optimized-baseline troubleshooting, install guides, operations docs), 2026-10-11

```bash
kubectl get pods,svc,inferencepool,httproute,gateway -n $NAMESPACE
kubectl logs -n $NAMESPACE deploy/${GUIDE_NAME}-epp --all-containers --tail=100
kubectl describe inferencepool -n $NAMESPACE
kubectl get pods -n $NAMESPACE -l llm-d.ai/guide --show-labels
```

| Symptom                                                 | Likely cause                                                                                      | Fix                                                                               |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Helm install: no matches for kind (InferencePool, etc.) | Inference Extension CRDs missing or wrong version                                                 | Apply the `GAIE_VERSION` manifests from `env.sh`                                  |
| Router starts but sees no endpoints                     | `modelServers.matchLabels` in router values does not match model-server pod labels                | Align `llm-d.ai/guide` label with the values file                                 |
| Requests 5xx right after start                          | Pods Ready before the model loaded (probes on `/health`)                                          | Use `/v1/models` readiness and a startup probe (`operations.md`)                  |
| Gateway mode never healthy on GKE                       | `provider.name=none` creates no `HealthCheckPolicy`                                               | Set `--set provider.name=gke`                                                     |
| Uneven load, some pods hot and others idle              | Load scorer or saturation override not spreading; `peakPrefillThroughput` wrong for your hardware | Calibrate with `guides/recipes/router/calibration`, set it on the filter          |
| Low prefix cache hit rate                               | Prompt mix not prefix-sticky, or override spreads too aggressively                                | Compare hit rate to per-pod saturation; consider precise prefix-cache routing     |
| TTFT regression with balanced load and healthy cache    | Model-server queue or scheduler latency, not routing config                                       | Look at `vllm:num_requests_waiting` and `llm_d_epp_plugin_duration_seconds` first |
| Precise prefix routing has no cache awareness           | vLLM `--block-size` differs from `blockSizeTokens`, KV-events not enabled, render service down    | Match 64 to 64 (guide default), check the render service and ZMQ events           |
| Monitoring helm upgrade fails validation                | Prometheus Operator CRDs absent (ServiceMonitor)                                                  | Install the monitoring stack first                                                |
| CPU pods crash on startup                               | CPU lacks AMX or AVX512-BF16                                                                      | Use Sapphire Rapids/Zen 4 or newer                                                |
| P/D: KV transfer stalls or fails after prefill restarts | NixlConnector stale agent cache; TP ratio direction limits                                        | See `docs/operations/disaggregation`; restart the affected decode pods            |
| Image pull of `llm-d-cuda` fails or is stale            | Image deprecated in v0.10.0                                                                       | Use `docker.io/vllm/vllm-openai`                                                  |
| Hugging Face 429 or timeouts at start                   | Hub rate limit on parallel pod starts                                                             | Use a model cache (PVC or node-local) per `model-loading-and-startup.md`          |
| Router CPU high at idle                                 | Scraping cost scales with pod count; large prefix match limit                                     | Raise EPP CPU, lower `maxPrefixTokensToMatch`                                     |
| Multi-replica EPP gives no throughput gain              | Default is active-passive leader election                                                         | Active-active only with compatible plugins (`operations.md`)                      |

## Sources

- <https://github.com/llm-d/llm-d/blob/release-0.10/guides/optimized-baseline/README.md>
- <https://github.com/llm-d/llm-d/tree/release-0.10/docs/operations>
