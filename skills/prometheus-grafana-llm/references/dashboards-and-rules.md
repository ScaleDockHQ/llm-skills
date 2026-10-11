# Dashboards and recording rules

> Verified against Grafana v13.2.3 provisioning and Prometheus v3.15.0 recording-rule docs, 2026-10-11

## Grafana data source and dashboards

Provision the data source from `assets/grafana-datasource.yml` (mounted in `/etc/grafana/provisioning/datasources/`). Import dashboards through Dashboards -> New -> Import or provision JSON files:

- vLLM: `examples/observability/prometheus_grafana/grafana.json` and `examples/observability/dashboards/grafana/*.json` in the vLLM repo.
- SGLang: `examples/monitoring/grafana/dashboards/json/sglang-dashboard.json`.
- llama-swap: `docs/grafana/example-dashboard.json`.
- DCGM exporter: grafana.com dashboard 12239.
- LiteLLM: community dashboards linked from its docs; check that names match (`_total` suffixes).

Grafana secrets use `GF_<SECTION>_<KEY>__FILE` pointing at a mounted file (`GF_SECURITY_ADMIN_PASSWORD__FILE`), as in the Compose asset. Disable sign-up, put TLS and auth in front, and never share the admin account for viewers.

## Gateway overview, per model

Requests/s, error ratio, p50 and p95 end-to-end latency, p95 TTFT for streaming, output tokens/s, spend/hour. Engine dashboards then answer why: queue depth, KV-cache usage, preemptions, prefill versus decode time.

## Recording rules

Recording rules keep dashboards fast and give alerts stable names.

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

Naming convention: `level:metric:operations`. Validate with `promtool check rules`.

## Pitfalls

- `histogram_quantile` without `sum by (le, ...)` returns per-series quantiles.
- A `rate()` window under 4x the scrape interval gives gaps.
- Dashboard variables on `model_name` break when a label differs between engines; add a common `model` label in scrape configs.

## Official links

- Recording rules: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/
- Histograms: https://prometheus.io/docs/practices/histograms/
- Grafana provisioning: https://grafana.com/docs/grafana/latest/administration/provisioning/
