# OpenTelemetry for GenAI

An agent skill for vendor-neutral LLM tracing with OpenTelemetry. It explains the GenAI semantic conventions and their Development status, the official Python instrumentation packages (including the move from `openai-v2`), content capture and privacy, and an OpenTelemetry Collector that strips prompts, samples and fans out traces to Phoenix, Langfuse, MLflow or any OTLP backend, plus LiteLLM, vLLM and OpenAI-compatible endpoints.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill opentelemetry-genai
```

## Rules

- **Ask before changing the system.** Installs, env vars, Collector deployment and content capture need approval and an undo path.
- **Secrets never touch output.** Credentials live in `0600` env files and are read with `${env:NAME}`.
- **The conventions are not stable.** Status is Development; pin versions and expect renames.
- **Content capture is off by default.** Keep it a written decision and strip it again at the Collector.
- **One layer owns each LLM call.** No app plus gateway double tracing.
- **Verify upstream.** Names and defaults come from the conventions repo and package changelogs at use time.

## References

- [`references/semconv-status.md`](references/semconv-status.md): status, repositories, opt-in variables.
- [`references/attributes-and-signals.md`](references/attributes-and-signals.md): spans, metrics, events, key attributes.
- [`references/instrumentation.md`](references/instrumentation.md): official packages, zero-code, openai-v2 migration.
- [`references/content-and-privacy.md`](references/content-and-privacy.md): capture modes, upload hook, redaction, canary.
- [`references/collector.md`](references/collector.md): processors, sampling, exporters, operations.
- [`references/backends-and-gateways.md`](references/backends-and-gateways.md): Phoenix, Langfuse, MLflow, LiteLLM, vLLM.
- [`references/updating.md`](references/updating.md): pins and rename handling.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

**Assets and scripts:**

- [`assets/otel-collector.yaml`](assets/otel-collector.yaml): content-stripping, tail-sampling Collector (validated against contrib 0.162.0).
- [`scripts/check.sh`](scripts/check.sh): read-only variables, package and OTLP route check.

## Companion skills

- `llm-observability`: choosing a stack.
- `arize-phoenix`, `langfuse`, `mlflow-tracing`: backends.
- `openllmetry`: alternative instrumentation library.

## License

MIT
