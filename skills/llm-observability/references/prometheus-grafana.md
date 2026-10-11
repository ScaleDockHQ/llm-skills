# Prometheus and Grafana for LLM serving

> Verified against Prometheus v3.15.0 (configuration docs and `prometheus --help`), Grafana v13.2.3 docs, llama.cpp master b11556 default port, llama-swap v263 auth middleware, 2026-10-11

## What it is and when to choose it

Prometheus scrapes `/metrics` from engines, the gateway, and GPU exporters, stores time series, and evaluates alert rules. Grafana draws dashboards from it. This is the default metrics stack for self-hosted LLM serving: every engine in this skill speaks Prometheus format. Choose a managed Prometheus-compatible service (Grafana Cloud, Amazon Managed Prometheus, etc.) if you don't want to operate storage; the scrape configs and queries stay the same.

## Install

Docker on a monitoring host (node-b here):

```bash
mkdir -p ~/monitoring && cd ~/monitoring
cp /path/to/skill/assets/prometheus.yml ./prometheus.yml   # then edit targets
cp /path/to/skill/assets/alert-rules.yml ./alert-rules.yml

docker run -d --name prometheus -p 9090:9090 \
  -v "$PWD/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  -v "$PWD/alert-rules.yml:/etc/prometheus/alert-rules.yml:ro" \
  -v "$PWD/secrets:/etc/prometheus/secrets:ro" \
  -v prometheus-data:/prometheus \
  prom/prometheus:<tag> \
  --config.file=/etc/prometheus/prometheus.yml --web.enable-lifecycle

docker run -d --name grafana -p 3000:3000 -v grafana-data:/var/lib/grafana grafana/grafana:<tag>
```

Pin `<tag>` to a release. `--web.enable-lifecycle` allows `curl -X POST http://localhost:9090/-/reload`; only enable it when 9090 is not reachable by untrusted clients.

Validate before (re)loading, using the same image if `promtool` is not installed:

```bash
docker run --rm --entrypoint promtool -v "$PWD:/w:ro" -w /w prom/prometheus:<tag> check config prometheus.yml
docker run --rm --entrypoint promtool -v "$PWD:/w:ro" -w /w prom/prometheus:<tag> check rules alert-rules.yml
```

`check config` also checks referenced rule files and credential files exist, so run it where those paths resolve.

## Minimal working config

See `assets/prometheus.yml` for the full version. The core pattern, one job per component type with a `model` / `backend` label per target:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - alert-rules.yml

scrape_configs:
  - job_name: vllm
    static_configs:
      - targets: ["node-a:8000"]
        labels: { backend: vllm, model: "<served-model-name>" }

  - job_name: litellm
    authorization:
      type: Bearer
      credentials_file: /etc/prometheus/secrets/litellm-metrics-key
    static_configs:
      - targets: ["llm.example.com:4000"]
        labels: { backend: litellm }

  - job_name: llamacpp-router
    metrics_path: /metrics
    params:
      model: ["<model-id>"] # router mode needs ?model=
    static_configs:
      - targets: ["node-a:9931"] # llama-server default since b11521; 8080 on older builds
        labels: { backend: llamacpp, model: "<model-id>" }
```

Write the key file without echoing it to the terminal or shell history:

```bash
( umask 077; mkdir -p secrets
  read -rs -p "LiteLLM metrics key: " k && printf '%s' "$k" > secrets/litellm-metrics-key; echo )
```

The `prom/prometheus` image runs as `nobody` (uid 65534), so a mode-700 directory and mode-600 file owned by you are unreadable inside the container; on Linux give both to that uid (`sudo chown -R 65534 secrets`). Use a dedicated low-privilege LiteLLM key for scraping, not the master key.

Retention (Prometheus 3.x prefers the config file over the deprecated `--storage.tsdb.retention.*` flags; the default is 15 days):

```yaml
storage:
  tsdb:
    retention:
      time: 30d
      size: 50GB
```

## How it plugs into the stack

| Target        | Port                      | Path                                  | Auth                                                                                |
| ------------- | ------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------- |
| vLLM          | 8000                      | `/metrics`                            | none                                                                                |
| SGLang        | 30000                     | `/metrics`                            | none (needs `--enable-metrics`)                                                     |
| llama.cpp     | 9931 (8080 before b11521) | `/metrics` (`?model=` in router mode) | Bearer key if `--api-key` is set                                                    |
| llama-swap    | 8080                      | `/metrics`                            | Bearer key if `apiKeys` is set                                                      |
| LiteLLM proxy | 4000                      | `/metrics`                            | key required by default; or a dedicated unauthenticated `--prometheus_metrics_port` |
| DCGM exporter | 9400                      | `/metrics`                            | none, or `--web-config-file`                                                        |
| Prometheus    | 9090                      | UI, `/api/v1/*`                       | none by default (`--web.config.file` for TLS/basic auth)                            |
| Grafana       | 3000                      | UI                                    | Grafana users                                                                       |

Grafana data source (provisioning file in `/etc/grafana/provisioning/datasources/`):

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

Dashboards worth importing (Dashboards → New → Import, paste JSON or ID):

- vLLM: `examples/observability/prometheus_grafana/grafana.json` and `examples/observability/dashboards/grafana/*.json` in the vLLM repo.
- SGLang: `examples/monitoring/grafana/dashboards/json/sglang-dashboard.json`.
- llama-swap: `docs/grafana/example-dashboard.json`.
- DCGM exporter: grafana.com dashboard 12239.
- LiteLLM: the LiteLLM docs link community dashboards; check they match your metric names (counter `_total` suffixes).

## Operating

Recording rules keep dashboards fast and give alerts stable names. Add to a rule file:

```yaml
groups:
  - name: llm-recording
    interval: 30s
    rules:
      - record: model:vllm_ttft_seconds:p95_5m
        expr: histogram_quantile(0.95, sum by (model_name, le) (rate(vllm:time_to_first_token_seconds_bucket[5m])))
      - record: model:vllm_generation_tokens:rate5m
        expr: sum by (model_name) (rate(vllm:generation_tokens_total[5m]))
      - record: model:litellm_request_latency_seconds:p95_5m
        expr: histogram_quantile(0.95, sum by (model_group, le) (rate(litellm_request_total_latency_metric_bucket[5m])))
```

A gateway overview dashboard should answer, per model: requests/s, error ratio, p50/p95 end-to-end latency, p95 TTFT (streaming), output tokens/s, spend/hour. Engine dashboards then answer why: queue depth, KV-cache usage, preemptions, prefill vs decode time.

Health checks:

```bash
curl -fsS http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health!="up") | "\(.labels.job) \(.scrapeUrl) \(.lastError)"'
curl -fsS 'http://localhost:9090/api/v1/query' --data-urlencode 'query=up' | jq -r '.data.result[] | "\(.metric.job) \(.metric.instance) \(.value[1])"'
```

## Tuning knobs worth knowing

- `scrape_interval`: 15 s is a good default; histograms at 5 s get expensive.
- `scrape_timeout`: must be ≤ interval; raise it for a slow LiteLLM `/metrics` with many series.
- `metric_relabel_configs` with `action: labeldrop`: drop high-cardinality labels at ingest (e.g. LiteLLM `hashed_api_key`, `user_agent`) when you can't change the exporter.
- `storage.tsdb.retention.time` / `.size`: retention is a decision; see `privacy.md` for label content.

## Known pitfalls

- **`histogram_quantile` without `sum by (le, ...)`** gives per-series quantiles; averaging quantiles across instances is wrong.
- **`rate()` window shorter than 4× scrape interval** produces gaps.
- **LiteLLM `/metrics` 401**: since v1.85.0 it needs a key; scrape with `authorization` + `credentials_file`, or use the dedicated metrics port on a private network.
- **Multi-worker LiteLLM** without `PROMETHEUS_MULTIPROC_DIR` reports per-worker values that jump between scrapes.
- **Cardinality blowups** from per-user/per-key labels on the gateway; check `prometheus_tsdb_head_series` after enabling.
- **Secrets in `prometheus.yml`**: use `credentials_file`, not inline `credentials`, and keep the file out of git.

## Official links

- Prometheus configuration: https://prometheus.io/docs/prometheus/latest/configuration/configuration/
- Recording rules: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/
- Querying histograms: https://prometheus.io/docs/practices/histograms/
- Storage and retention: https://prometheus.io/docs/prometheus/latest/storage/
- Grafana provisioning: https://grafana.com/docs/grafana/latest/administration/provisioning/
- Grafana Prometheus data source: https://grafana.com/docs/grafana/latest/datasources/prometheus/
