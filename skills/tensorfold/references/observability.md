# TensorFold: observability

> Verified against TensorFold v1.0.7, 2026-10-11

Docs/api.md, README, docs/memory-diagnostics.md

## Health and stats

- `GET /health`: open even with API keys. Without keys, returns server health and status info; on CUDA includes counters you can difference into rates (`requests_total`, `completion_tokens_total`, `prompt_tokens_total`, `cached_tokens_total`, `prefill_seconds_total`, `decode_seconds_total`, `rounds_total`, `drafted_total`, `accepted_total`, `busy`, `requests_running`, `streams`, `context_length`).
- `--dashboard` adds `/dashboard` (live page, polls once a second) and `/stats` JSON.
- `/memory` (read-only): process footprint, lifetime peak, backend allocation counters, applied retained-prefix plan.

## Prometheus

`GET /metrics` and `/v1/metrics`, prefix `tensorfold:`: `requests_running`, `requests_waiting`, `prompt_tokens_total`, `generation_tokens_total`, `kv_cache_usage_ratio` (label `pool`), `mtp_drafted_total`, `mtp_accepted_total`, `request_latency_seconds`, `time_to_first_token_seconds`, `request_decode_seconds`, `request_time_per_output_token_seconds`, `request_prefill_seconds`, `decode_rounds_total`, plus `tensorfold:pinned_memory_bytes` on CUDA and prefix-cache counters when the engine keeps prompt states. vLLM-named duplicates exist (`num_requests_running`, `kv_cache_usage_perc`, `spec_decode_num_*`, `e2e_request_latency_seconds`, `prefix_cache_hits_total`). Families the server cannot count honestly are omitted rather than zero. With auth enabled `/metrics` needs a key unless `--metrics-open`.

```bash
curl -fsS http://127.0.0.1:8080/metrics -H "Authorization: Bearer $(cat ~/.config/tensorfold/key)" | grep -E '^tensorfold:'
```

## Logs

The native server's finish log names the reply ID, `prompt`, `cached`, `thinking`, `effort`, `tokens`, `sha`, `finish`, `rounds` and draft acceptance; refusals log `refused <id>`; client aborts log `ended <id> reason=client-left`. Request logs and request counters use key labels, never keys. Under llama-swap read `/logs/stream/<id>`. Recipes: `docker logs -f <container>`; the dual recipe saves each rank's log (gzipped) on stop.
