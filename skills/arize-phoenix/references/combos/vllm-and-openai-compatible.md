# Phoenix with vLLM and OpenAI-compatible endpoints

> Verified against Arize Phoenix v20.21.0, vLLM v0.31.0 (examples/observability/opentelemetry, docs/design/metrics) and OpenInference OpenAI instrumentation, 2026-10-11

Self-hosted engines (vLLM, SGLang, llama.cpp, Ollama) speak the OpenAI API. There are two places to get spans: the client or gateway in front (rich LLM spans with messages) and the engine itself (timing metadata).

## Client-side: trace the OpenAI SDK pointed at your endpoint

The OpenAI instrumentor traces any OpenAI SDK client regardless of `base_url`:

```python
from phoenix.otel import register
from openai import OpenAI

register(project_name="vllm-app", auto_instrument=True)   # needs openinference-instrumentation-openai installed
client = OpenAI(base_url="http://vllm:8000/v1", api_key="not-needed-or-your-key")
client.chat.completions.create(model="served-model-name", messages=[{"role": "user", "content": "ping"}])
```

Spans carry the model name you send, provider `openai`, token counts and messages unless hidden (`privacy-retention.md`). This works for every OpenAI-compatible server, because the span comes from the client, not the engine.

## Gateway-side

If a LiteLLM proxy fronts the engine, trace there once (`combos/litellm.md`) rather than in every app, and avoid also instrumenting apps, or the same call appears twice.

## Engine-side: vLLM spans

vLLM bundles the OTel packages. Enable export with a flag and standard OTel variables:

```bash
export OTEL_SERVICE_NAME=vllm-server
export OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf        # default is grpc
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://phoenix:6006/v1/traces
vllm serve <model> --otlp-traces-endpoint="$OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
```

- gRPC alternative: `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=grpc://phoenix:4317` and, for plaintext, `OTEL_EXPORTER_OTLP_TRACES_INSECURE=true`.
- With Phoenix auth on, vLLM needs the bearer header (`OTEL_EXPORTER_OTLP_TRACES_HEADERS="authorization=Bearer ..."` from a secret file) or a Collector in between that adds it.
- `--collect-detailed-traces` (`model`, `worker`, `all`) adds forward and execute timing and costs performance (vLLM's design doc).
- In v0.31.0 source the engine emits one `llm_request` span (kind `SERVER`) per request with metadata only: `gen_ai.request.max_tokens/top_p/temperature/n`, `gen_ai.response.model`, `gen_ai.usage.prompt_tokens/completion_tokens` (older attribute names than the current OTel conventions) and `gen_ai.latency.*` timings (queue, scheduler, time to first token, end to end; model forward/execute/prefill/decode with detailed traces). No prompt or completion text is attached, so use client or gateway spans for content. They are not OpenInference LLM spans, so Phoenix shows them as generic spans and token usage may not map to its token columns. Confirm flags on your version with `vllm serve --help=all | grep -i otlp`.
- `traceparent` from the client continues into vLLM, giving one connected trace (app -> gateway -> engine) when each hop propagates it.

## Verify

```bash
vllm_ok=$(curl -fsS http://vllm:8000/v1/models | jq -r '.data[0].id'); echo "serving: $vllm_ok"
scripts/check.sh
```

Send one request, open the project, and confirm the trace has the app span and the vLLM span under one trace ID.
