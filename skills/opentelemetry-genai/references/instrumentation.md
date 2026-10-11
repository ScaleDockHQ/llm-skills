# Official GenAI instrumentation (Python)

> Verified against opentelemetry-python-genai 1.2b0 (README, instrumentation/*/README.rst, CHANGELOGs), opentelemetry-util-genai 1.2b0 and the deprecated opentelemetry-instrumentation-openai-v2 2.4b0, 2026-10-11

## Packages

Released in `open-telemetry/opentelemetry-python-genai` (all `1.2b0`, beta; they emit the current conventions unconditionally):

| Package                                                                                               | Instruments                                     | Import (instrumentor)                                                   |
| ----------------------------------------------------------------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------- |
| `opentelemetry-instrumentation-genai-openai`                                                          | `openai >=1.26,<4`: chat, Responses, embeddings | `opentelemetry.instrumentation.genai.openai.OpenAIInstrumentor`         |
| `opentelemetry-instrumentation-genai-anthropic`                                                       | `anthropic >=0.51,<2`                           | `opentelemetry.instrumentation.genai.anthropic.AnthropicInstrumentor`   |
| `opentelemetry-instrumentation-genai-bedrock`                                                         | `boto3 >=1.40.46,<2`                            | `opentelemetry.instrumentation.genai.bedrock.BedrockInstrumentor`       |
| `opentelemetry-instrumentation-google-genai`                                                          | `google-genai >=1.32,<3`                        | `opentelemetry.instrumentation.google_genai.GoogleGenAiSdkInstrumentor` |
| `opentelemetry-instrumentation-genai-langchain`                                                       | `langchain >=0.3.21,<2`                         | `opentelemetry.instrumentation.genai.langchain.LangChainInstrumentor`   |
| `...-genai-llama-index`, `-openai-agents`, `-agno`, `-dspy`, `-smolagents`, `-portkey`, `-qwen-agent` | frameworks                                      | see each package README                                                 |

Unreleased skeletons (do not rely on them): `claude-agent-sdk`, `crewai`, `weaviate-client`. Shared helper: `opentelemetry-util-genai` (handler, content capture, upload hook).

## Install and run (zero-code)

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install opentelemetry-distro opentelemetry-exporter-otlp opentelemetry-instrumentation-genai-openai
export OTEL_SERVICE_NAME=chat-app
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318          # a Collector or backend
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf                  # or grpc with port 4317
export OTEL_TRACES_EXPORTER=otlp OTEL_METRICS_EXPORTER=otlp OTEL_LOGS_EXPORTER=none
opentelemetry-instrument python app.py
```

- `OTEL_LOGS_EXPORTER=none` unless a logs pipeline exists; content then stays on spans only if you opt in. The package's own zero-code example sets `OTEL_LOGS_EXPORTER=otlp` because it demonstrates events.
- Leave `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` unset for no content (`content-and-privacy.md`).
- Backends that take traces only usually need the metrics exporter off: `OTEL_METRICS_EXPORTER=none`.

## Manual use

```python
from opentelemetry.instrumentation.genai.openai import OpenAIInstrumentor
OpenAIInstrumentor().instrument()      # after the SDK and exporters are configured, before creating clients is safest
```

Configure tracer, meter and logger providers first; the instrumentation uses the global providers. Instrumenting a client works for any `base_url`, so OpenAI-compatible servers (vLLM, SGLang, Ollama `/v1`, LiteLLM proxy) are traced from the app side.

## Migrating from `opentelemetry-instrumentation-openai-v2`

That package is deprecated and only receives security patches. The new package continues it.

```bash
pip uninstall opentelemetry-instrumentation-openai-v2
pip install opentelemetry-instrumentation-genai-openai
```

- Change the import from `opentelemetry.instrumentation.openai_v2` to `opentelemetry.instrumentation.genai.openai`; zero-code discovery needs no code change.
- Remove `OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental`; the flag is gone and the latest names are the only behavior. With the old package, leaving it unset kept the legacy names (`gen_ai.system`, `gen_ai.client.token.usage`) and event-based content.
- Update dashboards and alert rules for the new names (`attributes-and-signals.md`) and re-run the content canary: capture mode values and defaults differ from what you tuned before.

## Other languages and non-GenAI-specific libraries

JavaScript, Java and .NET have their own GenAI instrumentation efforts with varying maturity; check each language repository and the conventions repo before choosing. Where an official package does not exist, `openllmetry` (Python, JS, Go, Ruby) emits compatible OTel spans for many providers.

## Choosing between official and OpenLLMetry or OpenInference

- Official packages: neutral, track the conventions closely, fewer providers.
- `openllmetry`: broad provider and vector DB coverage, own attribute vocabulary partly converging.
- OpenInference (Phoenix): attribute vocabulary Phoenix renders best; Phoenix also converts canonical `gen_ai.*` at ingest.
- Do not run two of them against the same client.
