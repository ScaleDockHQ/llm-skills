# Aphrodite Engine observability

> Verified against Aphrodite Engine (Sonar) v0.24.1, 2026-10-11

```bash
curl -s --fail http://127.0.0.1:2242/health      # process health; allow time for load, compile, graph capture
curl -s http://127.0.0.1:2242/metrics | head -40  # Prometheus; keep private
curl -s http://127.0.0.1:2242/version
```

Data-parallel supervisor deployments also serve `/ready` and `/readyz`. Do not route traffic before model
loading and graph capture finish; send a warm-up request first.

Watch: running and waiting requests, TTFT, inter-token latency, end-to-end latency, prompt and generation
throughput, KV cache occupancy and preemptions, prefix-cache hits, speculative acceptance counters. For P/D, NIXL
exports transfer duration, bytes, failed transfers and expired requests: alert on failures. Alert on sustained
queue growth and tail latency, not brief GPU spikes. Scale on queue depth and latency rather than utilization.

- `--enable-request-id-headers` returns `X-Request-Id`; never put user content in it.
- `APHRODITE_LOGGING_LEVEL=DEBUG` for bounded runs; `--enable-log-requests` logs request parameters (prompts at
  DEBUG). Restrict access and retention.
- `--otlp-traces-endpoint` exports OpenTelemetry traces: sample, keep errors, use a private collector.
- `--enable-server-load-tracking` backs `/load`.
- Docs list a Grafana dashboard image only as a screenshot; build panels from the metric names above.

Graceful shutdown: remove from the load balancer, wait for active requests, stop (`--shutdown-timeout`, 0 aborts,

> 0 waits), start the replacement, warm it. Set the orchestrator grace period above the longest request.
> Release checklist: authenticated chat, streaming cancel, max-context request, health during load and shutdown,
> metrics, one failed replica behind the balancer. See the `llm-observability` skill for traces and cost.
