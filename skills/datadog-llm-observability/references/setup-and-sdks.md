# Datadog Agent Observability: setup and SDKs

> Verified against Datadog Agent Observability docs, ddtrace 4.15.6 and dd-trace 6.20.1, 2026-10-11

The product is called Agent Observability in the docs (formerly LLM Observability; the URL path is still `/llm_observability/`, and the metric prefix is `ml_obs.*`). It is not available on the `ddog-gov.com` sites listed in the docs banner. It is a paid Datadog product: check the pricing page, do not assume a free tier.

## Pick a transport

| Path                       | Needs                                                                               | Use when                                                                                 |
| -------------------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| SDK with the Datadog Agent | Agent on the host (trace port 8126)                                                 | You already run the Agent                                                                |
| SDK agentless              | `DD_API_KEY` and `DD_SITE`, `DD_LLMOBS_AGENTLESS_ENABLED=1`                         | No Agent, a container or serverless                                                      |
| OpenTelemetry              | An OTLP/HTTP exporter or Collector                                                  | Non-Python language, or you already emit GenAI spans (`references/otlp-and-gateways.md`) |
| HTTP API                   | `DD-API-KEY` header, `POST https://api.<DD_SITE>/api/intake/llm-obs/v1/trace/spans` | No SDK or OTel option                                                                    |

## Python (recommended path)

```bash
pip install 'ddtrace==4.15.6'
DD_LLMOBS_ENABLED=1 DD_LLMOBS_ML_APP=my-app DD_SITE=datadoghq.com DD_LLMOBS_AGENTLESS_ENABLED=1 \
  ddtrace-run python app.py          # DD_API_KEY comes from the environment, set from a 0600 file
```

`ddtrace-run` auto-instruments installed integrations, all enabled by default. In code instead:

```python
from ddtrace.llmobs import LLMObs
LLMObs.enable(ml_app="my-app", agentless_enabled=True)   # site and api_key default to DD_SITE and DD_API_KEY
```

Disable auto-instrumentation with `integrations_enabled=False` and create spans manually (`LLMObs.llm`, `LLMObs.workflow`, `LLMObs.annotate`).

## Node and others

```bash
npm install dd-trace
DD_LLMOBS_ENABLED=1 DD_LLMOBS_ML_APP=my-app DD_SITE=datadoghq.com \
  NODE_OPTIONS="--import dd-trace/initialize.mjs" node app.js
```

Java uses the `dd-java-agent.jar` with `-Ddd.llmobs.enabled=true -Ddd.llmobs.ml.app=...`. Go is marked experimental in the docs.

## Variables

`DD_LLMOBS_ENABLED`, `DD_LLMOBS_ML_APP` (names the application; allowed characters are in the docs), `DD_SITE`, `DD_API_KEY`, `DD_LLMOBS_AGENTLESS_ENABLED` (default false), `DD_LLMOBS_SAMPLE_RATE` (default 1.0; Go does not support it).

## Self-hosted engines

There is no engine-side tracing to switch on except one: the vLLM auto-integration (`vllm` 0.10.2 or newer with ddtrace 4.2.0 or newer) traces `Processor.process_inputs` and `OutputProcessor.process_outputs` inside the vLLM process, capturing model, tokens and latency (time to first token, queue, prefill, decode). For llama.cpp, SGLang and Ollama, trace from the client: an OpenAI-compatible client with `base_url` pointed at the server is picked up by the OpenAI integration (OpenAI SDK 1.0 or newer, ddtrace 2.9.0 or newer). The model name recorded is what you send.

## Proxies and gateways

For an LLM gateway used by many applications, enable the SDK with a service name and no ml_app (`LLMObs.enable(service="chat-proxy")`), so spans filter by service. The application that calls the gateway enables its own `ml_app` and wraps the call in a `LLMObs.workflow`, giving one end-to-end trace.

## Lapdog (local, no account)

Datadog ships Lapdog, a local agent on `localhost:8126` with a browser dashboard for inspecting traces from your app or from coding agents, built on the open-source `dd-apm-test-agent`. It can forward to Datadog. Read its install guide before use; it can sit in the model request path for `lapdog claude` and `lapdog codex`.

## Read-only discovery

```bash
pip show ddtrace litellm | grep -E '^(Name|Version)'
curl -fsS https://pypi.org/pypi/ddtrace/json | jq -r .info.version
curl -fsS https://registry.npmjs.org/dd-trace/latest | jq -r .version
```
