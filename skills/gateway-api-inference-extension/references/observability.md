# Observability

> Verified against llm-d router v0.11.0 (`docs/metrics.md`, release notes, chart README) and Gateway API Inference Extension v1.6.2, 2026-10-11

## What to look at

```bash
kubectl get inferencepool <name> -o yaml | sed -n '/status:/,$p'      # parent conditions
kubectl get gateway,httproute -A -o wide
kubectl logs deploy/<pool>-epp --tail=100                              # the EPP pod; name depends on the release
kubectl exec -it deploy/<pool>-epp -- sh -c 'true'                     # only if you need a shell; avoid secrets
```

## Metrics

- EPP `/metrics` on port 9090 by default. The metrics doc lists the prefix `llm_d_epp_` (request totals and durations
  by `model_name`, `target_model_name`, `fairness_id`, `priority`; pool gauges `average_kv_cache_utilization`,
  `average_queue_size`, `average_running_requests`, `ready_endpoints`, `per_endpoint_queue_size`; scheduler
  `scheduler_e2e_duration_seconds`, `scheduler_attempts_total`; flow control, disaggregation, prefix indexer). A July 2026
  release note says KV-cache index metrics moved under the `llm_d_router_epp` subsystem with the former `kvcache_*`
  names deprecated. Run `curl -s <epp>:9090/metrics | cut -d'{' -f1 | sort -u` on your version and build alerts from what exists.
- Label cardinality is bounded: unconfigured request-supplied model names collapse into `other` after 1000 distinct
  values, and `fairness_id` is capped at 1000.
- Model servers expose their own metrics (vLLM: skill `vllm`, `references/observability.md`).
- Chart: `router.monitoring.prometheus.enabled` renders a ServiceMonitor; by default scraping needs the auth Secret
  (`router.monitoring.prometheus.auth.enabled`); with `router.podAnnotations` you can scrape by annotation, which
  requires turning that auth off. `router.tracing.enabled` turns on OpenTelemetry (sampler
  `parentbased_traceidratio`, arg `0.1`); logs are OpenTelemetry-style JSON (docs `otel-json-stdout.md`).
- Metrics endpoint over mTLS: `--metrics-cert-dir` and `--metrics-client-ca-file`.

## Alert candidates

`ready_endpoints` below the replica count; scheduler attempts failing; rising request error counters; EPP restart or
leader flapping; `x-llm-d-request-dropped-reason` 503s; queue size average rising with KV-cache utilization near 1
(scale the pool: skill `keda`); flat prefix-cache hit rate after enabling prefix scoring.
