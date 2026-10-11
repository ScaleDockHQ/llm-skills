# Observability

> Verified against mistral.rs v0.9.4 (docs `guides/deploy/observability`, `reference/http-api`), 2026-10-11

## Logs

- Default: curated `INFO` startup logs, dependency warnings and HTTP access logs (`request started`, `request completed` with request id,
  method, matched route, resolved model, status, duration). `/`, `/health`, `/metrics`, `/docs`, `/api-doc/openapi.json`, `/ui` and CORS
  preflights are skipped unless `--access-log-health`.
- `--access-log-format json` for machine parsing; `--disable-access-log` to silence.
- `-v` debug, `-vv` trace, or an explicit `RUST_LOG` filter. `MISTRALRS_DEBUG` adds engine tracing.
- `x-request-id`: an incoming header is honoured, otherwise generated; echoed on the response unless `--disable-request-id-header`.
- `-l/--log <path>` records prompts and responses in full, so it is a data-retention decision, not an access log.

## Health and readiness

```bash
curl -s -o /dev/null -w 'live %{http_code}\n' http://127.0.0.1:1234/health      # up, says nothing about model load
curl -s http://127.0.0.1:1234/v1/models | jq -e '.data[] | select(.id=="<id>" and .status=="loaded")' >/dev/null && echo ready
```

Give startup probes minutes for first-run download and quantization.

## Metrics (`GET /metrics`, Prometheus text)

On by default; `--disable-metrics` turns it off (then 503). Excludes health, metrics, docs and UI from the HTTP series.

- HTTP, labelled `method`, `path` (route pattern), `model`, `status`: `http_requests_total`, `http_request_duration_seconds`,
  `http_requests_in_flight`, `http_request_body_bytes`.
- Streaming latency: `mistralrs_time_to_first_token_seconds`, `mistralrs_inter_token_latency_seconds` (vLLM-compatible buckets).
- Engine (unlabelled, process-wide; use one process per model for per-model dashboards):
  `mistralrs_prefill_tokens_processed_total`, `mistralrs_decode_tokens_processed_total`, `mistralrs_sequences_running`, `_waiting`,
  `_capacity`, `mistralrs_sequences_completed_total{reason}`, `mistralrs_kv_cache_blocks_used` / `_total` / `_available`,
  `mistralrs_prefix_cache_lookups_total` / `_hits_total` / `_evictions_total`, encoder-cache counters, and
  `mistralrs_speculative_drafts_total` and `_draft_tokens_proposed_total` with accepted-token counterparts for MTP.

```promql
rate(mistralrs_decode_tokens_processed_total[1m])                                    # generation tokens/s
histogram_quantile(0.95, sum by (le) (rate(mistralrs_time_to_first_token_seconds_bucket[5m])))
mistralrs_kv_cache_blocks_used / mistralrs_kv_cache_blocks_total                     # KV pressure
mistralrs_prefix_cache_hits_total / mistralrs_prefix_cache_lookups_total             # cache hit ratio
mistralrs_sequences_waiting > 0                                                      # saturation
```

Scrape from the private network only; `/metrics` is unauthenticated like the rest. Check the full series list on a running server
with `curl -s localhost:1234/metrics | grep -E '^# TYPE (mistralrs|http)_'`.

## GPU and host

`nvidia-smi dmon -s um` or DCGM for GPU; `mistralrs doctor` for hardware and compiled features; `mistralrs cache list` for downloaded weights.
