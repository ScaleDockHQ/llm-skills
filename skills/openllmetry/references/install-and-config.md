# OpenLLMetry: install and configuration

> Verified against OpenLLMetry traceloop-sdk 0.62.4 (docs: getting-started-python, configuration, tracing/without-sdk, tracing/supported; source packages/traceloop-sdk), 2026-10-11

OpenLLMetry is a set of OpenTelemetry instrumentations (Apache-2.0) plus `traceloop-sdk`, a convenience layer that builds a tracer provider, exporter and the instrumentations for you. Spans are standard OTel, so any OTLP backend works.

## Python install

Python `>=3.10,<4` (SDK 0.62.4).

```bash
pip install traceloop-sdk==0.62.4        # pin; check the newest first
```

```python
from traceloop.sdk import Traceloop

Traceloop.init(app_name="my-app", disable_batch=True)   # call once, before using LLM clients; drop disable_batch in production
```

`app_name` becomes the OTel `service.name` and defaults to `sys.argv[0]`, so set it. `Traceloop.init` instruments every supported library that is installed. Narrow it with `instruments={Instruments.OPENAI}` or exclude with `block_instruments={...}` (the `Instruments` enum in `traceloop.sdk.instruments`).

## Environment variables (SDK arguments win over variables)

| Variable                                                  | Default                     | Meaning                                                                                                         |
| --------------------------------------------------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `TRACELOOP_BASE_URL`                                      | `https://api.traceloop.com` | OTLP endpoint base. `http://` or `https://` prefix: OTLP/HTTP and `/v1/traces` is appended. Otherwise OTLP/gRPC |
| `TRACELOOP_API_KEY`                                       | none                        | Sent as `Authorization: Bearer <key>`                                                                           |
| `TRACELOOP_HEADERS`                                       | none                        | `key1=value1,key2=value2` (use `%20` for spaces); when set, the API key is ignored                              |
| `TRACELOOP_TRACE_CONTENT`                                 | `true`                      | `false` stops recording prompts, completions and embeddings (all instrumentations respect it)                   |
| `TRACELOOP_TRACING_ENABLED`                               | `true`                      | Master switch for tracing                                                                                       |
| `TRACELOOP_METRICS_ENABLED`                               | `true`                      | Exports metrics to `TRACELOOP_METRICS_ENDPOINT` or the base URL                                                 |
| `TRACELOOP_METRICS_ENDPOINT`, `TRACELOOP_METRICS_HEADERS` | base URL / headers          | Separate metrics destination                                                                                    |
| `TRACELOOP_LOGGING_ENABLED`                               | `false`                     | Export logs; `TRACELOOP_LOGGING_ENDPOINT`, `TRACELOOP_LOGGING_HEADERS`                                          |
| `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT`                  | none                        | Truncates decorator inputs and outputs                                                                          |

Key `Traceloop.init` arguments: `app_name`, `api_endpoint`, `api_key`, `headers`, `disable_batch`, `exporter` (any OTel `SpanExporter`; then base URL, key and headers are ignored), `processor`, `sampler`, `resource_attributes={...}`, `metrics_exporter`, `logging_exporter`, `instruments`, `block_instruments`, `span_postprocess_callback`, `trace_content`, `use_attributes`. Check `help(Traceloop.init)` on the installed version.

Behaviors worth knowing from the source:

- With the default base URL and no API key (and no custom exporter or processor) `init` prints a red "Missing Traceloop API key" message and returns without tracing. Setting `TRACELOOP_BASE_URL` to your backend, or passing `exporter`, avoids it.
- `trace_content=True/False` in `init` writes the process-wide `TRACELOOP_TRACE_CONTENT` environment variable; the last explicit value wins and child processes inherit it.
- Messages go on spans as `gen_ai.input.messages` / `gen_ai.output.messages` attributes when `use_attributes` is true (the default), per the OTel GenAI shape; with `use_attributes=False` they go out as OTel log events and need a configured event logger provider, otherwise no content is recorded.
- It prints "Traceloop exporting traces to <endpoint>" at startup: use that line to confirm the destination.

## Workflow annotations

`@workflow`, `@task`, `@agent`, `@tool` decorators (and `with_workflow` style helpers in JS) group LLM calls into named spans. `@aworkflow` is deprecated; use `@workflow` for sync and async. Set association properties (user, session) with `Traceloop.set_association_properties({...})`; see the docs pages on sessions and association.

## Use the instrumentations without the SDK

Already running an OpenTelemetry SDK or Collector setup? Install only what you need and register against your own provider (set the provider before `instrument()`):

```bash
pip install opentelemetry-instrumentation-openai      # also -anthropic, -bedrock, -cohere, -litellm, -ollama, -langchain, -llamaindex, -vertexai, ...
```

```python
from opentelemetry.instrumentation.openai import OpenAIInstrumentor
OpenAIInstrumentor().instrument()
```

These `opentelemetry-instrumentation-*` packages are Traceloop's, versioned with the repo (openai 0.62.4 on PyPI), and are not the same as the OpenTelemetry project's own GenAI packages (`opentelemetry-instrumentation-genai-*`, see `opentelemetry-genai`). Do not install both for the same library.

## Other languages

Node.js (`@traceloop/node-server-sdk`, `Traceloop.initialize({...})` with `baseUrl`, `apiKey`, `headers`, `traceContent`, `disableBatch`, `instrumentModules`), Go and Ruby SDKs exist; check the matching getting-started page. In Node, import Traceloop before any LLM library or pass `instrumentModules`.

## What is supported

Docs list (check `tracing/supported` for the current table): Anthropic, Bedrock, SageMaker, Azure OpenAI, Cohere, Gemini, Vertex AI, Groq, Ollama, OpenAI, Together, Mistral, Replicate, Transformers, WatsonX and others; LangChain, LlamaIndex, CrewAI, Haystack, Agno, OpenAI Agents, LiteLLM; vector DBs (Chroma, Pinecone, Qdrant, Weaviate, pgvector and more). Unsupported libraries can be reported manually through the manual reporting API.
