# OpenLLMetry with self-hosted engines and gateways

> Verified against OpenLLMetry traceloop-sdk 0.62.4 (source packages/, docs tracing/supported), vLLM v0.31.0 (examples/observability/opentelemetry, source vllm/tracing), LiteLLM docs 2026-10-10 (observability/opentelemetry_integration), 2026-10-11

## OpenAI-compatible self-hosted endpoints (vLLM, SGLang, llama.cpp, TGI, Ollama's `/v1`)

The instrumentation hooks the client library, not the server, so any OpenAI SDK client pointed at your own `base_url` is traced:

```python
from traceloop.sdk import Traceloop
from openai import OpenAI

Traceloop.init(app_name="chat-app", disable_batch=True)
client = OpenAI(base_url="http://vllm:8000/v1", api_key="unused-or-your-key")
client.chat.completions.create(model="served-model-name", messages=[{"role": "user", "content": "ping"}])
```

The span records the model string the client sent, which is the served model name, and token usage the server returned; servers that omit `usage` give empty token counts (vLLM returns it for non-streaming; for streaming set the OpenAI `stream_options={"include_usage": True}` if your server supports it).

Ollama's native API has its own instrumentation (`opentelemetry-instrumentation-ollama`, listed in the docs table); its `/v1` endpoint is covered by the OpenAI instrumentation.

## Engine-side spans (vLLM)

Independent of OpenLLMetry, vLLM v0.31.0 can export its own spans: `--otlp-traces-endpoint`, bundled OTel packages, `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf` (default is gRPC), `OTEL_SERVICE_NAME`, `--collect-detailed-traces` (`model`, `worker`, `all`). Per source the engine emits one `llm_request` span with latency and token metadata and no prompt text. If the client sends W3C `traceparent` (OpenTelemetry HTTP-client instrumentation does it automatically), the engine span becomes a child in the same trace. Run both against one backend or a Collector, and give them different `service.name` values.

## LiteLLM

Two options, pick one layer:

| Layer                     | How                                                                                                                                                                                                                                                            |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App using the LiteLLM SDK | `Traceloop.init(...)`; the LiteLLM instrumentation is in the supported list (Python only)                                                                                                                                                                      |
| LiteLLM proxy             | The proxy's own callbacks (`callbacks: ["otel"]`, with `OTEL_EXPORTER`, `OTEL_ENDPOINT`, `OTEL_HEADERS`), not OpenLLMetry; see the `litellm` skill. You can still run OpenLLMetry in the apps that call the proxy, but then the LLM call appears in two places |

The proxy's content switch is `litellm.turn_off_message_logging=True` and the standard `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` variable (see `opentelemetry-genai`). OpenLLMetry's own switch is `TRACELOOP_TRACE_CONTENT`; they are independent.

Avoid double spans: if the proxy traces LLM calls, call the proxy with a plain HTTP client (or an OpenAI client with the OpenAI instrumentation blocked: `block_instruments={Instruments.OPENAI}`) and let the proxy own the LLM span, while apps keep workflow and tool spans through the decorators.

## Context propagation

One connected trace needs `traceparent` forwarded app -> gateway -> engine. `Traceloop.init` takes a `propagator=` argument; whether a header is injected on the outbound call depends on an HTTP client instrumentation (the OpenAI SDK uses httpx, so `opentelemetry-instrumentation-httpx`) being installed. Check in the backend that the gateway span shares the app's trace ID; if not, install the HTTP client instrumentation in the app.

## Threads

Python thread pools lose the active context; the docs have a "Usage with Threads" page for `ThreadPoolExecutor`. Wrap submitted callables so the context carries over.
