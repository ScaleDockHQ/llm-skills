# Observability

> Verified against LMDeploy v0.18.0 (docs `advance/metrics.md`; source `lmdeploy/metrics`, `serve/core/health.py`), 2026-10-11

## Logs

Default `--log-level WARNING`. For debugging use `--log-level INFO` (shows the applied chat template and loading
steps). Prompt logging is unlimited unless `--max-log-len N` is set: set it so prompts and secrets in prompts are
not written to logs wholesale. Uvicorn level: `UVICORN_LOG_LEVEL`.

## Health

`GET /health`: 200 for `healthy` and `sleeping`, 503 otherwise (including "health monitor not initialized" during
startup). Background probe settings: `LMDEPLOY_HEALTH_POLL_INTERVAL` (12 s), `LMDEPLOY_HEALTH_PROBE_TIMEOUT` (10 s),
`LMDEPLOY_HEALTH_UNHEALTHY_AFTER` (90 s). Use `/health` for readiness and a generous startup probe: load and graph
capture are slow.

## Metrics

Enabled by default; `--disable-metrics` turns them off. Scrape `http://<host>:23333/metrics` (unauthenticated).
Metric names in v0.18.0 source:

| Metric (prefix `lmdeploy:`)                                                                                                   | Meaning                          |
| ----------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| `num_requests_running`, `num_requests_waiting`, `num_api_requests_waiting`, `num_api_requests_routed`                         | Queue and load                   |
| `num_requests_succeeded`, `num_requests_failed`, `request_success_total`                                                      | Outcomes                         |
| `prompt_tokens_total`, `generation_tokens_total`, `iteration_tokens_total`, `cached_tokens_total`                             | Token counters                   |
| `time_to_first_token_seconds`, `time_per_output_token_seconds`, `iter_token_latency`                                          | Latency histograms               |
| `request_queue_time_seconds`, `request_prefill_time_seconds`, `request_decode_time_seconds`, `request_inference_time_seconds` | Per-request phases               |
| `request_prompt_tokens`, `request_generation_tokens`, `request_cached_tokens`, `request_cache_hit_ratio`                      | Request size and cache           |
| `gpu_cache_usage_perc`, `prefix_cache_hit_rate`                                                                               | KV occupancy and prefix cache    |
| `spec_decode_mean_accept_rate`, `spec_decode_mean_accept_length`, `spec_decode_num_*`, `spec_decode_per_position_accept_rate` | Speculative decoding             |
| `backend_config`                                                                                                              | Info metric of the engine config |

`gpu_cache_usage_perc` semantics differ by engine: PyTorch counts logical blocks referenced by live requests
(set `LMDEPLOY_ENABLE_REQUEST_CACHE_USAGE_METRIC=0` for total occupancy including prefix-cache-only blocks);
TurboMind is bytes in live prefix-cache and checkpoint objects over the cache-region size, with scheduler
metrics only for DP 1.

```bash
curl -s http://127.0.0.1:23333/metrics | grep -E '^lmdeploy:(num_requests|gpu_cache|time_to_first)' | head
```

## Prometheus and Grafana stack

```bash
git clone --depth=1 --branch v0.18.0 https://github.com/InternLM/lmdeploy
cd lmdeploy/lmdeploy/monitoring && docker compose up
```

Prometheus on :9090, Grafana on :3000 (default login `admin`/`admin`, you are asked to change it). Edit
`prometheus.yaml` for a non-default server port, and use the host IP, not loopback, for `DP > 1`. Bind or firewall
these to private access. For fleet dashboards see `prometheus-grafana-llm`.
