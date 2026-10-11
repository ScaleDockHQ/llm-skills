# OpenLLMetry

An agent skill for tracing LLM applications with OpenLLMetry (Traceloop SDK), the Apache-2.0 OpenTelemetry instrumentation library. It covers installing `traceloop-sdk`, the `TRACELOOP_*` variables, sending spans to Phoenix, Langfuse, MLflow, Jaeger or a Collector without the Traceloop cloud, tracing OpenAI-compatible self-hosted engines, LiteLLM and vLLM, keeping content out of spans, redaction, sampling, upgrades and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill openllmetry
```

## Rules

- **Ask before changing the app.** Installing packages, changing the endpoint and enabling content capture need approval.
- **Secrets never touch output.** `TRACELOOP_HEADERS` and keys live in `0600` env files.
- **Content is on by default.** Set `TRACELOOP_TRACE_CONTENT=false` unless capture is a written decision.
- **Base URL has no `/v1/traces`.** The SDK appends it; `http(s)` means OTLP/HTTP, anything else gRPC.
- **One layer owns LLM spans.** Do not trace the same call in the app and the gateway.
- **Verify upstream.** Versions and variables come from the OpenLLMetry docs and releases at use time.

## References

- [`references/install-and-config.md`](references/install-and-config.md): install, `Traceloop.init`, variables.
- [`references/backends.md`](references/backends.md): Phoenix, Langfuse, MLflow, Collector, generic OTLP settings.
- [`references/self-hosted-and-gateways.md`](references/self-hosted-and-gateways.md): vLLM, OpenAI-compatible servers, LiteLLM, propagation.
- [`references/privacy.md`](references/privacy.md): content switches, redaction, sampling, canary test.
- [`references/updating.md`](references/updating.md): pinning and upgrade routine.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

**Scripts:** [`scripts/check.sh`](scripts/check.sh) is a read-only check of variables (by name) and OTLP reachability.

## Companion skills

- `arize-phoenix`, `langfuse`, `mlflow-tracing`: backends that receive the spans.
- `opentelemetry-genai`: GenAI semantic conventions and Collector configuration.

## License

MIT
