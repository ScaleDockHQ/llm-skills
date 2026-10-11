---
name: opentelemetry-genai
description: OpenTelemetry for GenAI, covering semantic conventions (gen_ai.* spans, metrics, status), OTel-native instrumentation packages, and a Collector that strips prompt content, samples and fans out traces. Use to instrument LLM apps, gateways or vLLM, capture or hide message content (OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT), migrate from openai-v2, or debug missing gen_ai spans. Not for picking a backend (llm-observability).
license: MIT
compatibility: Commands assume bash, curl, jq and Docker for validating Collector configs; Python 3.10+ for the instrumentation packages. Installing packages, running a Collector and enabling content capture need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# OpenTelemetry for GenAI

Vendor-neutral tracing for LLM calls: the OpenTelemetry GenAI semantic conventions define the span, metric and event vocabulary (`gen_ai.*`), instrumentation packages emit it from client libraries, and the OpenTelemetry Collector sits in your network to clean, sample and route it to any OTLP backend (Phoenix, Langfuse, MLflow, Jaeger, Tempo).

**Scope:** the standard, the official instrumentation and the Collector. Backends belong to `arize-phoenix`, `langfuse`, `mlflow-tracing`; the Traceloop library belongs to `openllmetry`; choosing a stack belongs to `llm-observability`.

**Status you must tell the user:** the conventions are in **Development** status, not stable. They moved to their own repository (`open-telemetry/semantic-conventions-genai`) which has no tagged release or schema URL yet, and names are changing (for example inference metrics are now `gen_ai.client.inference.*`). The official Python instrumentations are beta (`1.2b0`). Pin versions and expect renames.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
pip list 2>/dev/null | grep -iE '^opentelemetry' || true
env | cut -d= -f1 | grep -E '^OTEL_' || true                          # names only
grep -rIl --include='*.py' -E 'OpenAIInstrumentor|opentelemetry\.instrumentation' . 2>/dev/null | head
docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | grep -iE 'otel|collector|phoenix|langfuse|mlflow' || true
for p in opentelemetry-instrumentation-genai-openai opentelemetry-instrumentation-openai-v2 opentelemetry-util-genai; do
  printf '%s %s\n' "$p" "$(curl -fsS https://pypi.org/pypi/$p/json | jq -r .info.version)"; done
```

Ask only what discovery cannot show: which libraries and gateways emit calls, which backend receives them (OTLP/HTTP or gRPC), whether content may be stored, and whether a Collector already exists.

## Decision flow

1. **What is the standard and how stable is it:** status, repositories, opt-in. -> `references/semconv-status.md`
2. **Attribute, span and metric names to query or map:** -> `references/attributes-and-signals.md`
3. **Instrument a Python app (OpenAI, Anthropic, Bedrock, Gemini, LangChain, agents):** -> `references/instrumentation.md`
4. **Migrate from `opentelemetry-instrumentation-openai-v2` or the `OTEL_SEMCONV_STABILITY_OPT_IN` flag:** -> `references/instrumentation.md`
5. **Content capture and privacy:** decide before real traffic. -> `references/content-and-privacy.md`
6. **Collector: strip content, sample, fan out, retry:** -> `references/collector.md`
7. **Send to Phoenix, Langfuse, MLflow; LiteLLM and vLLM:** -> `references/backends-and-gateways.md`
8. **Version bumps:** -> `references/updating.md`
9. **No spans, empty content, wrong names:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Package installs, env vars, Collector deployment and content capture need approval and an undo path.
- **Secrets never touch output.** Backend credentials go in `0600` env files or secret stores; the Collector config reads them with `${env:NAME}`.
- **Content capture is off by default and should stay a written decision.** `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` unset or invalid means `NO_CONTENT`. Strip content again at the Collector as a second line of defense.
- **Do not mix generations of names.** Older material (`gen_ai.client.token.usage`, `gen_ai.prompt.N.*`, `gen_ai.system`) is superseded; confirm which names your instrumentation emits before writing dashboards or redaction rules.
- **One layer owns each LLM call.** App instrumentation plus a gateway callback double-count spans and tokens.
- **Prefer a local Collector over direct export** when content, sampling or several backends are involved.
- **Verify upstream.** Names and defaults come from the conventions repo and package changelogs at use time.

## Workflows

### Instrument an app

- [ ] Install the instrumentation for the client library -> `references/instrumentation.md`.
- [ ] Set `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT` and the protocol; leave content capture unset.
- [ ] Run `opentelemetry-instrument` or call the instrumentor, make one request, find a `chat <model>` span with `gen_ai.usage.*` attributes.

### Deploy a content-stripping Collector

- [ ] Copy `assets/otel-collector.yaml`, set endpoints and exporters; keep secrets in an env file.
- [ ] Validate: `docker run --rm -v "$PWD/otel-collector.yaml:/c.yaml:ro" -e BACKEND_AUTH_PHOENIX=x -e LANGFUSE_BASIC_AUTH=x otel/opentelemetry-collector-contrib:<tag> validate --config=/c.yaml` (pin a tag; `curl -fsS https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest | jq -r .tag_name`).
- [ ] Point apps at the Collector, send the canary, check the backend -> `references/content-and-privacy.md`.

### Privacy and retention

- [ ] Fill the decision record, run the canary after every upgrade -> `references/content-and-privacy.md`.
- [ ] Retention is the backend's setting; the Collector and SDK store nothing durable.

## Reference index

| File                                   | Read when                                                             |
| -------------------------------------- | --------------------------------------------------------------------- |
| `references/semconv-status.md`         | Stability, repositories, what changed, opt-in variables               |
| `references/attributes-and-signals.md` | Span, metric and event names, key attributes, operation values        |
| `references/instrumentation.md`        | Official packages, zero-code and manual use, openai-v2 migration      |
| `references/content-and-privacy.md`    | Capture modes, upload hook, Collector redaction, canary               |
| `references/collector.md`              | Receivers, processors, sampling, exporters, deployment, validation    |
| `references/backends-and-gateways.md`  | Phoenix, Langfuse, MLflow, LiteLLM, vLLM, OpenAI-compatible endpoints |
| `references/updating.md`               | Pins, changelogs, rename handling                                     |
| `references/troubleshooting.md`        | Symptom to cause to fix                                               |

Assets and scripts: `assets/otel-collector.yaml` (validated against contrib 0.162.0, strips content, tail-samples, three exporters), `scripts/check.sh` (read-only: OTEL variables by name, package versions, OTLP route probe).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-observability`: choosing and combining tracing backends.
- `arize-phoenix`, `langfuse`, `mlflow-tracing`: backends that receive the spans.
- `openllmetry`: a Traceloop-maintained alternative instrumentation library.
- `litellm`, `vllm`: gateway and engine that emit or forward spans.
