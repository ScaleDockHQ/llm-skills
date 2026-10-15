---
name: openllmetry
description: OpenLLMetry (Traceloop), Apache-2.0 OpenTelemetry instrumentation for LLM apps (traceloop-sdk, Traceloop.init, TRACELOOP_* variables). Use to trace OpenAI, Anthropic, LiteLLM, Ollama, LangChain calls into Phoenix, Langfuse, MLflow, Jaeger or a Collector, keep prompts out of spans, redact, sample, or fix no spans, 404 on /v1/metrics, Missing Traceloop API key. Not for choosing a tracing stack (llm-observability).
license: MIT
compatibility: Commands assume bash, curl and a Python 3.10+ app environment (Node and other languages covered briefly). Installing packages into the app, pointing it at a backend and enabling content capture need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# OpenLLMetry

A traced LLM application: OpenLLMetry (`traceloop/openllmetry`, PyPI `traceloop-sdk`, plus one `opentelemetry-instrumentation-<lib>` package per provider, framework and vector DB) turns calls to OpenAI-style clients, LiteLLM, Ollama, LangChain and others into standard OpenTelemetry spans that go to any OTLP backend.

**Scope:** this instrumentation library only: install, point at a backend, privacy switches, sampling, update, troubleshoot. It is not a backend; the Traceloop cloud platform is out of scope. Choosing a backend or comparing libraries belongs to `llm-observability`; running a backend belongs to `arize-phoenix`, `langfuse` or `mlflow-tracing`; the attribute schema belongs to `opentelemetry-genai`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
pip list 2>/dev/null | grep -iE '^(traceloop-sdk|opentelemetry-(instrumentation|sdk|exporter|semantic))' || true
env | cut -d= -f1 | grep -E '^(TRACELOOP|OTEL_|OPENINFERENCE)' || true       # names only
grep -rIl --include='*.py' -E 'Traceloop\.init|traceloop\.sdk' . 2>/dev/null | head   # existing init sites
curl -fsS https://pypi.org/pypi/traceloop-sdk/json | jq -r .info.version             # newest release
```

Ask only what discovery cannot show: which backend receives spans and whether it takes HTTP or gRPC, which libraries the app calls (OpenAI client against vLLM, LiteLLM, LangChain), whether prompts may be stored, whether another OTel SDK or instrumentation already runs in the process.

## Decision flow

1. **App in Python, any OTLP/HTTP backend:** `pip install traceloop-sdk`, `Traceloop.init(...)`. -> `references/install-and-config.md`
2. **App already runs an OpenTelemetry SDK:** use the instrumentation packages directly, no SDK. -> `references/install-and-config.md`
3. **Node, Go or Ruby:** separate SDKs with similar options. -> `references/install-and-config.md`
4. **Which backend settings:** Phoenix, Langfuse, MLflow or a Collector. -> `references/backends.md`
5. **Self-hosted engines and gateways:** OpenAI-compatible endpoints, LiteLLM, Ollama. -> `references/self-hosted-and-gateways.md`
6. **Content, redaction, retention:** decide before real traffic. -> `references/privacy.md`
7. **New release or a switch from the legacy attributes:** -> `references/updating.md`
8. **No spans or odd spans:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the app or its environment.** New dependencies, `Traceloop.init`, new env vars and content capture need approval and an undo path (remove the init call and the variables).
- **Secrets never touch output.** Backend keys go in `TRACELOOP_HEADERS` or `TRACELOOP_API_KEY` from a `0600` env file; never log them or put them in code.
- **Content is captured by default.** `TRACELOOP_TRACE_CONTENT` defaults to `true`: prompts, completions and embeddings land on spans. Decide per environment; set `false` for anything real.
- **Turn metrics off for trace-only backends.** `TRACELOOP_METRICS_ENABLED` defaults to `true` and exports metrics to the same base URL; set `false` unless the backend takes OTLP metrics.
- **Set the base URL without `/v1/traces`.** An `http(s)://` base URL means OTLP/HTTP and the SDK appends `/v1/traces`; anything else means gRPC. Initialize before importing the LLM libraries (required in JS, safest in Python).
- **One layer owns LLM spans.** If a gateway already traces the call, do not instrument the app for the same call, or it appears twice.
- **Verify upstream.** Variables and defaults come from traceloop.com/docs/openllmetry (append `.md`) and the repository at use time; pin the SDK version.

## Workflows

### First trace

- [ ] Install `traceloop-sdk` in the app environment -> `references/install-and-config.md`.
- [ ] Export the backend variables from a `0600` file -> `references/backends.md`; set `TRACELOOP_METRICS_ENABLED=false` and, for non-production, `TRACELOOP_TRACE_CONTENT=false`.
- [ ] Call `Traceloop.init(app_name="my-app", disable_batch=True)` once at startup, make one LLM call, find the span in the backend.
- [ ] Switch to batching (drop `disable_batch`) for production.

### Self-hosted model or gateway

- [ ] Client app against vLLM or another OpenAI-compatible server: the OpenAI instrumentation already traces it -> `references/self-hosted-and-gateways.md`.
- [ ] Gateway tracing, engine spans and `traceparent` propagation -> same reference.

### Privacy

- [ ] Fill the decision record and run the canary test -> `references/privacy.md`.
- [ ] Redact with `span_postprocess_callback` or a Collector if content must be kept but cleaned.

### Update

- [ ] Pin the version, read the release notes, rerun the canary -> `references/updating.md`.

## Reference index

| File                                     | Read when                                                                  |
| ---------------------------------------- | -------------------------------------------------------------------------- |
| `references/install-and-config.md`       | Install, `Traceloop.init` options, env vars, SDK-less use, other languages |
| `references/backends.md`                 | Exact settings for Phoenix, Langfuse, MLflow, a Collector, Jaeger          |
| `references/self-hosted-and-gateways.md` | vLLM, Ollama, LiteLLM, propagation, avoiding double spans                  |
| `references/privacy.md`                  | Content switches, redaction, sampling, image uploads, canary test          |
| `references/updating.md`                 | Releases, pinning, attribute-format changes                                |
| `references/troubleshooting.md`          | Symptom to cause to fix                                                    |

Script: `scripts/check.sh` (read-only: SDK version, which `TRACELOOP_*` and `OTEL_*` variables are set by name, backend reachability).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-observability`: choosing and combining tracing backends.
- `opentelemetry-genai`: GenAI semantic conventions, OTel-native instrumentation and Collector config.
- `arize-phoenix`, `langfuse`, `mlflow-tracing`: backends that receive these spans.
- `litellm`: the gateway with its own callbacks.
- `vllm`: an OpenAI-compatible engine that also emits spans.
