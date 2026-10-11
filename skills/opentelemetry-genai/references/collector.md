# OpenTelemetry Collector for GenAI traces

> Verified against OpenTelemetry Collector contrib 0.162.0 (`otelcol-contrib components`, `validate`, a live strip-content test), opentelemetry.io Collector docs, 2026-10-11

Run a Collector between apps or gateways and backends when you need to strip content, sample, add auth headers, fan out to several backends, or buffer during backend outages. Apps then export to one local endpoint and never hold backend credentials.

## Pipeline shape

`receivers: [otlp]` -> `processors: [memory_limiter, transform/strip-content, tail_sampling, batch]` -> `exporters: [otlphttp/<backend>]`. Order matters: `memory_limiter` first, `batch` last. The ready-made file is `assets/otel-collector.yaml`; it removes `gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`, tool definitions and arguments, the legacy `gen_ai.prompt.N.*` and `gen_ai.completion.N.*`, OpenInference `llm.input_messages.*`, `input.value`/`output.value`, and OpenLLMetry `traceloop.entity.*`. Tested: a span carrying three secret attributes left the Collector with only `gen_ai.usage.input_tokens`.

## Install and run

Use the contrib distribution, which includes `transform`, `redaction`, `tail_sampling`, `attributes`, `filter` and the auth extensions (the core distribution does not).

```bash
tag=$(curl -fsS https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest | jq -r .tag_name)   # read-only; pin the value you choose
docker run --rm -v "$PWD/otel-collector.yaml:/etc/otelcol/config.yaml:ro" otel/opentelemetry-collector-contrib:${tag#v} validate --config=/etc/otelcol/config.yaml
docker run -d --name otelcol --restart unless-stopped --env-file ./otel.env \
  -p 127.0.0.1:4317:4317 -p 127.0.0.1:4318:4318 \
  -v "$PWD/otel-collector.yaml:/etc/otelcol/config.yaml:ro" otel/opentelemetry-collector-contrib:${tag#v}
```

`otel.env` (mode `0600`) holds `BACKEND_AUTH_PHOENIX`, `LANGFUSE_BASIC_AUTH` (base64 of `public:secret`) and similar. Binding to `127.0.0.1` keeps the receiver private; for other hosts use a Docker network or TLS plus auth.

## Receivers

- OTLP gRPC on `4317`, OTLP/HTTP on `4318` (`/v1/traces`, `/v1/metrics`, `/v1/logs`). Python apps default to gRPC unless `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`. Backends such as Langfuse and MLflow accept HTTP only, so the Collector's `otlphttp` exporter is the bridge from gRPC apps.
- Protect a receiver that crosses hosts with TLS and an auth extension (`bearertokenauth` or `basicauth` are in contrib), referenced by `auth: {authenticator: ...}` on the receiver and listed under `service.extensions`.

## Processors

| Need                        | Processor and pattern                                                                                                 |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Drop content attributes     | `transform` with `delete_key(span.attributes, "...")` and `delete_matching_keys(span.attributes, "<regex>")`          |
| Redact patterns             | `transform` with `replace_pattern(...)`, or `redaction` (allow-list of keys, blocked value regexes)                   |
| Drop whole spans or noise   | `filter` with OTTL conditions (health checks, internal probes)                                                        |
| Add or rewrite metadata     | `resource` / `attributes` (environment, team, `service.name` fixes)                                                   |
| Keep errors and slow traces | `tail_sampling` policies `status_code`, `latency`, `probabilistic`; ratio-only head sampling: `probabilistic_sampler` |
| Backpressure                | `memory_limiter`, then `batch`                                                                                        |

`error_mode: ignore` keeps a bad statement from dropping data; test every statement with the `debug` exporter (`verbosity: detailed`) before trusting it.

Tail sampling holds spans in memory for `decision_wait` and needs all spans of a trace on one Collector instance: run a single instance, or put a load-balancing exporter tier in front. Long-running agent traces exceeding `decision_wait` are split and sampled inconsistently; raise it or sample at the head for agents.

## Exporters and routing

- `otlphttp` with `endpoint` as the **base** (the exporter appends `/v1/traces`), `headers` for auth. Do not put `/v1/traces` in the endpoint unless you set `traces_endpoint`.
- One exporter per backend; list several in the pipeline for fan-out. Use separate pipelines when backends need different processing, for example a stripped copy to a shared backend and a full copy to a private one.
- Phoenix project routing: header `x-project-name`. MLflow: header `x-mlflow-experiment-id`. Langfuse: `Authorization: Basic ...` against `/api/public/otel`. Details: `backends-and-gateways.md`.
- Resilience: the exporter's `sending_queue` and `retry_on_failure` are on by default with an in-memory queue; for a persistent queue add the `file_storage` extension and `sending_queue.storage`.

## Operations

- Health: add the `health_check` extension (default port 13133) and probe it; metrics about the Collector itself are on `:8888` by default.
- Debug temporarily: add `debug` to a pipeline's exporters; remove it afterwards because detailed verbosity prints span content to logs.
- Logs: events from `OTEL_INSTRUMENTATION_GENAI_EMIT_EVENT` need a `logs` pipeline; without one the receiver rejects log exports. Prefer `OTEL_LOGS_EXPORTER=none` in apps if you do not need them.
- Update: change the pinned tag, run `validate`, canary, roll. Component names and settings change between minor versions; read the contrib changelog for your jump.

## Validation checklist

- [ ] `validate` exits 0 with the pinned image.
- [ ] A test span with canary attributes through the receiver arrives without them.
- [ ] Errors and slow spans survive the sampler; baseline share looks right.
- [ ] Backend credentials appear only in the `0600` env file.
