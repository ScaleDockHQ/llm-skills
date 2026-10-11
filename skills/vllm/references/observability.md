# Observability: logs, Prometheus metrics, tracing

> Verified against vLLM v0.31.0 (docs `usage/metrics.md`, `design/metrics.md`, `usage/troubleshooting.md`, `examples/observability/*`, source `vllm/v1/metrics/loggers.py`), 2026-10-11

## Logs

- Startup lines to read: the selected attention backend and kernels (`Selected <kernel> for <module>`),
  `GPU KV cache size: N tokens`, `Maximum concurrency for M tokens per request: Nx`, the `--kv-cache-memory-bytes`
  value that reproduces the allocation, and compile/graph capture timing.
- Periodic stats lines (running/waiting requests, KV usage, prefix cache hit rate) come from the stat logger;
  `VLLM_LOG_STATS_INTERVAL=1.` makes them frequent, `--disable-log-stats` turns them off.
- `VLLM_LOGGING_LEVEL=DEBUG` for more detail; v0.31.0 adds `--logging-config` and `--log-level`.
- `--enable-log-requests` logs request bodies (v0.31.0): prompts end up in logs, so treat them as sensitive.
- Container: `docker logs -f <name>`; systemd: `journalctl -u vllm -f`.
- Debug env vars for hangs: `CUDA_LAUNCH_BLOCKING=1`, `NCCL_DEBUG=TRACE`, `VLLM_TRACE_FUNCTION=1` (over 100x slowdown).

## Prometheus metrics

`GET /metrics` is on by default on the API server port. Metric names present in the v0.31.0 stat logger
(prefix `vllm:`):

| Area          | Metrics                                                                                                                                                                                                                                                  |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Load          | `num_requests_running`, `num_requests_waiting`, `num_requests_waiting_by_reason`, `num_preemptions`                                                                                                                                                      |
| KV cache      | `kv_cache_usage_perc`, `prefix_cache_queries`, `prefix_cache_hits`, `external_prefix_cache_*`, `mm_cache_queries`, `mm_cache_hits`, `kv_block_lifetime_seconds`, `kv_block_idle_before_evict_seconds`, `kv_block_reuse_gap_seconds`, `cache_config_info` |
| Throughput    | `prompt_tokens`, `prompt_tokens_by_source`, `prompt_tokens_cached`, `generation_tokens`, `iteration_tokens_total`, `request_success`                                                                                                                     |
| Latency       | `time_to_first_token_seconds`, `inter_token_latency_seconds`, `request_time_per_output_token_seconds`, `request_queue_time_seconds`, `request_prefill_time_seconds`, `request_decode_time_seconds`, `request_inference_time_seconds`                     |
| Request shape | `request_prompt_tokens`, `request_generation_tokens`, `request_params_n`, `request_params_max_tokens`, `request_max_num_generation_tokens`                                                                                                               |
| Misc          | `engine_sleep_state`, `corrupted_requests`, `lora_requests_info`, speculative-decoding, NIXL, KV offload and (with `--enable-mfu-metrics`) MFU series                                                                                                    |

Alert candidates: `num_requests_waiting` rising with `kv_cache_usage_perc` near 1 (add capacity or lower
`--max-model-len`/`--max-num-seqs`), `num_preemptions` increasing (preemption recomputes; raise
`--gpu-memory-utilization` or reduce concurrency), TTFT p95 up with prefix cache hit rate down (cache churn).
Deprecated metrics are hidden one minor version later; restore with `--show-hidden-metrics-for-version X.Y`.

Scrape config (each DP/replica server needs its own target):

```yaml
scrape_configs:
  - job_name: vllm
    metrics_path: /metrics
    static_configs:
      - targets: ["127.0.0.1:8000"]
```

Upstream ships a Prometheus + Grafana compose example and dashboards under `examples/observability/`
(`prometheus_grafana/`, `dashboards/grafana`, `dashboards/perses`).

## Tracing

OpenTelemetry tracing: `--otlp-traces-endpoint` and `--collect-detailed-traces <modules>` (see `design/metrics.md`,
`examples/observability/opentelemetry`). Per-request timing also arrives in response metrics when enabled.
For LLM-level observability, traces and cost, see the skill `llm-observability`.

## Health probes

`GET /health` for liveness/readiness. Cold starts (weight load, compile, graph capture) can take many minutes:
raise Kubernetes `failureThreshold` or `startupProbe`, and any router `healthCheckTimeout`. A restart with
`KeyboardInterrupt: terminated` in the log plus `failed startup probe` events means the probe killed a healthy
start (docs `k8s.md`). `VLLM_ENGINE_READY_TIMEOUT_S` (default 600) is the engine's own startup deadline.
