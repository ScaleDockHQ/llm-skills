# Sending traces to MLflow

> Verified against MLflow 3.17.0 (docs genai/tracing: quickstart, opentelemetry/ingest, opentelemetry/genai-semconv, opentelemetry/export, lightweight-sdk, prod-tracing, faq; live OTLP ingest of a gen_ai.* span into 3.17.0), opentelemetry-python-genai 1.2b0, 2026-10-11

Two ways in. Pick one per application.

## A. MLflow SDK autolog (Python, TypeScript)

```bash
pip install mlflow-tracing                       # lightweight SDK for apps; never together with the full mlflow package
export MLFLOW_TRACKING_URI=http://mlflow:5000
export MLFLOW_EXPERIMENT_NAME=llm-app            # created on first use
# with basic auth on: MLFLOW_TRACKING_USERNAME and MLFLOW_TRACKING_PASSWORD from a 0600 env file
```

```python
import mlflow
mlflow.set_tracking_uri("http://mlflow:5000")
mlflow.set_experiment("llm-app")
mlflow.openai.autolog()          # also anthropic, gemini, litellm, langchain, llama_index, dspy, ... (dozens of integrations)

@mlflow.trace                    # manual spans for your own functions
def answer(q: str) -> str: ...
```

Autolog patches the client library, so it follows the library wherever it points (`base_url` of an OpenAI client). Disable with `mlflow.<flavor>.autolog(disable=True)`; the global kill switch is `MLFLOW_TRACING_ENABLED=false`. Production guidance: `mlflow-tracing` package, async logging (default), `MLFLOW_TRACE_SAMPLING_RATIO`, `MLFLOW_ASYNC_TRACE_LOGGING_MAX_QUEUE_SIZE`.

## B. OpenTelemetry (any language, any instrumentation)

The server exposes `POST /v1/traces` (OTLP/HTTP, protobuf) from MLflow 3.6.0; gzip or deflate compression is accepted from 3.7.0. Requirements: SQL backend store, HTTP not gRPC, experiment routing by header.

```bash
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://mlflow:5000/v1/traces       # full URL: this variable is not a base
export OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_TRACES_HEADERS="x-mlflow-experiment-id=1"          # numeric ID; add ,X-MLFLOW-WORKSPACE=team-a when workspaces are on
# basic auth on: ...HEADERS="x-mlflow-experiment-id=1,Authorization=Basic%20<base64 user:password>"
export OTEL_EXPORTER_OTLP_TRACES_COMPRESSION=gzip                             # 3.7.0+
```

Get the numeric experiment ID:

```bash
curl -sS -G "$MLFLOW_URL/api/2.0/mlflow/experiments/get-by-name" --data-urlencode experiment_name=llm-app | jq -r .experiment.experiment_id
```

(Create with `curl -sS -X POST "$MLFLOW_URL/api/2.0/mlflow/experiments/create" -H 'Content-Type: application/json' -d '{"name":"llm-app"}'`.)

**GenAI semantic conventions are recognized on ingest.** Tested on 3.17.0: a span with `gen_ai.operation.name=chat`, `gen_ai.provider.name`, `gen_ai.request.model`, `gen_ai.usage.input_tokens`/`output_tokens` and `gen_ai.input.messages`/`gen_ai.output.messages` arrived as a `CHAT_MODEL` span with token usage `{input: 7, output: 3, total: 10}` and structured inputs and outputs. Attributes in OpenInference and OpenLLMetry vocabularies are translated by the attribute mapping table in the docs (`genai/tracing/opentelemetry/attribute-mapping`). Without LLM attributes spans still appear as generic spans.

Official instrumentation and Collector configs: `opentelemetry-genai` skill (`npx skills add ScaleDockHQ/llm-skills --skill opentelemetry-genai`). A Collector between apps and MLflow adds content stripping and sampling:

```yaml
exporters:
  otlphttp/mlflow:
    endpoint: http://mlflow:5000 # base URL; the exporter appends /v1/traces
    headers:
      x-mlflow-experiment-id: "1"
      # authorization: "Basic ${env:MLFLOW_BASIC_AUTH}"      # base64 user:password from an env file
    compression: gzip
```

## C. MLflow SDK traces exported to other OpenTelemetry backends

Set `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` **before starting the app** and MLflow sends traces to that OTLP endpoint instead of the Tracking Server. `MLFLOW_TRACE_ENABLE_OTLP_DUAL_EXPORT=true` sends to both. `MLFLOW_ENABLE_OTEL_GENAI_SEMCONV=true` (MLflow 3.11+) exports `gen_ai.*` attributes instead of `mlflow.*`, which other backends understand.

## Verify

```bash
scripts/check.sh                      # server and OTLP route
```

Open the experiment in the UI: traces list with state OK, token usage and the span tree. Search from code: `mlflow.search_traces(locations=["<experiment id>"])`.
