# OpenLLMetry: privacy, redaction and sampling

> Verified against OpenLLMetry traceloop-sdk 0.62.4 (docs: privacy/traces, privacy/telemetry, configuration; source traceloop/sdk), 2026-10-11

OpenLLMetry is a library, so it stores nothing itself: whatever it puts on spans is stored by the backend. Retention is the backend's job (Phoenix: `PHOENIX_DEFAULT_RETENTION_POLICY_DAYS`; Langfuse: Enterprise retention when self-hosted; MLflow: trace archival and `delete_traces`; see those skills). The SDK sends no usage telemetry of its own: upstream states that since OpenLLMetry v0.49.2 (JS v0.21.1) no package collects telemetry.

## Content switches

| Mechanism                                                         | Effect                                                                                                                                                      |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TRACELOOP_TRACE_CONTENT=false`                                   | No prompts, completions or embeddings on spans; every instrumentation respects it. **Default is `true`.**                                                   |
| `Traceloop.init(trace_content=False)` (JS: `traceContent: false`) | Same, sets the environment variable process-wide and for child processes; last explicit value wins                                                          |
| `override_enable_content_tracing` in OTel context                 | Turns content on for specific calls even when globally off: `attach(set_value("override_enable_content_tracing", True))` before the call, set `False` after |
| JS `withWorkflow({ name, traceContent: false }, ...)`             | Per workflow, task, agent or tool                                                                                                                           |
| `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT`                          | Truncates decorator inputs and outputs, keeps structure                                                                                                     |
| `use_attributes=False`                                            | Messages as log events instead of attributes; without an event logger provider nothing is recorded                                                          |

With content off, metadata remains: model, token counts, latency, error messages, association properties (user and session IDs), resource attributes, custom attributes, and workflow or task names.

## Redact instead of drop

`span_postprocess_callback` runs on each ended span and may mutate attributes (the SDK unfreezes the attributes around the call):

```python
import re
from traceloop.sdk import Traceloop

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")

def redact(span):
    for key in ("gen_ai.input.messages", "gen_ai.output.messages"):
        value = span.attributes.get(key)
        if isinstance(value, str):
            span.attributes[key] = EMAIL.sub("[email]", value)

Traceloop.init(app_name="my-app", span_postprocess_callback=redact)
```

Keys depend on the instrumentation version, so inspect a real span first; test with the canary below. For content that must never leave the host, drop it at a Collector that sits in your network (`opentelemetry-genai`) as a second line of defense.

## Images

When messages contain images, the SDK's image uploader POSTs the base64 image to `<base URL>/v2/traces/<trace_id>/spans/<span_id>/images`, an endpoint of the Traceloop platform (0.62.4 source). Self-hosted OTLP backends do not serve that route, so expect error logs, and know that image data is sent to the same base URL you configured. Keep content off for multimodal apps unless that is acceptable.

## Sampling

- `Traceloop.init(sampler=...)` takes any OTel `Sampler` (for example `ParentBased(TraceIdRatioBased(0.1))`); `OTEL_TRACES_SAMPLER` variables apply when the tracer provider reads them.
- Tail sampling (keep all errors and slow requests) belongs in a Collector.

## Decision record

- Environment, content on/off, redaction method, backend and its retention days, who can read the backend, review date.

## Canary test

- [ ] Send `PRIVACY-CANARY-<date>` and a fake email through every instrumented path.
- [ ] Search the backend (UI search or its database) and any Collector debug output for the marker.
- [ ] With content off it must be absent; repeat after every SDK upgrade, since defaults change.

## Pitfalls

- Content is **on** unless you set the variable; a new service copied without it leaks prompts.
- `trace_content` in code is process-wide and persists across later `init` calls.
- Temporary debug captures become permanent: add an end date.
