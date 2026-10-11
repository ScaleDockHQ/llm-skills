# MLflow with LiteLLM, vLLM and OpenAI-compatible endpoints

> Verified against MLflow 3.17.0 docs (genai/tracing/integrations/listing/litellm-proxy, litellm, openai, ollama), vLLM v0.31.0 (examples/observability/opentelemetry, source vllm/tracing), opentelemetry-python-genai 1.2b0 and a live OTLP ingest test, 2026-10-11

One layer owns each LLM call. Pick the gateway, the app or the engine, not all three, except for the engine span that links under a gateway or app span by `traceparent`.

## LiteLLM proxy

Server-side callback (traces every request through the proxy into one experiment):

```bash
pip install 'litellm[mlflow]'
```

```yaml
# litellm config.yaml
litellm_settings:
  success_callback: ["mlflow"]
  failure_callback: ["mlflow"]
```

```bash
export MLFLOW_TRACKING_URI=http://mlflow:5000          # base URL of the Tracking Server; with basic auth also MLFLOW_TRACKING_USERNAME / MLFLOW_TRACKING_PASSWORD from a 0600 env file
export MLFLOW_EXPERIMENT_NAME="LiteLLM Proxy"
litellm --config litellm_config.yaml
```

- Content: LiteLLM's `turn_off_message_logging: true` in `litellm_settings` is its general switch for logging callbacks; confirm in the LiteLLM docs for your version that it applies to the `mlflow` callback, then run the canary (`privacy-retention.md`).
- Client-side alternative: apps use the OpenAI SDK with `mlflow.openai.autolog()` against the proxy, which lets LLM spans nest in the app's own trace; then do not also enable the callback.
- Route through a Collector instead (`opentelemetry-genai`): LiteLLM's generic `otel` callback to a Collector, whose `otlphttp` exporter targets MLflow `/v1/traces` with the experiment header. That path gives you content stripping and sampling.
- Docker: put LiteLLM and MLflow on one network and use service names; add `mlflow:5000` to MLflow's `--allowed-hosts` or you get 403. Skill for the gateway: `litellm`.

## OpenAI-compatible self-hosted endpoints (vLLM, SGLang, llama.cpp, Ollama `/v1`)

Instrument the client, not the server:

```python
import mlflow
from openai import OpenAI
mlflow.set_tracking_uri("http://mlflow:5000"); mlflow.set_experiment("vllm-app")
mlflow.openai.autolog()
client = OpenAI(base_url="http://vllm:8000/v1", api_key="unused-or-your-key")
client.chat.completions.create(model="served-model-name", messages=[{"role": "user", "content": "ping"}])
```

The span records the model name sent and the usage the server returned; servers that omit `usage` give empty token counts. (This path follows from how autolog patches the OpenAI client; MLflow's docs describe the OpenAI integration and a separate Ollama page, but no vLLM page, so confirm with one request.)

Apps using OpenTelemetry instead of MLflow's SDK use `opentelemetry-instrumentation-genai-openai` and `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://mlflow:5000/v1/traces` (see `tracing.md`).

## vLLM engine spans

vLLM v0.31.0 exports spans itself: `--otlp-traces-endpoint`, `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf` (the default is gRPC, which MLflow does not accept), `OTEL_EXPORTER_OTLP_TRACES_HEADERS` with the experiment header, `OTEL_SERVICE_NAME`; `--collect-detailed-traces model|worker|all` adds timing at a performance cost.

```bash
export OTEL_SERVICE_NAME=vllm-server
export OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_TRACES_HEADERS="x-mlflow-experiment-id=1"       # plus Authorization=Basic%20... with auth
vllm serve <model> --otlp-traces-endpoint http://mlflow:5000/v1/traces
```

Per source the engine emits one `llm_request` span with latency and token metadata and no prompt text, using older attribute names (`gen_ai.usage.prompt_tokens`); MLflow will show it as a span, but token mapping may not apply. Client or gateway spans carry the content. Confirm flags on your version: `vllm serve --help=all | grep -i otlp`. Skill: `vllm`.

## Ollama

MLflow documents an Ollama integration (`mlflow.ollama.autolog()` or the OpenAI client at Ollama's `/v1`). Both trace from the client side.

## Verify

Send one request per path. In the UI: one trace per request, model name and token usage present, no content unless intended, canary absent. `scripts/check.sh` confirms the server side.
