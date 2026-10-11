# Observability

> Verified against Ray 2.59.0 (docs `serve/monitoring`, `serve/llm/user-guides/observability`), 2026-10-11

## Status and logs

```bash
serve status; ray status
kubectl logs <worker-pod> -c ray-worker --tail=200
ls /tmp/ray/session_latest/logs/serve/       # on a node: controller, proxy and replica logs
```

Serve writes logs from the `ray.serve` logger to stderr and to `/tmp/ray/session_latest/logs/serve/`
on each node (replica logs `replica_<app>_<deployment>_*`). Ship them with a node-level agent (Loki, ELK).

## Metrics

Ray exposes Serve, engine and system metrics on the Ray Prometheus endpoint of each node (port 8080 in the
KubeRay sample). Scrape the head and every worker pod.

- Serve metrics (prefix `ray_serve_`): `deployment_request_counter_total`, `deployment_error_counter_total`,
  `num_http_requests_total`, `num_http_error_requests_total`, `http_request_latency_ms`,
  `deployment_processing_latency_ms`, `deployment_queued_queries`, `deployment_replica_healthy`,
  `deployment_status`, `application_status`, `health_check_failures_total`.
- Autoscaler: `ray_serve_autoscaling_desired_replicas`, `autoscaling_target_replicas`,
  `autoscaling_target_ongoing_requests`, `autoscaling_total_requests`.
- Engine metrics: vLLM metrics are exported when `log_engine_metrics: true` (default since Ray 2.51): TTFT, TPOT,
  KV cache utilization, batch size, throughput. Names follow the vLLM metrics documentation (skill `vllm`).
  A Serve LLM Grafana dashboard ships with Ray when Grafana and Prometheus are configured.
- Histogram buckets: `RAY_SERVE_REQUEST_LATENCY_BUCKETS_MS`, fixed at startup (restart Serve actors to change).
  `RAY_SERVE_METRICS_EXPORT_INTERVAL_MS` controls Serve-side batching of updates.

```bash
curl -s http://<pod-ip>:8080/metrics | grep -E '^ray_serve_(deployment_queued|deployment_replica_healthy|autoscaling_desired)' | head
```

Alert candidates: queued queries rising with replicas at `max_replicas`; `deployment_replica_healthy` below the
target; `deployment_status` not healthy; error counter rate; vLLM KV cache usage near 1.

## Usage stats

Ray collects usage data about Serve LLM features (model architecture, LoRA, autoscaling, TP size, GPU type). Opt
out per the Ray usage stats docs (`RAY_USAGE_STATS_ENABLED=0`) when the data policy requires it.

## Sources

https://docs.ray.io/en/latest/serve/monitoring.html, https://docs.ray.io/en/latest/serve/llm/user-guides/observability.html
