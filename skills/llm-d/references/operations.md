# Operating llm-d

> Verified against llm-d v0.10.0 (docs/operations: observability, readiness-probes, graceful-shutdown, router, model-loading-and-startup), 2026-10-11

## Observability

```bash
./guides/recipes/observability/install-prometheus-grafana.sh            # into namespace llm-d-monitoring; --enable-tls for autoscalers
kubectl get pods -n llm-d-monitoring
# Enable router metrics: add -f guides/recipes/router/features/monitoring.values.yaml (creates a ServiceMonitor)
# Enable model-server metrics:
kubectl apply -n $NAMESPACE -k guides/recipes/modelserver/components/monitoring     # decode PodMonitor
kubectl get podmonitors,servicemonitors -n $NAMESPACE
```

The monitoring values need the Prometheus Operator CRDs installed first or Helm validation fails. Use the
`monitoring-pd` component too for disaggregation.

Signals that matter:

| Question                   | Metric                                                                                                   |
| -------------------------- | -------------------------------------------------------------------------------------------------------- |
| Is load even?              | `llm_d_epp_request_total`, `llm_d_epp_request_running`, `vllm:num_requests_running`                      |
| Is prefix routing helping? | `vllm:prefix_cache_hits_total` / `vllm:prefix_cache_queries_total`, `llm_d_epp_request_cached_tokens`    |
| Is a pod saturated?        | `vllm:kv_cache_usage_perc`, `vllm:num_requests_waiting`                                                  |
| Is the router slow?        | `llm_d_epp_plugin_duration_seconds`                                                                      |
| User-facing latency        | `vllm:time_to_first_token_seconds`, `vllm:inter_token_latency_seconds`, `llm_d_epp_request_ttft_seconds` |
| Errors                     | `llm_d_epp_request_error_total` (alert above about 5 percent per the docs)                               |

SGLang equivalents: `sglang_num_running_reqs`, `sglang_token_usage`, `sglang_cache_hit_rate`. Tracing: uncomment the
OTLP flags and env in the model-server patch (`--otlp-traces-endpoint`, `OTEL_*`) and see `observability/tracing.md`.

## Probes

vLLM `/health` only says the process is up. Use `/v1/models` for startup and readiness so a pod is Ready only after the
model loads (`templates/probes-patch.yaml`). Decode pods in P/D serve through the sidecar on 8200 (prefill 8000), so
match the probe port to the role.

## Graceful shutdown

On termination Kubernetes first removes the pod from the InferencePool (no new traffic), then runs `preStop`, sends
SIGTERM, and kills after `terminationGracePeriodSeconds` (default 30 s). vLLM aborts in-flight requests on SIGTERM unless
started with `--shutdown-timeout N`. Set `--shutdown-timeout` below the grace period and raise the grace period for long
generations. P/D has its own rules in `docs/operations/disaggregation/vllm.md`.

## Router high availability and sizing

- Default multi-replica EPP is active-passive (`--ha-enable-leader-election`): one leader serves, replicas are
  warm standby; more replicas do not add throughput. `router.proxy.failOpen: true` keeps traffic flowing to
  model servers during a failover.
- Active-active: `router.epp.flags.ha-enable-leader-election: false` with `replicas: 3` scales near-linearly (docs table:
  2.0x at 2, 2.7x at 3, 3.5x at 4), but only plugins that query model servers live are compatible, so index-based
  precise prefix routing is not.
- CPU rule of thumb from the docs: 0.5 to 1.0 core per request per second for large agentic workloads; idle scraping
  cost grows with pod count (about 7.5 cores at 100 pods). Larger `maxPrefixTokensToMatch` costs CPU.

## Startup time

Model loading dominates cold start. Options in `docs/operations/model-loading-and-startup.md`: node-local or PVC model
caches, an internal registry, compilation-cache reuse, ModelExpress GPU-to-GPU loading, pod snapshots (GKE), and
mirrors like ModelScope when Hugging Face is limited. For Hugging Face rate limits or timeouts see its Verification
section.

## Serving external APIs

`docs/operations/serve-external-apis` shows LiteLLM Proxy or Kong AI Gateway routing between self-hosted llm-d and cloud
APIs. For a LiteLLM front, point `api_base` at the router Service (skill `litellm`).

## Sources

- <https://llm-d.ai/docs/operations>
- <https://github.com/llm-d/llm-d/tree/release-0.10/docs/operations>
