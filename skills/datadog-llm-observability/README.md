# Datadog LLM Observability

An agent skill for Datadog Agent Observability (formerly LLM Observability). It covers instrumenting apps with ddtrace and dd-trace, tracing self-hosted endpoints and LiteLLM (vLLM, llama.cpp, SGLang, Ollama), OTLP, span-processor redaction, manual cost for local models, `ml_obs.*` monitors, updates and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill datadog-llm-observability
```

## Rules

- **Ask before sending data off the machine.** Datadog is hosted and paid.
- **Secrets never touch output.** `DD_API_KEY` in `0600` files only.
- **Content capture is a decision.** Span processors or Collector stripping first.
- **Match `DD_SITE`;** OTLP is HTTP only with `dd-otlp-source=llmobs`.
- **Local models need manual cost.**
- **Pin the tracer and flush short-lived jobs.**

## References

- [`references/setup-and-sdks.md`](references/setup-and-sdks.md): transports, install, variables.
- [`references/otlp-and-gateways.md`](references/otlp-and-gateways.md): LiteLLM, OTLP, HTTP API.
- [`references/privacy-and-governance.md`](references/privacy-and-governance.md): redaction, access, retention.
- [`references/cost-and-alerting.md`](references/cost-and-alerting.md): cost, metrics, monitors.
- [`references/updating-and-troubleshooting.md`](references/updating-and-troubleshooting.md): updates and fixes.

**Templates and scripts:** [`assets/otel-collector.yaml`](assets/otel-collector.yaml), [`assets/litellm-proxy-datadog.env.example`](assets/litellm-proxy-datadog.env.example), [`scripts/check.sh`](scripts/check.sh).

## Upstream credits

- [dd-trace-py](https://github.com/DataDog/dd-trace-py) and [dd-trace-js](https://github.com/DataDog/dd-trace-js) by Datadog (BSD-3-Clause).

## Companion skills

- `llm-observability`: choosing a stack.
- `litellm`: the proxy.
- `prometheus-grafana-llm`: engine metrics.

## License

MIT
