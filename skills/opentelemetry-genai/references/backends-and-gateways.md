# Sending GenAI telemetry to backends, gateways and engines

> Verified against Arize Phoenix v20.21.0, Langfuse docs (integrations/native/opentelemetry), MLflow 3.17.0 docs (genai/tracing/opentelemetry/ingest), LiteLLM docs 2026-10-10 (observability/opentelemetry_integration, phoenix_integration), vLLM v0.31.0 (examples/observability/opentelemetry, source vllm/tracing), 2026-10-11

Rule: set the **base** URL on exporters that append the signal path. With the OpenTelemetry SDK, `OTEL_EXPORTER_OTLP_ENDPOINT` is a base (the SDK appends `/v1/traces`); `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` is the full URL.

## Arize Phoenix

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://phoenix:6006                    # HTTP, port 6006 (gRPC is 4317)
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_HEADERS="authorization=Bearer <key from a 0600 file>,x-project-name=my-app"
```

Phoenix 15.10.0+ converts canonical `gen_ai.*` spans to its OpenInference model at ingest, so official GenAI instrumentation renders with messages and tokens (content only if captured). `x-project-name` routes to a project (server 15.5.0+). Without it, spans go to the `default` project. Skill: `arize-phoenix`.

## Langfuse

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=https://langfuse.example.com/api/public/otel
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <base64 of public:secret>"
```

HTTP/protobuf or JSON only (no gRPC). Traces only; metrics and logs are not ingested, so set `OTEL_METRICS_EXPORTER=none` and `OTEL_LOGS_EXPORTER=none` to avoid errors. Langfuse maps `gen_ai.*` attributes to its observation model. Skill: `langfuse`.

## MLflow Tracking Server

```bash
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://mlflow:5000/v1/traces
OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_TRACES_HEADERS="x-mlflow-experiment-id=<numeric id>"
```

Needs a SQL-backed MLflow store and a version with OTLP ingest (3.6.0+); HTTP only; the experiment ID header selects the destination (`mlflow experiments search` lists IDs). Skill: `mlflow-tracing`.

## Jaeger, Tempo, any OTLP backend

Point at the backend's OTLP port (Jaeger: 4317/4318). They store spans generically, so attributes show as tags without LLM-specific rendering. Use a Collector (`collector.md`) to strip content first.

## OpenAI-compatible self-hosted endpoints

Instrument the client, not the server: the instrumentation wraps the OpenAI SDK whatever `base_url` is.

```python
from openai import OpenAI
client = OpenAI(base_url="http://vllm:8000/v1", api_key="unused-or-your-key")   # traced by OpenAIInstrumentor
```

The span reports provider `openai` (the API dialect), the model string you sent, and token usage the server returned. A server that omits `usage` gives empty token attributes; for streaming, request usage in the final chunk (`stream_options={"include_usage": True}`) if the server supports it.

## vLLM engine spans

vLLM v0.31.0 exports engine-side spans itself: `--otlp-traces-endpoint`, `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf` (default is gRPC), `OTEL_SERVICE_NAME`, `--collect-detailed-traces model|worker|all` (costs performance). Per source it emits an `llm_request` span with latency and token metadata only (no prompt text) and older attribute names (`gen_ai.usage.prompt_tokens`, `gen_ai.usage.completion_tokens`). A `traceparent` header from the client links it into the app's trace. Check flags with `vllm serve --help=all | grep -i otlp`. Skill: `vllm`.

## LiteLLM proxy and SDK

Use LiteLLM's generic OTel callback or the backend preset, not both, and not alongside app-level instrumentation of the same call.

```yaml
# config.yaml
litellm_settings:
  callbacks: ["otel"]
  turn_off_message_logging: true # forces no content; metadata only
```

```bash
OTEL_EXPORTER=otlp_http
OTEL_ENDPOINT=http://otel-collector:4318/v1/traces        # LiteLLM takes the full traces URL
OTEL_HEADERS="<name>=<value>"                              # real values only in a 0600 env file; not needed for an unauthenticated Collector
LITELLM_OTEL_V2=true                                      # newer GenAI semconv path and presets such as arize_phoenix
```

- Check the LiteLLM docs for the exact variables in your version; preset callbacks exist for Phoenix (`arize_phoenix`) and Langfuse (`langfuse_otel`), and `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` is honored by the generic callback (`true` maps to event-only there).
- `turn_off_message_logging` overrides content capture. Callers can also pass redaction headers; decide whether clients are trusted.
- Sending to a Collector gives you the strip step even if a key disables redaction.
- Run LiteLLM and the Collector on one Docker network and use service names; `localhost` inside a container is the container.

## Verify end to end

```bash
scripts/check.sh                                   # variables by name, OTLP route status
```

Send one request through each path (app, gateway), then confirm in the backend: one trace ID across app, gateway and engine spans; model and token attributes present; no content unless intended; canary absent (`content-and-privacy.md`).
