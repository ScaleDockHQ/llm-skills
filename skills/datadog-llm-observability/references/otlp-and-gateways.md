# Datadog Agent Observability: OTLP, LiteLLM and engines

> Verified against Datadog Agent Observability docs (OpenTelemetry Instrumentation, Automatic Instrumentation, Tracing Proxy Services), 2026-10-11

## What goes where

| Source                    | Request traces to Datadog                                                                                       | Engine metrics                                                       |
| ------------------------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| vLLM                      | `vllm` auto-integration inside the engine process, or the client's OpenAI integration                           | `vllm:*` Prometheus series: `prometheus-grafana-llm`                 |
| llama.cpp, SGLang, Ollama | Client-side OpenAI integration, or OTel from the client                                                         | `llamacpp:*`, `sglang:*`; Ollama has none (`prometheus-grafana-llm`) |
| LiteLLM proxy             | `ddtrace-run` around the proxy (LiteLLM 1.65.4 or newer, ddtrace 3.9.0 or newer; traces SDK and router methods) | `litellm_*` on `/metrics` (`litellm`)                                |

Datadog Agent Observability is request tracing, cost and evaluations. It does not replace Prometheus for queue depth, KV cache or GPU series.

## LiteLLM proxy

Run the proxy under the tracer with `assets/litellm-proxy-datadog.env.example`:

```bash
set -a; . /etc/litellm/datadog.env; set +a      # 0600 file with DD_API_KEY and the names in the example
ddtrace-run litellm --config /etc/litellm/config.yaml --port 4000
```

Canary-test that spans show the proxy model names; the docs list the instrumented methods (chat completion and text completion, sync and async, streamed, plus the Router equivalents), and a method not listed, such as embeddings or responses, is not traced.

## OpenTelemetry (any language, any Collector)

Agent Observability accepts traces that follow the OpenTelemetry 1.37 or newer GenAI semantic conventions, or supported OpenInference conventions.

```bash
OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=<site-specific OTLP traces endpoint from the Datadog docs>
OTEL_EXPORTER_OTLP_TRACES_HEADERS=dd-api-key=<from a 0600 file>,dd-otlp-source=llmobs
OTEL_RESOURCE_ATTRIBUTES=dd_llmobs_enabled=true
# libraries emitting pre-1.37 attributes (for example strands-agents) also need:
OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental
```

- The OTLP traces intake takes `http/protobuf` or `http/json`, not gRPC.
- `dd-otlp-source=llmobs` routes spans to Agent Observability; `dd_llmobs_enabled=true` on any span of a trace converts that trace's GenAI spans (an explicit `false` on any span blocks the whole trace).
- Supported attributes include `gen_ai.provider.name`, `gen_ai.operation.name`, `gen_ai.request.model`, `gen_ai.usage.input_tokens` and `gen_ai.usage.output_tokens`; operation inputs and outputs can be attributes or span events.
- Some of this data may also land in APM traces, so mirror access controls with an APM restricted dataset when content is sensitive.
- The exact endpoint per site is injected into the docs page at render time and was not resolvable from the raw Markdown. Copy it from the OpenTelemetry Instrumentation page for your site (or the in-app onboarding) and say so to the user.

`assets/otel-collector.yaml` receives OTLP/HTTP on loopback 4318, adds `dd_llmobs_enabled`, deletes message-content attributes, batches and exports with the key from the environment. It validates with collector-contrib 0.162.0 apart from the site endpoint you supply.

## HTTP API

`POST https://api.<DD_SITE>/api/intake/llm-obs/v1/trace/spans` with `DD-API-KEY` and `Content-Type: application/json`. Span kinds: `agent`, `workflow`, `llm`, `tool`, `task`, `embedding` and more. Put token counts and cost in the `metrics` object. A separate evaluations endpoint accepts external evaluations and feedback.

## Unverified here

Whether vLLM's OpenTelemetry spans (`--otlp-traces-endpoint`) convert cleanly in Agent Observability was not tested. Use the vLLM integration or the client instead, and canary-test any direct export.
