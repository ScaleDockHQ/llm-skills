# GenAI content capture, redaction and retention

> Verified against opentelemetry-util-genai 1.2b0 (utils.py, types.py, environment_variables.py), opentelemetry-instrumentation-genai-openai 1.2b0 README, semantic-conventions-genai main (requirement levels), OpenTelemetry Collector contrib 0.162.0 (transform processor tested), 2026-10-11

## What is stored where

OpenTelemetry libraries and the Collector keep nothing durable. Whatever reaches a backend is stored under that backend's retention (`arize-phoenix`: retention policies; `langfuse`: retention settings; `mlflow-tracing`: trace deletion). Decide content policy at three layers: instrumentation, Collector, backend.

## Layer 1: instrumentation

| `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` | Effect                                                                                                                                                                                        |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| unset, empty, `no_content`, or any invalid value     | No prompts, completions, tool arguments or results (default)                                                                                                                                  |
| `span_only`                                          | Content as span attributes                                                                                                                                                                    |
| `event_only`                                         | Content on `gen_ai.client.inference.operation.details` log events (emitted by default in this mode; needs a logs exporter, and `OTEL_INSTRUMENTATION_GENAI_EMIT_EVENT=false` suppresses them) |
| `span_and_event`                                     | Both                                                                                                                                                                                          |

Values are case-insensitive. `OTEL_INSTRUMENTATION_GENAI_COMPLETION_HOOK=upload` plus `OTEL_INSTRUMENTATION_GENAI_UPLOAD_BASE_PATH=<fsspec URI>` (install `opentelemetry-util-genai[upload]`) writes prompts and responses to a file or bucket and keeps references on spans: a way to keep payloads out of the trace backend while retaining them under storage-level access control and lifecycle rules. Then retention is that bucket's lifecycle policy; set one.

Metadata always present: model, provider, token counts, durations, error type, conversation ID, server address. Conversation or user identifiers can themselves be personal data.

## Layer 2: Collector

`assets/otel-collector.yaml` removes content attributes with the `transform` processor, including the legacy and OpenInference/OpenLLMetry names, so a misconfigured service cannot leak prompts. Adjust for **logs** if events are on:

```yaml
processors:
  transform/strip-log-content:
    error_mode: ignore
    log_statements:
      - context: log
        statements:
          - delete_key(log.attributes, "gen_ai.input.messages")
          - delete_key(log.attributes, "gen_ai.output.messages")
          - delete_key(log.attributes, "gen_ai.system_instructions")
```

Event content can also sit in the log body; if so, `set(log.body, "")` for matching records. Check a real record with the `debug` exporter first.

To redact rather than drop, use `redaction` (allowed keys and blocked value patterns) or OTTL `replace_pattern(span.attributes["gen_ai.input.messages"], "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "[email]")`. Test with the debug exporter. Whole-value JSON redaction by regex can corrupt structure; prefer dropping.

To hash a user ID: `set(span.attributes["user.id"], SHA256(span.attributes["user.id"]))` (check the function in your Collector version).

## Layer 3: backend

Set retention and access there; see the backend skill. Langfuse and Phoenix both support masking at ingestion in their SDKs, which does not apply to raw OTLP, so the Collector is the common control point.

## Decision record

- Environment, capture mode, layers that strip, where content lives (backend, bucket), retention days, who can read, review date.

## Canary test

- [ ] Send a request containing `PRIVACY-CANARY-<date>` and a fake email through each instrumented path.
- [ ] Search the backend, the upload bucket and Collector debug output for the marker.
- [ ] With `NO_CONTENT` it must be absent everywhere; with the Collector strip on it must be absent from backends even when apps capture content.
- [ ] Repeat after each upgrade of an instrumentation, the Collector or a backend.

## Pitfalls

- Setting `span_only` in a shared environment file for debugging and forgetting it.
- Content on events but no logs pipeline: either the SDK drops it or the Collector rejects logs, and you think content is off.
- Streaming and tool-call content appear in different attributes per instrumentation; strip by prefix as well.
- Images and audio can be inlined as base64 blob parts; they are large and sensitive.
