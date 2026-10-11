# Datadog Agent Observability: privacy, governance and retention

> Verified against Datadog Agent Observability docs (Data Governance, SDK Reference span processing), 2026-10-11

## Decide first

Spans carry prompts and completions. Datadog is third-party hosting, in the site (region) you choose with `DD_SITE`. Decide in writing: content on, redacted or off; which `ml_app`; who can read; retention.

## Controls, strongest first

1. **Do not send content.** Strip at a Collector (`assets/otel-collector.yaml`), or skip instrumenting that path. Use `filter_processor` below to drop whole spans.
2. **Span processors (SDK).** A function that edits `span.input` and `span.output`, or returns `None` to drop the span. Python:

```python
from ddtrace.llmobs import LLMObs, LLMObsSpan

def redact(span: LLMObsSpan) -> LLMObsSpan:
    for m in span.input or []:
        m["content"] = ""
    for m in span.output or []:
        m["content"] = ""
    return span

LLMObs.register_processor(redact)   # with ddtrace-run; with LLMObs.enable(), pass span_processor=redact
```

For auto-instrumented spans, set a tag with `LLMObs.annotation_context(tags={...})` and branch on `span.get_tag(...)` for conditional redaction. Node has `llmobs.registerProcessor`. 3. **Sensitive Data Scanner integration** scans and redacts matching patterns in Agent Observability data on the Datadog side. This happens after the data has left your network, so it is a second layer, not a first. 4. **Data Access Control and RBAC:** restrict by the `ml_app` tag, and restrict projects, experiments, datasets and annotation queues. 5. **Self-hosting is not an option** for Datadog: if prompts may not leave the network, use `langfuse`, `weave` self-managed, or PostHog self-hosted.

## Retention (from the docs, check the page at use time)

| Data                    | Period                                                                           |
| ----------------------- | -------------------------------------------------------------------------------- |
| Traces and spans        | 15 days by default; 30, 60 or 90 with an add-on (not on the free tier)           |
| `ml_obs.*` metrics      | 15 months                                                                        |
| Experiments             | 15 days on free and on-demand, 90 days on committed plans, longer with an add-on |
| Dataset records         | current version 3 years, previous versions 90 days                               |
| Prompts in the registry | 3 years, extended on pull                                                        |

Per-span cost, tokens, latency and errors, and evaluation scores follow the span retention.

## Keys

`DD_API_KEY` is a secret; keep it in a `0600` env file or the secret store, never in code, logs or shell history. Use a dedicated key per service so it can be rotated alone. Prompts embedded in `ml_app` or tag values are visible to everyone with read access.

## Canary test

Send a request containing `CANARY-<random>`, open the trace, and confirm the string is absent (or redacted) in input, output and metadata.
