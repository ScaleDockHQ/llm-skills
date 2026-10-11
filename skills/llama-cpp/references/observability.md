# llama.cpp: observability

> Verified against llama.cpp b11556 (master; tools/server/README.md) and v0.6.0, 2026-10-11

## Health

`GET /health` (or `/v1/health`): public, `503 {"error":{"code":503,"message":"Loading model","type":"unavailable_error"}}` while loading, `200 {"status":"ok"}` when ready. It does not reset the idle-sleep timer and never reloads a sleeping model; the same holds for `GET /props`, `/models`, `/metrics`. Use it for liveness and readiness, but it says nothing about authentication.

## Prometheus metrics

Start with `--metrics` (or `LLAMA_ARG_ENDPOINT_METRICS=1`), scrape `GET /metrics`. In router mode add `?model=<id>`.

| Metric                                                                                                                                                        | Type                    | Meaning                                                           |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- | ----------------------------------------------------------------- |
| `llamacpp:prompt_tokens_total`, `llamacpp:prompt_seconds_total`, `llamacpp:prompt_tokens_seconds`                                                             | counter, counter, gauge | Prompt tokens, time, average prefill t/s.                         |
| `llamacpp:tokens_predicted_total`, `llamacpp:tokens_predicted_seconds_total`, `llamacpp:predicted_tokens_seconds`                                             | counter, counter, gauge | Generated tokens, time, average decode t/s.                       |
| `llamacpp:requests_processing`, `llamacpp:requests_deferred`                                                                                                  | gauge                   | In flight and queued (deferred means no free slot).               |
| `llamacpp:n_tokens_max`                                                                                                                                       | counter                 | High watermark of context used.                                   |
| `llamacpp:n_decode_total`, `llamacpp:n_busy_slots_per_decode`                                                                                                 | counter, gauge          | `llama_decode()` calls and average busy slots.                    |
| `llamacpp:spec_decode_num_draft_tokens_total`, `..._num_accepted_tokens_total`, `..._num_drafts_total`, `..._num_accepted_tokens_per_pos_total{position="N"}` | counter                 | Speculative decoding drafted versus accepted tokens (0 when off). |

Useful alerts: `requests_deferred > 0` for minutes (add slots or replicas), decode t/s dropping after a driver or build change, acceptance ratio `accepted/draft` under about 0.4 (draft not paying off; a threshold you should calibrate), `n_tokens_max` close to `-c`.

```bash
curl -s http://127.0.0.1:9931/metrics | grep -E '^llamacpp:(requests|predicted|prompt_tokens_seconds)'
```

## State endpoints

- `GET /props`: build info, model path, modalities, `chat_template`, default generation settings, sleeping status (field name not verified); `/props?model=<id>` in router mode.
- `GET /slots`: per-slot `id`, `n_ctx`, `is_processing`, and the current request's parameters; disable with `--no-slots`.
- `GET /models` (router): per-model `status.value` (`loaded`, `unloaded`, loading) and the args used; `GET /models/sse` streams status changes.

Per-request timing is in the response `timings` (prompt/predicted ms and tokens per second) and in server log lines `prompt eval time` and `eval time`.

## Logs

stdout/stderr by default; `--log-file FILE`, `--log-jsonl` (one JSON object per line, disables colours), `--log-timestamps`, `--log-prefix`, `-lv 0..5` (3 = info, 5 = debug), `-v` everything. Startup lines worth reading: backend and devices (`ggml_cuda_init`, `ggml_vulkan: Using`, Metal), `llama_model_load` memory table, layers offloaded, the `--fit` decision, `Chat format:` (tool-call handler), context per slot. Under systemd use `journalctl --user -u llama-server -f`; in Docker `docker logs -f NAME`; behind llama-swap `/logs/stream/<model>`.

Debug aids: `--log-prompts-dir DIR` writes prompts to files (contains user data: keep it off in production), `--perf` enables libllama timings, `GGML_RPC_DEBUG` for RPC, `GGML_VK_PERF_LOGGER=1` for Vulkan per-op timings.

## Tracing and dashboards

llama-server has no native OpenTelemetry exporter in the docs read. Trace at the gateway (`llm-observability` skill) and scrape `/metrics` with Prometheus; add node and GPU exporters (`nvidia-smi dmon`, DCGM, or `rocm-smi`) for utilisation and memory.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
