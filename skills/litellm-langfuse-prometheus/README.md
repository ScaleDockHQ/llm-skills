# LiteLLM + Langfuse + Prometheus

A stack skill that wires one LiteLLM gateway to Langfuse for per-request traces and cost, and to Prometheus and Grafana for health, latency and spend metrics. It covers the callbacks and environment, the dedicated metrics port and scrape job, privacy and retention choices, and an end-to-end verification ladder.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill litellm-langfuse-prometheus
```

## Rules

- **Ask before changing the system.** Config edits and restarts need approval.
- **Set `LITELLM_OTEL_V2=true`** for the `langfuse_otel` preset.
- **Keep the metrics port private.** The dedicated listener has no key check.
- **Decide on message logging first.** Traces carry prompts unless you turn it off.

## References

- [`references/langfuse-side.md`](references/langfuse-side.md): callbacks, env names, per-team projects.
- [`references/prometheus-side.md`](references/prometheus-side.md): metrics port, scrape job, queries, label limits.
- [`references/privacy-and-cost.md`](references/privacy-and-cost.md): content logging, retention, cost views.
- [`references/verify-and-troubleshoot.md`](references/verify-and-troubleshoot.md): test request, ladder, symptoms.

## Companion skills

- `litellm`, `langfuse`, `llm-observability`, `llm-gateway`.

## License

MIT
