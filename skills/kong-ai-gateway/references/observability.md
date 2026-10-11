# Observability

> Verified against Kong AI Gateway 2.2.0, Kong Gateway OSS 3.9.3, Kong Gateway EE 3.16.0.0, 2026-10-11

## 3.x plugin model

- `ai-proxy` `config.logging.log_statistics: true` adds model and token usage to the output of Kong log plugins (`file-log`, `http-log`, `tcp-log`, `syslog`, OpenTelemetry). `log_payloads: true` adds request and response bodies (and puts them in OTel traces if tracing is enabled). Payload logging stores prompts and answers; leave it off unless the data owner agrees, and restrict who reads the sink.
- Add a log plugin on the same Service or Route, for example `http-log` to a collector. Prometheus and OpenTelemetry plugins exist in Kong Gateway; check the AI-specific metric options on their pages.
- `X-Kong-LLM-Model` on responses names the model Kong selected.

## AI Gateway 2.x

The OpenTelemetry AI Policy exports OTLP metrics and traces. Set `config.metrics.enable_ai_metrics: true` and `config.metrics.endpoint`; `enable_latency_metrics` is needed for `gen_ai.server.request.duration` and `mcp.client.operation.duration`, and `enable_request_metrics` populates `error.type`.

Metrics (docs reference page "Gen AI OpenTelemetry metrics"): `gen_ai.client.operation.duration`, `gen_ai.server.request.duration`, `gen_ai.client.token.usage`, `gen_ai.server.time_to_first_token`, `gen_ai.server.time_per_output_token`, `kong.gen_ai.llm.cost`, cache, RAG and AWS guardrail latency metrics, `kong.gen_ai.mcp.*`, `mcp.client.operation.duration`, `mcp.server.operation.duration` and `kong.gen_ai.a2a.*`. Common attributes: `gen_ai.provider.name`, `gen_ai.request.model`, `gen_ai.response.model`, `gen_ai.operation.name`, `kong.auth.consumer.name`, `kong.gen_ai.request.mode` (`oneshot`, `stream`, `realtime`), `error.type`.

Send to an OTel Collector, then Prometheus and Grafana (skills `opentelemetry-genai`, `prometheus-grafana-llm`) or an LLM tracing tool (`llm-observability`).

## Discover

```bash
curl -s http://127.0.0.1:8101/plugins | jq -r '.data[] | select(.name|test("log|prometheus|opentelemetry")) | [.name,.enabled] | @tsv'
docker logs --tail 50 "$(docker ps -q --filter ancestor=kong:3.9.3 | head -1)" 2>&1 | grep -iE 'ai-|error' | head
```
