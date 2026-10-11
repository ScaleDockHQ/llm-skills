# Langfuse with an OpenTelemetry Collector

> Verified against Langfuse v4.56.0 (docs: integrations/native/opentelemetry) and OpenTelemetry Collector releases v0.162.0 (2026-09-29), 2026-10-11

Use a Collector between apps and Langfuse to fan out to several backends, strip prompt content centrally, sample, or hide Langfuse keys from applications. Template: `assets/otel-collector.yaml`.

## Rules

- Exporter: `otlphttp` to `<langfuse host>/api/public/otel` with headers `Authorization: Basic <base64(pk:sk)>` and `x-langfuse-ingestion-version: 4`. The Collector may receive gRPC from apps, but the Langfuse leg must be HTTP.
- Build the auth string without echoing keys: `export LANGFUSE_AUTH_STRING=$(printf '%s:%s' "$LANGFUSE_PUBLIC_KEY" "$LANGFUSE_SECRET_KEY" | base64 | tr -d '\n')`, and pass it to the Collector as an environment variable from a `0600` env file.
- One Langfuse project per key pair: use separate exporters or Collectors per project.
- The `attributes` processor deletes the GenAI content attributes listed in the template; instrumentations that put content in other attributes or span events need their own rules. Inspect a real span before relying on it.
- Langfuse keeps only Langfuse-relevant spans by default when using its SDK; raw OTLP sends everything you route, so filter non-LLM spans in the Collector to avoid noise and cost.
- Trace-level attributes (`langfuse.user.id`, `langfuse.session.id`, tags, metadata) must be on every span; add them in the application or with baggage, not only on the root span.

## Verify

Send one span through the Collector, then check Langfuse Observations. If nothing arrives, run the Collector with the `debug` exporter added alongside, and check for 401 (keys), 404 (path) or a gRPC exporter pointed at Langfuse.

## Official links

- https://langfuse.com/integrations/native/opentelemetry
- https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/attributesprocessor
