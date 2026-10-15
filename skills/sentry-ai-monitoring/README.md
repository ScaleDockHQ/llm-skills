# Sentry AI monitoring

An agent skill for Sentry Agent Tracing (formerly AI Insights). It covers tracing apps that call self-hosted endpoints and LiteLLM (vLLM, llama.cpp, SGLang, Ollama) with `sentry-sdk`, manual `gen_ai` spans, direct OTLP and a Collector, privacy and scrubbing, head-based sampling, custom cost for local models, self-hosted Sentry, updates and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill sentry-ai-monitoring
```

## Rules

- **Ask before sending data off the machine.** Sentry SaaS is third-party hosting.
- **Secrets never touch output.** DSN and tokens in `0600` files only.
- **Content is off by default;** `gen_ai.*` content attributes need scrubbing rules.
- **Sample agent runs at 100 percent.**
- **Local models need custom cost.**
- **OTLP is open beta;** span events are dropped.
- **Pin SDKs.**

## References

- [`references/setup-and-sdks.md`](references/setup-and-sdks.md): hosting, SDK setup, manual spans.
- [`references/otlp-and-gateways.md`](references/otlp-and-gateways.md): OTLP, Collector, LiteLLM.
- [`references/privacy-and-sampling.md`](references/privacy-and-sampling.md): privacy, scrubbing, sampling.
- [`references/cost-and-alerting.md`](references/cost-and-alerting.md): cost, dashboards, alerts.
- [`references/updating-and-troubleshooting.md`](references/updating-and-troubleshooting.md): updates and fixes.

**Templates and scripts:** [`assets/otel-collector.yaml`](assets/otel-collector.yaml), [`scripts/check.sh`](scripts/check.sh).

## Upstream credits

- [Sentry](https://github.com/getsentry/sentry) (FSL) and [sentry-python](https://github.com/getsentry/sentry-python) (MIT).

## Companion skills

- `llm-observability`: choosing a stack.
- `litellm`: the proxy.
- `prometheus-grafana-llm`: engine metrics.

## License

MIT
