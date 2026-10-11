---
name: prometheus-grafana-llm
description: Prometheus, Alertmanager and Grafana for LLM serving metrics. Use to install the stack with Docker Compose, scrape vLLM, llama.cpp, SGLang, llama-swap, LiteLLM and DCGM, add recording rules, dashboards and alerts, route pages, remote_write to Grafana Cloud, set retention, update, or fix target down, 401 on /metrics, empty histogram_quantile, cardinality. Not for tracing or spend (llm-observability, langfuse).
license: MIT
compatibility: Commands assume bash, curl, jq and Docker Compose; promtool and amtool run from the official images. Installs, exposure, retention changes and alert routing need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Prometheus and Grafana for LLM

A working metrics stack for self-hosted LLM serving: Prometheus scraping every engine, the gateway and the GPU exporter, Grafana dashboards, and Alertmanager routing alerts that page on what users feel and warn on what explains it.

**Scope:** this stack only: install, scrape configs per engine, recording rules, alerts, dashboards, retention, remote_write, update, troubleshoot. NVIDIA GPU telemetry is `dcgm-exporter`. Traces, prompts, spend and gateway logging are `llm-observability` and `langfuse`. The sparkDash dashboard is `sparkdash`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | grep -Ei 'prometheus|grafana|alertmanager|node-exporter|dcgm' || true
systemctl list-units --no-legend 'prometheus*' 'grafana*' 'alertmanager*' 2>/dev/null
curl -fsS -m 3 http://127.0.0.1:9090/-/ready; curl -fsS -m 3 http://127.0.0.1:9090/api/v1/status/buildinfo | jq -r .data.version
curl -fsS -m 3 http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job)\t\(.health)\t\(.scrapeUrl)"'
for p in 8000 30000 9931 8080 4000 9400 11434; do curl -s -o /dev/null -m 2 -w "$p /metrics %{http_code}\n" http://127.0.0.1:$p/metrics; done
gh api repos/prometheus/prometheus/releases/latest --jq .tag_name
```

Ask only what discovery cannot show: which engines and gateway run where, whether Prometheus already exists, who receives alerts, retention needs, and whether a managed backend (Grafana Cloud) is acceptable.

## Decision flow

1. **No Prometheus yet, one monitoring host:** Compose stack from `assets/`. -> `references/install.md`
2. **Managed backend wanted:** keep scrape configs, add `remote_write` or Alloy. -> `references/remote-write.md`
3. **Targets to add:** engine flags, ports, auth. -> `references/scrape-engines.md`
4. **Dashboards and recording rules:** -> `references/dashboards-and-rules.md`
5. **Paging:** -> `references/alerting.md`
6. **Content or PII in labels, who can read `/metrics`:** -> `references/privacy.md`
7. **New release or retention change:** -> `references/updating.md`
8. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, exposed ports, retention, alert routes and reloads need approval and an undo path (config backup).
- **Secrets never touch output.** Scrape keys and webhook URLs live in `0600` files used via `credentials_file`, `url_file` or env; never inline in `prometheus.yml`.
- **Metrics on, content off.** Metrics carry label values, not prompts, but gateway labels can hold emails and key aliases; drop them.
- **Pin images.** Exact tags (`prom/prometheus:v3.15.0`), not `latest`; keep `--web.enable-lifecycle` and 9090 private.
- **Page on symptoms, warn on causes.** Every alert has an owner and a runbook URL.
- **Aggregate before quantiles.** `histogram_quantile` over `sum by (le, ...)`, never average quantiles.
- **Verify live names.** Metric names drift; check `/metrics` after every engine upgrade.
- **Validate before reload.** `promtool check config` and `check rules`, `amtool check-config`.

## Workflows

### Install and first scrape

- [ ] Copy `assets/` to `~/monitoring`, set targets, create `secrets/grafana-admin-password` (`0600`) -> `references/install.md`.
- [ ] Validate with promtool and amtool from the images, `docker compose up -d`.
- [ ] `scripts/check.sh` shows every target `up`; Grafana at `127.0.0.1:3000` has the provisioned data source.

### Add an engine or gateway

- [ ] Enable metrics with the engine flag, confirm `curl .../metrics` -> `references/scrape-engines.md`.
- [ ] Add a job with `backend` and `model` labels; use `credentials_file` where auth applies.
- [ ] Reload, run `scripts/check.sh`, compare names against dashboards.

### Alerts

- [ ] Start from `assets/alert-rules.yml`; set thresholds from SLOs -> `references/alerting.md`.
- [ ] Route `severity=page` to a pager, `warning` to chat; test one alert end to end.

### Update

- [ ] Back up config and volumes, bump pinned tags, `docker compose pull && up -d` -> `references/updating.md`.

## Reference index

| File                                 | Read when                                                                  |
| ------------------------------------ | -------------------------------------------------------------------------- |
| `references/install.md`              | Compose stack, bare install, Kubernetes pointer, sizing                    |
| `references/scrape-engines.md`       | Per-engine flags, ports, metrics, auth, Ollama gap                         |
| `references/dashboards-and-rules.md` | Grafana provisioning, dashboards to import, recording rules                |
| `references/alerting.md`             | Rules, Alertmanager routing, inhibition, silences, testing                 |
| `references/remote-write.md`         | Grafana Cloud or another long-term store, Alloy, sending from remote hosts |
| `references/privacy.md`              | Labels, exposure, retention, access                                        |
| `references/updating.md`             | Releases, Prometheus 3 notes, backup, rollback                             |
| `references/troubleshooting.md`      | Symptom to cause to fix                                                    |

Templates: `assets/docker-compose.yaml`, `assets/prometheus.yml`, `assets/alert-rules.yml`, `assets/alertmanager.yml`, `assets/grafana-datasource.yml`. Script: `scripts/check.sh` (read-only health).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `dcgm-exporter`: GPU telemetry that Prometheus scrapes.
- `sparkdash`: glanceable DGX Spark dashboard with a Prometheus export.
- `llm-observability`: tracing, gateway logging, spend and choosing a stack.
- `litellm`: the gateway whose `/metrics` this scrapes.
- `vllm`, `sglang`, `llama-cpp`: the engines being scraped.
