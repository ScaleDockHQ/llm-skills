# NVIDIA NIM observability

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: logging and observability page.

## Logs

NIM logs to stderr. `NIM_LOG_LEVEL` (default `WARNING`) controls NIM and the vLLM backend; override the
backend alone with `VLLM_LOGGING_LEVEL`. `NIM_JSONL_LOGGING=true` emits one JSON object per line with a
shared schema (`level`, `time`, `file_name`, `line_number`, `message`) for NIM and vLLM, recommended for
collectors such as Fluentd, Logstash or CloudWatch. Do not enable it for multi-node (Ray workers).

```bash
docker logs --tail 100 nim
docker run ... -e NIM_LOG_LEVEL=INFO <image>
```

## Metrics

`GET /v1/metrics` returns vLLM's native Prometheus metrics unchanged (latency, throughput, queue depth,
tokens, GPU use), so vLLM dashboards and alerts apply.

```yaml
scrape_configs:
  - job_name: "nim-llm"
    scrape_interval: 15s
    metrics_path: "/v1/metrics"
    static_configs:
      - targets: ["<nim-host>:8000"]
```

## Tracing and correlation

On `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings` and `/v1/responses`, NIM forwards
`X-Request-Id` (echoed back only if the caller sent it; never synthesised) and the W3C `traceparent`
header to the backend. Tracing headers are not forwarded on health or management endpoints. A custom
middleware (`--middleware`) can stamp other headers into logs.

## Health

`/v1/health/live` and `/v1/health/ready`. Readiness does not prove a given request is progressing.
`llm-observability` covers cost and traces across gateways.
