---
name: datadog-llm-observability
description: "Datadog Agent Observability (formerly LLM Observability): traces, cost, evaluations and ml_obs metrics for LLM apps. Use to instrument Python or Node with ddtrace and dd-trace, trace vLLM, llama.cpp, SGLang, Ollama or a LiteLLM proxy, send OTLP, redact with span processors, price local models, alert with monitors, or fix no spans, 403 and missing cost. Not for choosing a stack (llm-observability)."
license: MIT
compatibility: Python 3.8+ or Node 18+ with pip or npm, bash, curl and jq; optional Docker for an OpenTelemetry Collector. Needs a Datadog account and API key on a supported site. Sending prompts to a hosted service and installs need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Datadog Agent Observability

A working Datadog Agent Observability setup that traces LLM calls from self-hosted endpoints and gateways with cost and tokens, keeps prompt content under an explicit privacy decision, and alerts through ordinary Datadog monitors.

**Scope:** this one product: tracer install, agentless or Agent mode, auto-instrumentation, OTLP, span processors, cost for local models, `ml_obs.*` monitors, update, troubleshoot. Choosing between Datadog, Langfuse, PostHog and others is `llm-observability`; engine metrics are `prometheus-grafana-llm`; the LiteLLM proxy is `litellm`; eval method is `llm-evals`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
pip show ddtrace litellm 2>/dev/null | grep -E '^(Name|Version)'
env | cut -d= -f1 | grep -E '^(DD_|OTEL_EXPORTER)' || true          # names only
command -v datadog-agent && datadog-agent version | head -1          # Agent present?
curl -s -o /dev/null -m 3 -w 'trace port 8126 HTTP %{http_code}\n' http://127.0.0.1:8126/info || true
docker ps --format '{{.Names}}\t{{.Image}}' | grep -Ei 'datadog|otel|litellm|vllm' || true
curl -fsS https://pypi.org/pypi/ddtrace/json | jq -r .info.version   # newest tracer
```

Ask only what discovery cannot show: Datadog site, Agent or agentless, which clients or gateway send calls, whether prompts may leave the network.

## Decision flow

1. **Prompts may not leave your network:** Datadog cannot be self-hosted; pick another backend (`langfuse`), or send metadata only. -> `references/privacy-and-governance.md`
2. **Python or Node app:** `ddtrace-run` or `dd-trace` with `DD_LLMOBS_ENABLED`. -> `references/setup-and-sdks.md`
3. **LiteLLM proxy or other gateway:** run it under `ddtrace-run`, or OTel. -> `references/otlp-and-gateways.md`
4. **Other language or existing OTel:** OTLP over HTTP with `dd-otlp-source=llmobs`. -> `references/otlp-and-gateways.md`
5. **Cost empty for a local model, or alerts:** -> `references/cost-and-alerting.md`
6. **Update or an error:** -> `references/updating-and-troubleshooting.md`

## Rules

- **Ask before sending data off the machine.** Datadog is third-party hosting and a paid product; get approval, the site, and decide content capture first.
- **Secrets never touch output.** `DD_API_KEY` lives in a `0600` env file or the secret store; check presence by name only.
- **Content capture is a decision.** Use a span processor or Collector stripping before real traffic; Sensitive Data Scanner is a second layer after egress.
- **Match the site.** `DD_SITE` must equal the org's site; keys do not cross sites. The product is unavailable on the gov sites named in the docs.
- **OTLP is HTTP only** (`http/protobuf` or json) with `dd-api-key` and `dd-otlp-source=llmobs`; the intake endpoint is site specific, copy it from the docs.
- **Local models need manual cost.** Supply `input_cost` and `output_cost`, or cost stays empty.
- **Flush short-lived processes** and pin tracer versions.
- **Verify upstream.** The product was renamed; read the docs and PyPI at use time.

## Workflows

### First trace

- [ ] `pip install ddtrace` (pin); env from a file; `ddtrace-run <app>` -> `references/setup-and-sdks.md`.
- [ ] Make one call to the local endpoint; open Agent Observability; confirm model, tokens, latency.

### Gateway

- [ ] LiteLLM under `ddtrace-run` (`assets/litellm-proxy-datadog.env.example`), or Collector (`assets/otel-collector.yaml`) -> `references/otlp-and-gateways.md`.

### Privacy

- [ ] Register a span processor or strip at the Collector; canary string must not appear -> `references/privacy-and-governance.md`.

### Cost and alerts

- [ ] Annotate cost for local models; metric monitors on `ml_obs.*` -> `references/cost-and-alerting.md`.

## Reference index

| File                                         | Read when                                                                               |
| -------------------------------------------- | --------------------------------------------------------------------------------------- |
| `references/setup-and-sdks.md`               | Transports, ddtrace and dd-trace install, variables, vLLM integration, gateways, Lapdog |
| `references/otlp-and-gateways.md`            | LiteLLM proxy, OTLP headers, GenAI conventions, HTTP API                                |
| `references/privacy-and-governance.md`       | Span processors, Sensitive Data Scanner, access control, retention                      |
| `references/cost-and-alerting.md`            | Manual cost, cost tags, `ml_obs.*` metrics, monitors, evaluations                       |
| `references/updating-and-troubleshooting.md` | Version minimums, symptom to cause to fix, teardown                                     |

Templates: `assets/otel-collector.yaml`, `assets/litellm-proxy-datadog.env.example`. Script: `scripts/check.sh` (names and reachability only).

## Companion skills

- `llm-observability`: choosing a stack. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
- `litellm`: the proxy. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `prometheus-grafana-llm`: engine metrics and alerts. Install: `npx skills add ScaleDockHQ/llm-skills --skill prometheus-grafana-llm`.
- `llm-evals`: evaluation method. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
