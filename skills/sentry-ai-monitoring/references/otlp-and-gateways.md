# Sentry AI monitoring: OTLP, LiteLLM and engines

> Verified against Sentry docs (OpenTelemetry Protocol, Direct OTLP Traces, Python LiteLLM integration) and LiteLLM docs "Sentry", 2026-10-11

## What goes where

| Source                          | Request traces to Sentry                                                                                             | Engine metrics                                                                 |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| vLLM, llama.cpp, SGLang, Ollama | Client-side: the app's Sentry SDK with the OpenAI integration pointed at the server (`references/setup-and-sdks.md`) | `vllm:*`, `sglang:*`, `llamacpp:*` (Ollama has none): `prometheus-grafana-llm` |
| LiteLLM proxy                   | `sentry` callback for exceptions only; agent tracing needs the SDK integration in-process or OTel                    | `litellm_*` on `/metrics` (`litellm`)                                          |

Sentry does not ingest OTLP metrics, so Prometheus stays the home for engine metrics.

## Direct OTLP export (open beta)

```bash
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://o<orgId>.ingest.sentry.io/api/<projectId>/integration/otlp/v1/traces"
export OTEL_EXPORTER_OTLP_TRACES_HEADERS="x-sentry-auth=sentry sentry_key=<public key from Client Keys>"
```

Both values come from Project settings, Client Keys (DSN). For self-hosted Sentry, use your own host in the same path.

Limits stated in the docs:

- Span events are dropped at ingestion. Many GenAI instrumentations put message content in span events, so it will not arrive; content must be span attributes.
- Span links and array attributes are shown but cannot be searched, filtered or aggregated.
- Sentry ingests OTLP traces and logs, not metrics.

Agent views are driven by the `gen_ai.*` attributes (`gen_ai.operation.name`, `gen_ai.request.model`, token usage, `gen_ai.agent.name`, `gen_ai.conversation.id`). Whether a given OTel instrumentation produces the exact attributes the Agents UI needs was not tested; canary-test it and look in Explore, Traces first.

## Collector in front

`assets/otel-collector.yaml` (validated with collector-contrib 0.162.0) receives OTLP/HTTP on loopback 4318, deletes message and tool-call content attributes, batches and exports with the key from the environment. Forwarding through a Collector, Vector or Fluent Bit is Sentry's documented path for infrastructure sources; the Sentry exporter routes to multiple projects.

## LiteLLM proxy: exceptions

```yaml
litellm_settings:
  failure_callback: ["sentry"] # exceptions
  input_callback: ["sentry"] # breadcrumbs
  turn_off_message_logging: true # keeps messages and responses out of Sentry
```

Env: `SENTRY_DSN`, optional `SENTRY_API_SAMPLE_RATE` (errors), `SENTRY_API_TRACE_RATE` (transactions), `SENTRY_ENVIRONMENT`. The docs call this integration community maintained. LiteLLM scrubs secrets (`sk-` keys, auth headers, master key, database URL) and user identity before sending; `SENTRY_SEND_DEFAULT_PII=true` lets identity through.

## Unverified here

- Whether the LiteLLM SDK integration traces the proxy server process.
- Whether vLLM's own OpenTelemetry spans (`--otlp-traces-endpoint`) are rendered usefully in the Agents views.
