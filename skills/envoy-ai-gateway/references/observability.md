# Observability

> Verified against Agent Router (Envoy AI Gateway) v1.2.0 docs, chart values and examples (monitoring, access-log, aigw), 2026-10-11

Three signals, all driven by the ext-proc next to Envoy: Prometheus metrics (OpenTelemetry GenAI naming), OTel traces, and Envoy access logs enriched with dynamic metadata.

## Metrics

Collected for chat completions, completions, embeddings, Cohere rerank, TypeSafe System One and Anthropic messages (streaming and non-streaming):

- `gen_ai.client.token.usage` (attribute `gen_ai.token.type`: input, output, total, cached_input, cache_creation_input, reasoning)
- `gen_ai.server.request.duration`
- `gen_ai.server.time_to_first_token`
- `gen_ai.server.time_per_output_token`

Attributes include `gen_ai.operation.name`, `gen_ai.original.model` (as sent), `gen_ai.request.model` (after override), `gen_ai.response.model`, `gen_ai.provider.name` and, since v1.2.0, `gen_ai.backend` (`namespace/name` of the `AIServiceBackend`). Prometheus names use underscores (`gen_ai_client_token_usage_sum`, `gen_ai_backend`).

On Kubernetes the metrics are exposed on the Envoy pods of the Gateway; `examples/monitoring/monitoring.yaml` deploys a Prometheus that scrapes them, and `examples/monitoring/grafana-dashboard.json` imports a dashboard (tokens by type, request and TTFT percentiles, original versus response model, error rate, success by model). Standalone `aigw` serves `:1064/metrics` and `/health`.

```bash
# Sum tokens per model and type (Prometheus API; adjust the gateway name label)
curl -sG http://localhost:9090/api/v1/query --data-urlencode \
  'query=sum(gen_ai_client_token_usage_sum{gateway_envoyproxy_io_owning_gateway_name="llm"}) by (gen_ai_request_model, gen_ai_token_type)' \
  | jq -r '.data.result[]|[.metric.gen_ai_request_model,.metric.gen_ai_token_type,.value[1]]|@tsv'
curl -fsS http://127.0.0.1:1064/metrics | grep '^gen_ai_' | head
```

Alert candidates: error ratio (`gen_ai.error.type` set; the gateway records only a generic marker for GenAI errors), p95 `time_to_first_token`, token burn rate by tenant, response model differing from original model (silent provider swap). The `prometheus-grafana-llm` skill covers dashboards.

High-cardinality warning: map only low-cardinality request headers into metrics. Chart values on `controller`:

- `requestHeaderAttributes`: header to attribute map shared by metrics, spans and access logs, format `x-tenant-id:tenant.id`.
- `metricsRequestHeaderAttributes`: metrics only.
- `spanRequestHeaderAttributes`: spans only; defaults to `agent-session-id:session.id` when unset.

Session IDs belong in traces and logs, not metrics. Standalone `aigw` reads `OTEL_AIGW_REQUEST_HEADER_ATTRIBUTES`.

## Tracing

Set standard OTel SDK variables on the ext-proc, per Gateway through `GatewayConfig` (preferred) or chart `extProc.extraEnvVars`:

```yaml
apiVersion: aigateway.envoyproxy.io/v1beta1
kind: GatewayConfig
metadata: { name: llm-config, namespace: default }
spec:
  extProc:
    kubernetes:
      env:
        - {
            name: OTEL_EXPORTER_OTLP_ENDPOINT,
            value: "http://otel-collector.observability:4317",
          }
        - { name: OTEL_SERVICE_NAME, value: "ai-gateway" }
        - { name: OTEL_METRICS_EXPORTER, value: "none" } # when the backend takes traces only (Phoenix)
      resources:
        requests: { cpu: 100m, memory: 128Mi }
        limits: { memory: 512Mi }
```

Attach it to the Gateway with the annotation `aigateway.envoyproxy.io/gateway-config: llm-config` (same namespace). Other variables: `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, `OTEL_TRACES_EXPORTER` (`otlp`, `console`, `none`), `OTEL_BSP_SCHEDULE_DELAY`, `OTEL_METRIC_EXPORT_INTERVAL`.

Span vocabulary: `AI_GATEWAY_TRACING_SEMCONV` is unset or `openinference` (default; full request and response content recorded, which suits Arize Phoenix evals) or `gen_ai` (OTel GenAI semantic conventions, span name `chat {model}`, message content only when `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true`). An unrecognized value fails startup. The default records prompts and completions into traces; treat the trace store as sensitive or switch to `gen_ai` without content capture. Chat completions and embeddings are traced; MCP requests get `mcp.*` spans.

Standalone: pass the same variables to `aigw run`; `cmd/aigw/docker-compose-otel.yaml` in the repo wires Phoenix or an `otel-tui` viewer.

## Access logs

Per-request model and token details come from dynamic metadata in namespace `io.envoy.ai_gateway`. Define the costs on the route (`llmRequestCosts`, see `limits-and-quota.md`), then reference them from an `EnvoyProxy` JSON access log:

```yaml
telemetry:
  accessLog:
    settings:
      - matches: ["request.headers['x-ai-eg-model'] != ''"]
        sinks: [{ type: File, file: { path: /dev/stdout } }]
        format:
          type: JSON
          json:
            gen_ai.request.model: "%REQ(X-AI-EG-MODEL)%"
            gen_ai.response.model: "%DYNAMIC_METADATA(io.envoy.ai_gateway:response_model)%"
            gen_ai.provider.name: "%DYNAMIC_METADATA(io.envoy.ai_gateway:backend_name)%"
            gen_ai.usage.input_tokens: "%DYNAMIC_METADATA(io.envoy.ai_gateway:llm_input_token)%"
            gen_ai.usage.output_tokens: "%DYNAMIC_METADATA(io.envoy.ai_gateway:llm_output_token)%"
            response_code: "%RESPONSE_CODE%"
            upstream_host: "%UPSTREAM_HOST%"
            duration: "%DURATION%"
```

`examples/aigw/ollama.yaml` and `examples/access-log/basic.yaml` are complete versions, including MCP fields (`mcp.method.name`, `mcp.tool.name`, matched by `x-ai-eg-mcp-backend`). The metadata keys in the log must equal the `metadataKey` names in `llmRequestCosts`. Never log request bodies or `Authorization` headers.

## Logs and debugging

```bash
kubectl logs -n envoy-ai-gateway-system deploy/ai-gateway-controller --tail=100
kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=llm -c ai-gateway-extproc --tail=100 2>/dev/null \
  || kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=llm --all-containers --tail=100
```

Chart `extProc.logLevel` and `controller.logLevel` default to `info`; `debug` can print request content unless redaction is enabled (see `extProc` values), so use it briefly. `aigw` honors `AIGW_DEBUG`.
