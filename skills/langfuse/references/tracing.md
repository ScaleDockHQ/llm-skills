# Langfuse: tracing and ingestion

> Verified against Langfuse v4.56.0 (docs: integrations/native/opentelemetry, docs/observability/sdk/overview, docs/observability/features/masking, upgrade-v3-to-v4), Python SDK 4.17.0, JS/TS SDK 5.13.1, 2026-10-11

Langfuse v4 is observations-first: a trace is the root observation of a tree of observations (spans, generations, tools, agents). Ingestion is OpenTelemetry-based; the old `POST /api/public/ingestion` batch API is being retired (the public API page marks it sunset as of 2026-11-16, and on default v4 write mode it returns `400` for everything except `score-create` and `sdk-log`).

## Choose an ingestion path

| Source                                           | Path                                                                                               |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| Python app                                       | Langfuse Python SDK v4 (OTel-native): `pip install langfuse`                                       |
| JS/TS app                                        | JS/TS SDK v5: `npm install @langfuse/tracing @langfuse/otel @opentelemetry/sdk-node`               |
| Any other language or an OTel collector          | OTLP over HTTP to `<host>/api/public/otel` (HTTP/protobuf or HTTP/JSON; **gRPC is not supported**) |
| LiteLLM proxy                                    | `callbacks: ["langfuse_otel"]`, see `references/combos/litellm.md`                                 |
| OpenLLMetry, OpenLIT, other OTel GenAI libraries | OTLP endpoint above; Langfuse maps `gen_ai.*` attributes to its data model                         |

Minimum SDK versions for real-time visibility on a v4 server: Python SDK >= 4.7.0, JS/TS SDK >= 5.4.0, or `x-langfuse-ingestion-version: 4` on direct OTel exporters. Older producers can appear after ~10-15 minutes. Python SDK v2 and older and JS/TS SDK v3 and older are rejected by a v4 server on default settings.

## Python SDK

```bash
pip install langfuse
export LANGFUSE_PUBLIC_KEY=...      # read from a 0600 env file or secret store
export LANGFUSE_SECRET_KEY=...
export LANGFUSE_BASE_URL=http://localhost:3000   # self-hosted URL; cloud EU is https://cloud.langfuse.com
```

```python
from langfuse import get_client

langfuse = get_client()
with langfuse.start_as_current_observation(as_type="span", name="process-request") as span:
    with langfuse.start_as_current_observation(as_type="generation", name="llm-response", model="my-model") as gen:
        gen.update(output="...")
langfuse.flush()   # required in short-lived scripts and serverless
```

`langfuse.auth_check()` verifies host and keys. Docs also describe an `@observe` decorator and a drop-in OpenAI wrapper. Verify env var names against the SDK docs of the version you install; the current docs use `LANGFUSE_BASE_URL` (LiteLLM's own integration docs still use `LANGFUSE_HOST` and `LANGFUSE_OTEL_HOST`).

## JS/TS SDK

Register the span processor once at startup (`instrumentation.ts`) and import it first:

```ts
import { NodeSDK } from "@opentelemetry/sdk-node";
import { LangfuseSpanProcessor } from "@langfuse/otel";

export const sdk = new NodeSDK({
  spanProcessors: [new LangfuseSpanProcessor()],
});
sdk.start();
```

Call `sdk.shutdown()` before exit in short-lived processes so events flush. Same three env vars as Python.

## Raw OTLP

```bash
# Build the Basic auth string without echoing keys; -w 0 or tr -d '\n' avoids GNU base64 line wrapping
AUTH_STRING=$(printf '%s:%s' "$LANGFUSE_PUBLIC_KEY" "$LANGFUSE_SECRET_KEY" | base64 | tr -d '\n')
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:3000/api/public/otel"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic ${AUTH_STRING},x-langfuse-ingestion-version=4"
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

Signal-specific form: `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=<host>/api/public/otel/v1/traces` and `OTEL_EXPORTER_OTLP_TRACES_HEADERS` with the same header. Self-hosted OTLP needs Langfuse >= v3.22.0. Without `x-langfuse-ingestion-version: 4`, directly ingested spans can lag by up to ~10 minutes. A Collector in the middle can strip content and fan out: `references/combos/otel-collector.md`.

## Attributes that must be on every span

To filter or aggregate by user, session, metadata, version, release or tags, put them on **every** span, not just the root. Langfuse attribute keys: `langfuse.user.id` (or `user.id`), `langfuse.session.id` (or `session.id`), `langfuse.trace.metadata.*`, `langfuse.version`, `langfuse.release`, `langfuse.trace.tags`, `langfuse.trace.name`. The SDKs provide `propagate_attributes()` (Python) and `propagateAttributes()` (TS). For raw OTel use baggage with a `BaggageSpanProcessor`, but never put secrets or personal data in baggage: it crosses service boundaries and reaches third-party APIs.

By default the SDK exports Langfuse spans, spans with `gen_ai.*` attributes and known LLM instrumentors; use a custom filter to export everything.

## Masking before data leaves the app

Python SDK has two hooks: `mask_otel_spans` (recommended; patches raw OTel span attributes at export) and `mask` (legacy; runs when SDK attributes are created). JS/TS has its own masking option. Server-side ingestion masking exists but is Enterprise (`references/privacy-retention.md`). Details and code: https://langfuse.com/docs/observability/features/masking.

## Verify

```bash
LANGFUSE_HOST=http://localhost:3000 scripts/check.sh      # health, readiness, key validity
```

Then send one traced request and find it in the Observations view (root observations only is the default filter, one row per trace). Missing data: `references/troubleshooting.md`.

## Pitfalls

- gRPC exporters fail; switch to `http/protobuf`.
- Double instrumentation: app SDK and a gateway callback both emitting the LLM call. Decide which layer owns generation spans.
- Content is captured by default in SDKs and callbacks; check a stored span before production traffic.
- OTel GenAI semantic conventions are still in Development status; pin instrumentation versions.
- Custom code posting to legacy ingestion or read endpoints (`/api/public/traces`, `/observations`, `/sessions`, `/scores`, `/metrics`) returns `404` on default v4; use OTLP, Observations API v2, Scores API v3, Metrics API v2.

## Official links

- https://langfuse.com/integrations/native/opentelemetry
- https://langfuse.com/docs/observability/sdk/overview
- https://langfuse.com/docs/observability/features/masking
- https://langfuse.com/docs/api-and-data-platform/features/public-api
- https://github.com/langfuse/langfuse-python
- https://github.com/langfuse/langfuse-js
