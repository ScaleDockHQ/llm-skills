# Verify end to end and troubleshoot

> Verified against LiteLLM v1.105.0 (docs: proxy/prometheus, proxy/logging, observability/opentelemetry_v2), Langfuse v4.56.0 (self-hosting health endpoints) and Prometheus v3.15.0, 2026-10-11

## Send one test request

Use a LiteLLM virtual key held in a `0600` file; do not echo it.

```bash
( KEY=$(< ~/.config/litellm/test.key)
  printf 'header = "Authorization: Bearer %s"\n' "$KEY" | curl -sS -K - \
    -H 'Content-Type: application/json' http://127.0.0.1:4000/v1/chat/completions \
    -d '{"model":"<your-alias>","messages":[{"role":"user","content":"Say OK"}],"max_tokens":8}' | jq -r '.choices[0].message.content' )
```

## Verification ladder

1. **Gateway answers.** The request above returns text. If not, fix LiteLLM first (`litellm` skill).
2. **Callbacks loaded.** `docker compose logs --since 5m litellm` has no startup error naming `prometheus`, `langfuse_otel` or a label or metric name.
3. **Metrics exist.** From a container on the same network: `curl -fsS http://litellm:4001/metrics/ | grep -c '^litellm_'` is above zero (or use port 4000 with a key). No `litellm_proxy_total_requests` line means no request has completed since start, or the callback is missing.
4. **Prometheus scrapes.** `curl -fsS http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="litellm") | .health, .lastError'` shows `up` and an empty error.
5. **Prometheus has data.** `curl -fsS 'http://127.0.0.1:9090/api/v1/query?query=litellm_proxy_total_requests_metric' | jq '.data.result | length'` is above zero.
6. **Langfuse has the trace.** Open the project's Traces view; there is a generation for your alias within a minute or so. Langfuse ingests asynchronously through its worker, so also check `langfuse-worker` health (`/api/health`) if traces lag.
7. **Failures are visible.** `litellm_callback_logging_failures_metric` stays at zero.

## Symptom table

| Symptom                                     | Likely cause and check                                                                                                                                |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| No Langfuse traces, no error                | `LITELLM_OTEL_V2=true` missing from the proxy environment, so the OTel v2 preset does not run; or wrong `LANGFUSE_HOST` (preset defaults to US cloud) |
| 401 toward Langfuse                         | Public/secret key from a different project or region than `LANGFUSE_HOST`                                                                             |
| 404 on `/api/public/otel/v1/traces`         | Langfuse server too old for OTLP ingestion; use v3.63.0 or newer                                                                                      |
| Duplicate traces                            | Both `langfuse` (SDK) and `langfuse_otel` configured                                                                                                  |
| Prometheus target down                      | Wrong port, listener on another network, or key file unreadable by the `nobody` user in the Prometheus container                                      |
| 401 on `/metrics` port 4000                 | `require_auth_for_metrics_endpoint` on and the scrape key missing or invalid; or move to the dedicated port                                           |
| Dedicated port refuses connections          | LiteLLM older than v1.101.0, flag not set, or `prometheus` callback missing                                                                           |
| Metric present locally, empty in Grafana    | Name has a `_total` suffix in the exposition, or the data source points at another Prometheus                                                         |
| Gateway latency rose after enabling metrics | Scraping `/metrics` on the proxy port with many workers and labels; move to the dedicated port and trim labels                                        |
| Startup failure after editing labels        | Unknown name in `prometheus_exclude_labels`, `prometheus_exclude_metrics` or `prometheus_metrics_config`; the proxy validates at start                |
| Prompts visible in Langfuse unexpectedly    | `turn_off_message_logging` not set, or a per-request override re-enabled content                                                                      |

## Undo

Remove `langfuse_otel` and `prometheus` from `callbacks`, unset `LITELLM_OTEL_V2` and `PROMETHEUS_METRICS_PORT`, restart LiteLLM, and delete the Prometheus job. Data already stored in Langfuse and Prometheus stays until their own retention removes it.
