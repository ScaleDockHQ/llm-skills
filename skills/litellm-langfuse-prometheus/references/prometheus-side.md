# Prometheus side: scraping the gateway

> Verified against LiteLLM v1.105.0 (docs: proxy/prometheus) and Prometheus v3.15.0 (release 2026-09-25), 2026-10-11

Enable the callback (it is in the open-source proxy):

```yaml
litellm_settings:
  callbacks: ["prometheus", "langfuse_otel"]
```

## Where to scrape

1. **Proxy port.** `GET /metrics` on 4000, using a key (`Authorization: Bearer ...`). `general_settings.require_auth_for_metrics_endpoint` controls whether this route requires auth; check your version's default in the docs. Multiple workers need `PROMETHEUS_MULTIPROC_DIR` pointing at an existing writable directory.
2. **Dedicated metrics port (v1.101.0 and later).** Same metric set from its own process, so scrapes do not use request-serving workers. Configure `--prometheus_metrics_port 4001` or `PROMETHEUS_METRICS_PORT=4001`. The proxy-port `/metrics` route stays for backward compatibility, so migrate targets without downtime. It binds to the proxy `--host`.

```bash
litellm --config config.yaml --num_workers 4 --prometheus_metrics_port 4001
```

With the Docker image, the same flag goes in the compose `command:` list; expose 4001 only on the internal Docker network (no `ports:` entry), and attach Prometheus to that network.

**The dedicated listener does not use virtual-key authentication.** Allow only your Prometheus network and never publish it through a public ingress.

```bash
curl -fsS http://litellm:4001/health          # {"status":"healthy", ...}
curl -fsS http://litellm:4001/metrics/ | head
```

(Run from a container on the same network; `/health/readiness` on 4000 remains the proxy readiness check.)

## Scrape job

Dedicated port, no key needed:

```yaml
scrape_configs:
  - job_name: litellm
    static_configs:
      - targets: ["litellm:4001"]
```

Proxy port with a key file (low-privilege key, not the master key; create the file without echoing it):

```yaml
- job_name: litellm
  metrics_path: /metrics
  authorization:
    type: Bearer
    credentials_file: /etc/prometheus/secrets/litellm-metrics-key
  static_configs:
    - targets: ["litellm:4000"]
```

Prometheus install, secret file ownership, retention and alert rules: `llm-observability` skill, `prometheus-grafana.md`. Validate with `promtool check config` before reload.

## Metrics worth charting

Names from the LiteLLM Prometheus page (a metric appears only after the first matching request):

| Question                  | Metric                                                                                                                                                       |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Request rate by model     | `litellm_proxy_total_requests_metric`                                                                                                                        |
| Errors the client saw     | `litellm_proxy_failed_requests_metric`                                                                                                                       |
| End-to-end latency SLO    | `litellm_request_total_latency_metric` (histogram)                                                                                                           |
| Provider time, TTFT       | `litellm_llm_api_latency_metric`, `litellm_llm_api_time_to_first_token_metric`                                                                               |
| Gateway overhead          | `litellm_overhead_latency_metric`                                                                                                                            |
| Spend and tokens          | `litellm_spend_metric`, `litellm_input_tokens_metric`, `litellm_output_tokens_metric`                                                                        |
| Backend health, fallbacks | `litellm_deployment_state`, `litellm_deployment_failure_responses`, `litellm_deployment_successful_fallbacks`                                                |
| Budgets                   | `litellm_remaining_api_key_budget_metric`, `litellm_remaining_team_budget_metric` (set `prometheus_initialize_budget_metrics: true` to seed them at startup) |
| Callbacks failing         | `litellm_callback_logging_failures_metric`                                                                                                                   |

`litellm_requests_metric` is deprecated; use `litellm_proxy_total_requests_metric`. Counters may carry a `_total` suffix in the exposition, so check `curl .../metrics | grep '^litellm_proxy_total'` before writing queries.

```promql
# p95 end-to-end latency (from the LiteLLM docs)
histogram_quantile(0.95, sum by (le) (rate(litellm_request_total_latency_metric_bucket[5m])))
# per model group
histogram_quantile(0.95, sum by (model_group, le) (rate(litellm_request_total_latency_metric_bucket[5m])))
```

Use total latency for SLOs; if it rises, compare provider latency against overhead latency to see whether the delay is the backend or the gateway.

## Trim what is emitted

```yaml
litellm_settings:
  callbacks: ["prometheus"]
  prometheus_exclude_labels: [user_email, client_ip, user_agent, end_user]
  # or an include-based allowlist per group:
  # prometheus_metrics_config:
  #   - group: token_consumption
  #     metrics: [litellm_input_tokens_metric, litellm_output_tokens_metric, litellm_total_tokens_metric]
  #     include_labels: [model, team, hashed_api_key]
```

Without `prometheus_metrics_config`, all metrics are enabled with default labels. Invalid names fail proxy startup, so restart and read the logs after editing.
