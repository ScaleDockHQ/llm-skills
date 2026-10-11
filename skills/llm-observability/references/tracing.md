# Request tracing: OpenTelemetry GenAI, Langfuse, Phoenix, OpenLLMetry

> Verified against OpenTelemetry semantic conventions v1.44.0 and semantic-conventions-genai main (2026-10-09, status Development), Langfuse v4.56.0 docs, Arize Phoenix 20.20.0 docs, OpenLLMetry 0.62.4, vLLM v0.31.0, LiteLLM v1.105.0, OpenTelemetry Collector contrib v0.162.0, 2026-10-11

## What it is and when to choose it

A trace follows one request (or one agent run) through app → gateway → engine, with spans carrying model, token usage, latency and, optionally, prompt and completion content. Add tracing after metrics, when you need to answer "what happened in _this_ request" or "which step of the chain is slow or wrong".

| Option                                                       | Choose when                                                                                                     | Notes                                                                 |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| **OpenTelemetry + any OTLP backend** (Jaeger, Tempo, vendor) | You already run OTel; you want latency/topology, not prompt review                                              | Vendor-neutral; GenAI conventions define attribute names              |
| **Langfuse**                                                 | LLM-centric UI: traces, sessions, costs, prompt management, evals, human review                                 | OSS (MIT core), self-host via Docker Compose; receives OTLP over HTTP |
| **Arize Phoenix**                                            | OTel-native LLM tracing plus evals and experiments, single container                                            | Receives OTLP HTTP on 6006 and gRPC on 4317                           |
| **OpenLLMetry (Traceloop SDK)**                              | Instrumentation library, not a backend: auto-instruments OpenAI/Anthropic/LangChain/etc. clients and emits OTel | Send to any of the above                                              |

## Install

Langfuse: needs web, worker, ClickHouse, Redis, Postgres and S3-compatible storage, so it is a product skill of its own. Install, secrets, ports and upgrades live there.

Depth: install the langfuse skill (npx skills add ScaleDockHQ/llms-skills --skill langfuse)

Phoenix:

```bash
docker run -d --name phoenix -p 6006:6006 -p 4317:4317 \
  -e PHOENIX_TELEMETRY_ENABLED=false \
  -e PHOENIX_WORKING_DIR=/data -v phoenix-data:/data \
  arizephoenix/phoenix:<tag>
```

Default storage is SQLite under `PHOENIX_WORKING_DIR`; set `PHOENIX_SQL_DATABASE_URL` for PostgreSQL.

OpenLLMetry in a Python app (upstream library, installed in the app's environment):

```bash
pip install traceloop-sdk
# in app startup: from traceloop.sdk import Traceloop; Traceloop.init()
export TRACELOOP_BASE_URL=http://10.0.0.1:4318     # OTLP/HTTP collector
export TRACELOOP_TRACE_CONTENT=false               # do not record prompts/completions
```

## Minimal working config

Langfuse takes OTLP over HTTP only (no gRPC) at `<host>/api/public/otel`, with Basic auth and a version header. The exact exporter variables are in the `langfuse` skill (see the Depth line above).

Pointing at Phoenix: `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://node-b:6006/v1/traces` (HTTP/protobuf) or gRPC on `node-b:4317`.

A Collector in the middle lets you strip content and fan out (backend-neutral example; the Langfuse exporter variant ships in the `langfuse` skill):

```yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }
processors:
  attributes/strip-genai-content:
    actions:
      - { key: gen_ai.input.messages, action: delete }
      - { key: gen_ai.output.messages, action: delete }
      - { key: gen_ai.system_instructions, action: delete }
  batch: {}
exporters:
  otlphttp/backend:
    endpoint: ${env:OTLP_BACKEND_ENDPOINT} # any OTLP/HTTP backend, including Langfuse or Phoenix
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [attributes/strip-genai-content, batch]
      exporters: [otlphttp/backend]
```

The `attributes` processor ships in the core and contrib Collector distributions. Instrumentations that put content in other attributes or span events (vendor-specific keys) need their own delete rules; inspect a real span first.

## How it plugs into the stack

**OpenTelemetry GenAI semantic conventions** (status: Development; maintained in `open-telemetry/semantic-conventions-genai`):

- Span attributes: `gen_ai.operation.name`, `gen_ai.provider.name`, `gen_ai.request.model`, `gen_ai.response.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, request params such as `gen_ai.request.temperature`, `gen_ai.request.max_tokens`.
- Content attributes `gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`, `gen_ai.tool.definitions` are **Opt-In** and flagged as likely to contain sensitive/PII data. The spec says capture should be gated by an explicit opt-in, giving `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` as the example; each instrumentation library documents its own switch.
- Metrics: `gen_ai.client.operation.duration`, token usage as `gen_ai.client.inference.usage.input_tokens` / `.output_tokens` (older releases used a single `gen_ai.client.token.usage` histogram, and some instrumentations needed `OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental` to emit the newer names), and server-side `gen_ai.server.request.duration`, `gen_ai.server.time_to_first_token`, `gen_ai.server.time_per_output_token`.
- Because the conventions are still in Development, attribute names change; pin instrumentation versions and check what your backend expects.

**Where spans come from:**

| Layer           | How                                                                                                                                                                                                                                                                                                                                                     |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App             | OpenLLMetry (`Traceloop.init()`), OpenInference instrumentors (Phoenix), Langfuse SDK, or vendor OTel GenAI instrumentation                                                                                                                                                                                                                             |
| LiteLLM gateway | `litellm_settings.callbacks: ["otel"]` with `OTEL_EXPORTER` (`otlp_http`, `otlp_grpc`, `console`), `OTEL_ENDPOINT`, `OTEL_HEADERS`; or `["langfuse_otel"]` with `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_OTEL_HOST`; or the classic `success_callback: ["langfuse"]` with `LANGFUSE_HOST`. See `gateway-logging.md` for content switches |
| vLLM            | `--otlp-traces-endpoint <url>`; `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf` to use HTTP (default is gRPC); `--collect-detailed-traces` (`model`, `worker` or `all`) adds timing detail at a performance cost. OTel packages are bundled. Whether vLLM spans include prompt text is unverified; inspect a span before sending to a shared backend |

**Propagation:** the app must forward W3C `traceparent` to the gateway and engine for one connected trace. Most OTel HTTP client instrumentations do this automatically; check that your gateway's callback continues the incoming trace instead of starting a new one.

## Operating

- Sample: keep 100% for errors and slow requests, sample the rest (head sampling in SDK or tail sampling in a Collector).
- Watch the backend's own storage growth; trace payloads with content are orders of magnitude larger than metrics.
- Retention:
  - Langfuse self-hosted keeps data indefinitely unless retention is configured, and retention is an Enterprise feature when self-hosting; details in the `langfuse` skill.
  - Phoenix: `PHOENIX_DEFAULT_RETENTION_POLICY_DAYS` (default 0 = infinite).
- Access: Langfuse and Phoenix UIs show full prompts if captured. Restrict accounts, enable SSO where available, and keep them off the public internet.

## Tuning knobs worth knowing

- `TRACELOOP_TRACE_CONTENT=false`: OpenLLMetry stops recording prompts, completions and embeddings.
- Langfuse masking (client-side hooks, Enterprise server-side masking): see the `langfuse` skill.
- LiteLLM `turn_off_message_logging: true` and `callback_settings.otel.message_logging: false` keep content out of gateway-emitted traces.
- Phoenix `PHOENIX_TELEMETRY_ENABLED=false` disables Phoenix's own product analytics (it states trace data is not included either way); `PHOENIX_ALLOW_EXTERNAL_RESOURCES=false` for air-gapped hosts.

## Known pitfalls

- **Langfuse does not accept OTLP gRPC**; use HTTP/protobuf or HTTP/JSON (more in the `langfuse` skill).
- **Disconnected traces**: missing `traceparent` propagation between app and gateway.
- **Double instrumentation**: app SDK and gateway callback both log the same LLM call; decide which layer owns LLM spans.
- **Content captured by default** in some SDKs and gateway callbacks; verify with a test request and inspect the stored span before production traffic.
- **Attribute churn** in GenAI conventions breaks dashboards built on raw attribute names.

## Official links

- OTel GenAI semantic conventions: https://github.com/open-telemetry/semantic-conventions-genai
- OTel semantic conventions (GenAI section, published): https://opentelemetry.io/docs/specs/semconv/gen-ai/
- OTel Collector attributes processor: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/attributesprocessor
- Langfuse OpenTelemetry: https://langfuse.com/integrations/native/opentelemetry
- Phoenix: https://arize.com/docs/phoenix
- Phoenix Docker: https://arize.com/docs/phoenix/self-hosting/deployment-options/docker
- OpenLLMetry: https://github.com/traceloop/openllmetry
- OpenLLMetry privacy: https://www.traceloop.com/docs/openllmetry/privacy/traces
- vLLM OpenTelemetry example: https://github.com/vllm-project/vllm/tree/main/examples/observability/opentelemetry
- LiteLLM logging: https://docs.litellm.ai/docs/proxy/logging
