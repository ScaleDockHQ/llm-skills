# Observability for ik_llama.cpp

> Verified against ik_llama.cpp main (89bba35c), examples/server/README.md, 2026-10-11

- **Health:** `GET /health` returns 200 `ok`, 503 `loading model`, 500 `error`. Add `?include_slots` for slot detail, `?fail_on_no_slot` to return 503 when all slots are busy.
- **Metrics:** start with `--metrics` (or `LLAMA_ARG_ENDPOINT_METRICS=1`) and scrape `/metrics`: `llamacpp:prompt_tokens_total`, `llamacpp:tokens_predicted_total`, `llamacpp:prompt_tokens_seconds`, `llamacpp:predicted_tokens_seconds`, `llamacpp:kv_cache_usage_ratio`, `llamacpp:kv_cache_tokens`, `llamacpp:requests_processing`, `llamacpp:requests_deferred`.
- **Slots:** `GET /slots` shows per-slot state and sampling settings; disable with `--slots-endpoint-disable` if the host is shared.
- **Logs:** startup logs show offload and buffer sizes. `--minilog` logs request and response bodies, so treat logs as containing prompts. `-ld/--logdir` writes YAML logs per the server README.
- **Timings:** each completion response has a `timings` object with prompt and predicted tokens per second.

```bash
curl -s http://127.0.0.1:8080/metrics | grep -E 'tokens_seconds|kv_cache_usage'
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv
```
