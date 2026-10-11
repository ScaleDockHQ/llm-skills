# SGLang: observability

> Verified against SGLang v0.5.21 (docs: advanced_features/observability, references/production_metrics, production_request_trace; source `srt/observability/metrics_collector.py`, `srt/utils/auth.py`), 2026-10-11

For dashboards, alert rules and the Prometheus job layout across engines, use skill `llm-observability` (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`). This page is SGLang-specific.

## Prometheus metrics

Enable with `--enable-metrics` (off by default). Endpoint `GET /metrics` on the API port (30000), exempt from `--api-key`. All series start with `sglang:` and carry `model_name` (and parallel-rank labels where relevant); extra labels via `--extra-metric-labels '{"env":"prod"}'`.

```bash
curl -fsS http://127.0.0.1:30000/metrics | grep -c '^sglang:'
curl -fsS http://127.0.0.1:30000/metrics | grep -E '^sglang:(num_running_reqs|num_queue_reqs|token_usage|gen_throughput|cache_hit_rate)'
```

Names present in the v0.5.21 collector (metric names change between releases: list yours with `curl -s .../metrics | grep '^# HELP'`):

| Area                 | Metrics                                                                                                                                                    |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Load                 | `num_running_reqs`, `num_queue_reqs`, `num_paused_reqs`, `num_retracted_reqs`, `utilization`                                                               |
| KV pool              | `token_usage`, `num_used_tokens`, `kv_used_tokens`, `kv_available_tokens`, `max_total_num_tokens`, `full_token_usage`, `new_token_ratio`                   |
| Throughput           | `gen_throughput`, `prompt_tokens_total`, `generation_tokens_total`, `realtime_tokens_total`                                                                |
| Latency histograms   | `time_to_first_token_seconds`, `inter_token_latency_seconds`, `e2e_request_latency_seconds`, `queue_time_seconds`, `per_stage_req_latency_seconds`         |
| Outcomes             | `num_requests_total`, `num_aborted_requests_total`, `num_retracted_requests_total`                                                                         |
| Prefix cache         | `cache_hit_rate`, `cached_tokens_total`, `evicted_tokens_total`                                                                                            |
| Speculative decoding | `spec_accept_rate`, `spec_accept_length`, `spec_num_steps`, `spec_num_draft_tokens`                                                                        |
| Structured output    | `num_grammar_queue_reqs`, `grammar_compilation_time_seconds`, `num_grammar_timeout_total`                                                                  |
| HiCache              | `hicache_host_used_tokens`, `hicache_host_total_tokens`, `load_back_*`, `storage_prefetch_*`                                                               |
| LoRA                 | `lora_pool_slots_used`, `lora_pool_utilization`                                                                                                            |
| PD disaggregation    | `num_prefill_bootstrap_queue_reqs`, `num_decode_prealloc_queue_reqs`, `num_decode_transfer_queue_reqs`, `kv_transfer_latency_ms`, `kv_transfer_speed_gb_s` |
| Startup              | `startup_time_seconds`, `startup_available_gpu_memory_gb`, `weight_load_duration_seconds`                                                                  |

Docs example (older) shows `time_per_output_token_seconds`; the 0.5.21 collector names the inter-token histogram `inter_token_latency_seconds`. Rules written for one name break on the other.

Options: `--enable-mfu-metrics` (estimated FLOPs/bytes), `--enable-metrics-for-all-schedulers` (every TP rank, not just rank 0), custom histogram buckets (`--bucket-time-to-first-token`, `--bucket-inter-token-latency`, `--bucket-e2e-request-latency`, `--prompt-tokens-buckets`, `--generation-tokens-buckets`), `--tokenizer-metrics-custom-labels-header` (default `x-custom-labels`) with `--tokenizer-metrics-allowed-custom-labels`.

Prometheus job:

```yaml
scrape_configs:
  - job_name: sglang
    metrics_path: /metrics
    static_configs:
      - targets: ["sglang-host:30000"]
        labels: { backend: sglang }
```

Useful PromQL (the first two alert rules most deployments need):

```text
sglang:num_queue_reqs > 0                      # sustained queueing: saturation
sglang:token_usage > 0.95                      # KV pool nearly full: retractions follow
histogram_quantile(0.99, sum by (le) (rate(sglang:time_to_first_token_seconds_bucket[5m])))
rate(sglang:generation_tokens_total[5m])
```

Upstream ships a Prometheus + Grafana compose stack in `examples/monitoring/` (Grafana `:3000` login `admin`/`admin` with a forced change, Prometheus `:9090`; dashboard `grafana/dashboards/json/sglang-dashboard.json`). Change those default credentials and keep both ports local.

In multi-node or PD setups scrape every rank-0 API (prefill and decode servers expose their own `/metrics`).

## Logging

- `--log-level info|debug|warning`; `--log-level-http`; change at runtime: `python3 -m sglang.srt.managers.configure_logging --url http://localhost:30000 --log-level=debug`.
- `--log-requests` (+ `--log-requests-level 0..2`, `--log-requests-format text|json`, `--log-requests-target stdout|<dir>`) logs prompts and outputs. That is user data: restrict access and rotation.
- `--uvicorn-access-log-exclude-prefixes /health /metrics` removes probe noise.
- Request dump and replay: `python3 -m sglang.srt.managers.configure_logging --url http://localhost:30000 --dump-requests-folder /tmp/sglang_request_dump --dump-requests-threshold 100`; replay with `scripts/playground/replay_request_dump.py` from the repo.
- Per-request timing: `--enable-request-time-stats-logging`; export per-request metrics to files with `--export-metrics-to-file --export-metrics-to-file-dir <dir>`.

## Tracing

`--enable-trace --otlp-traces-endpoint host:4317` (default `localhost:4317`; `--trace-modules request` or `request,mooncake`) emits OpenTelemetry spans. See `references/production_request_trace` upstream.

## Crash diagnostics

`--crash-dump-folder /var/tmp/sglang-crash` writes `<hostname>/crash_dump_<timestamp>.pkl` with recent completed requests, in-flight requests, server args and launch command, and on CUDA sets defaults to enable device coredumps. `--watchdog-timeout 300` (seconds) crashes the server if a forward hangs; `--soft-watchdog-timeout` dumps info first. Crash dumps contain prompts: protect them.

## Health checks

- Liveness/readiness: `GET /health` (use for Kubernetes and llama-swap `checkEndpoint`). Allow generous startup time (`initialDelaySeconds` 120 or a startup probe; large models take many minutes).
- `GET /health_generate` runs a token: manual use only.
- Cheap state check: `curl -s localhost:30000/server_info | jq .version` or `/get_model_info`.
