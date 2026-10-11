# OpenLLMetry: backend settings

> Verified against OpenLLMetry traceloop-sdk 0.62.4, Arize Phoenix v20.21.0, Langfuse docs (integrations/native/opentelemetry), MLflow 3.17.0 (genai/tracing/opentelemetry/ingest) and OpenTelemetry Collector contrib v0.162.0, 2026-10-11

Rule for all backends: `TRACELOOP_BASE_URL` is the base; the SDK appends `/v1/traces`. Put credentials in `TRACELOOP_HEADERS` from a `0600` env file. Set `TRACELOOP_METRICS_ENABLED=false` unless the backend accepts OTLP metrics, otherwise the SDK also sends metrics to the same base URL and the backend may reject them.

## Arize Phoenix (self-hosted)

```bash
TRACELOOP_BASE_URL=http://phoenix:6006
TRACELOOP_METRICS_ENABLED=false
# auth on: system API key as bearer
TRACELOOP_HEADERS="Authorization=Bearer%20${PHOENIX_API_KEY}"
# optional project routing (server 15.5.0+): add x-project-name
# TRACELOOP_HEADERS="Authorization=Bearer%20${PHOENIX_API_KEY},x-project-name=my-app"
```

Phoenix converts OTel `gen_ai.*` attributes to OpenInference at ingest (15.10.0+), so OpenLLMetry spans render with messages and token counts. Details: the `arize-phoenix` skill.

## Langfuse (self-hosted or cloud)

```bash
# in the launching shell, after sourcing a 0600 file that defines LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY
export TRACELOOP_BASE_URL=https://langfuse.example.com/api/public/otel      # Cloud EU: https://cloud.langfuse.com/api/public/otel
export TRACELOOP_HEADERS="Authorization=Basic%20$(printf '%s:%s' "$LANGFUSE_PUBLIC_KEY" "$LANGFUSE_SECRET_KEY" | base64 | tr -d '\n')"
export TRACELOOP_METRICS_ENABLED=false
```

Langfuse accepts OTLP over HTTP only (no gRPC), at `<host>/api/public/otel`; the SDK's `/v1/traces` suffix lands on a supported route. Langfuse's integration page also recommends the header `x-langfuse-ingestion-version`; check the `langfuse` skill for the current value. Do not echo the header; build it inside the env file.

## MLflow (3.6.0 or newer, SQL backend)

```bash
TRACELOOP_BASE_URL=http://mlflow:5000
TRACELOOP_HEADERS="x-mlflow-experiment-id=123"      # add ,X-MLFLOW-WORKSPACE=team-a when workspaces are enabled
TRACELOOP_METRICS_ENABLED=false
```

MLflow's OTLP endpoint is `/v1/traces`, HTTP only (gRPC not supported), needs a SQL-backed store, and routes by the experiment-ID header. MLflow translates Traceloop attributes. See `mlflow-tracing`.

## OpenTelemetry Collector

```bash
TRACELOOP_BASE_URL=http://otel-collector:4318         # the Collector's OTLP/HTTP receiver
TRACELOOP_METRICS_ENABLED=false
```

The Collector can strip content, sample, and fan out to several backends; configs are in `opentelemetry-genai`. Using gRPC instead: set `TRACELOOP_BASE_URL=otel-collector:4317` (no `http` prefix).

## Jaeger, Tempo and generic OTLP

Point `TRACELOOP_BASE_URL` at the OTLP/HTTP port (4318 for Jaeger all-in-one) and, if the backend needs a non-OTLP protocol, pass a custom `exporter=` to `Traceloop.init` (for example Zipkin). When an exporter is given, base URL, key and headers are ignored, and metrics stay off unless a `metrics_exporter` is also given.

## Verify the destination

```bash
scripts/check.sh                            # shows variable names set and probes the base URL
```

At startup the SDK prints `Traceloop exporting traces to <endpoint>`; run the app once with `disable_batch=True` and look for the span in the backend. If nothing arrives, use `troubleshooting.md`.
