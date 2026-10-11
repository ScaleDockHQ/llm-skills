# Prometheus and Grafana for LLM

An agent skill for running Prometheus, Alertmanager and Grafana for self-hosted LLM serving. It covers a hardened Compose stack, scrape configs for vLLM, llama.cpp, SGLang, llama-swap, LiteLLM and DCGM, recording rules and dashboards, a validated alert set with Alertmanager routing, remote_write and Alloy for managed backends, label privacy, updates and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill prometheus-grafana-llm
```

## Rules

- **Ask before changing the system.** Installs, exposure, retention and alert routing need approval.
- **Secrets never touch output.** Keys and webhook URLs in `0600` files via `credentials_file` or `url_file`.
- **Metrics on, content off.** Drop PII labels at the gateway and at scrape.
- **Pin images; validate before reload** with promtool and amtool.
- **Page on symptoms, warn on causes.**

## References

- [`references/install.md`](references/install.md): Compose stack, host exporters, retention.
- [`references/scrape-engines.md`](references/scrape-engines.md): per-engine flags, ports, auth, Ollama gap.
- [`references/dashboards-and-rules.md`](references/dashboards-and-rules.md): Grafana provisioning, recording rules.
- [`references/alerting.md`](references/alerting.md): rules and Alertmanager routing.
- [`references/remote-write.md`](references/remote-write.md): managed backends, Alloy.
- [`references/privacy.md`](references/privacy.md): labels, exposure, retention.
- [`references/updating.md`](references/updating.md): releases and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

**Templates and scripts:** [`assets/docker-compose.yaml`](assets/docker-compose.yaml), [`assets/prometheus.yml`](assets/prometheus.yml), [`assets/alert-rules.yml`](assets/alert-rules.yml), [`assets/alertmanager.yml`](assets/alertmanager.yml), [`assets/grafana-datasource.yml`](assets/grafana-datasource.yml), [`scripts/check.sh`](scripts/check.sh).

## Upstream credits

- [Prometheus](https://github.com/prometheus/prometheus), [Alertmanager](https://github.com/prometheus/alertmanager) (Apache-2.0), [Grafana](https://github.com/grafana/grafana) (AGPL-3.0).

## Companion skills

- `dcgm-exporter`: GPU telemetry.
- `sparkdash`: DGX Spark dashboard with a Prometheus export.
- `llm-observability`: tracing, spend and choosing a stack.
- `litellm`: the gateway whose metrics are scraped.

## License

MIT
