# Phoenix: sending traces

> Verified against Arize Phoenix v20.21.0, arize-phoenix-otel 0.17.2, OpenInference (docs: sdk-api-reference/python/arize-phoenix-otel, tracing/how-to-tracing, release-notes 05-2026), 2026-10-11

Phoenix speaks OTLP. Instrumentation comes from OpenInference packages (Phoenix's own attribute vocabulary: `llm.model_name`, `llm.input_messages.*`, `llm.token_count.*`), or from any OTel GenAI source, which Phoenix converts at ingest (see the end).

## Python: `phoenix.otel.register`

```bash
pip install arize-phoenix-otel openinference-instrumentation-openai openai
```

```python
from phoenix.otel import register

tracer_provider = register(
    project_name="my-llm-app",       # or PHOENIX_PROJECT (alias PHOENIX_PROJECT_NAME); default project is "default"
    auto_instrument=True,            # instruments every installed openinference-instrumentation-* package
    batch=True,                      # default False (sync export); batch for production
)
# call tracer_provider.shutdown() before a short-lived process exits when batch=True
```

Environment read by `register`: `PHOENIX_COLLECTOR_ENDPOINT` (server URL), `PHOENIX_API_KEY` (adds the bearer header), `PHOENIX_CLIENT_HEADERS`, `PHOENIX_GRPC_PORT`; `.env.phoenix` files are auto-loaded (`PHOENIX_DISCOVER_CONFIG=false` opts out). With nothing set it targets `http://localhost:4317` over gRPC.

| Goal       | Setting                                                                                       |
| ---------- | --------------------------------------------------------------------------------------------- |
| HTTP       | `register(endpoint="http://phoenix:6006/v1/traces")`, the full path is required in code       |
| gRPC       | `register(endpoint="http://phoenix:4317")` or `protocol="grpc"`                               |
| Env-driven | `export PHOENIX_COLLECTOR_ENDPOINT=http://phoenix:6006` (the helpers add `/v1/traces`)        |
| Auth       | `export PHOENIX_API_KEY=...` from a `0600` file; or `headers={"Authorization": "Bearer ..."}` |

Instrumentor packages (one per library): `openinference-instrumentation-openai`, `-anthropic`, `-litellm`, `-langchain`, `-llama-index`, `-bedrock`, `-vertexai`, `-google-genai`, `-openai-agents`, and others; see the Phoenix integrations list. Manual: `from openinference.instrumentation.openai import OpenAIInstrumentor; OpenAIInstrumentor().instrument(tracer_provider=tracer_provider)`.

## TypeScript

```bash
npm i @arizeai/phoenix-otel @arizeai/openinference-instrumentation-openai openai
```

`@arizeai/phoenix-otel` (2.x) wraps the Node tracer provider the way `register` does; the raw approach uses `NodeTracerProvider` with `OTLPTraceExporter` from `@opentelemetry/exporter-trace-otlp-proto` pointed at `http://phoenix:6006/v1/traces` and `SEMRESATTRS_PROJECT_NAME` set as a resource attribute. Import the instrumented SDK after the instrumentation file runs.

## Raw OTLP from anything else

No Phoenix library required:

```bash
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://phoenix:6006/v1/traces     # HTTP/protobuf
export OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS="authorization=Bearer ${PHOENIX_API_KEY}"   # only when auth is on
export OTEL_RESOURCE_ATTRIBUTES=openinference.project.name=my-llm-app
```

gRPC works against `phoenix:4317` (`OTEL_EXPORTER_OTLP_PROTOCOL=grpc`, `OTEL_EXPORTER_OTLP_TRACES_INSECURE=true` for plaintext). Phoenix accepts protobuf only on `/v1/traces`.

## Projects

Resolution order for the project of a span: `x-project-name` HTTP header (server 15.5.0+, applies to the whole request) > `openinference.project.name` resource attribute > the server default. Headers are the way to route through an OTel Collector without touching apps:

```yaml
exporters:
  otlphttp/phoenix:
    endpoint: http://phoenix:6006
    headers: { x-project-name: my-project }
```

## Context and sampling

- Cross-service traces need W3C `traceparent` propagation; most OTel HTTP clients do it, but check the gateway continues the incoming trace.
- Head sampling in the SDK (`OTEL_TRACES_SAMPLER`, `OTEL_TRACES_SAMPLER_ARG`) or tail sampling in a Collector. Upstream flags a silent `always_off` gotcha: confirm the sampler value spelling when spans vanish.
- Short-lived scripts: `batch=False` or call `shutdown()`, otherwise queued spans are lost.

## OTel GenAI sources (conversion at ingest)

Since 15.10.0 Phoenix converts `gen_ai.*` attributes to OpenInference when spans arrive: `gen_ai.input.messages`, `gen_ai.output.messages` (the doc's table also names `gen_ai.output.message`), `gen_ai.system_instructions` (prepended as a system message), tool definitions, `gen_ai.usage.*` (to `llm.token_count.*`) and model and provider. Existing OpenInference attributes win; conversion only fills gaps. So OTel-native instrumentation (for example `opentelemetry-instrumentation-genai-openai`, see `opentelemetry-genai`) renders fully with no Phoenix library. Content only appears if the instrumentation captured it.

## Annotations and evals

Annotate spans from the UI or the client, run evals with `arize-phoenix-evals`, and build datasets and experiments from traces. Those are product features beyond tracing; start from the Phoenix docs (`datasets-and-experiments`, `evaluation`) and keep judge models reachable from the server's network.

## Verify a trace arrived

```bash
scripts/check.sh                                   # health, version, projects
curl -fsS -H "Authorization: Bearer $(cat ~/.phoenix.key)" http://localhost:6006/v1/projects | jq -r '.data[].name'
```

Open the project's Traces tab. No project listed after a send means the exporter never reached the server: use `troubleshooting.md`.
