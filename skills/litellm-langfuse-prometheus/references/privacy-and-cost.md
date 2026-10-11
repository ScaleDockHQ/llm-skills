# Privacy, retention and cost views

> Verified against LiteLLM v1.105.0 (docs: proxy/logging, proxy/prometheus, existing `llm-observability` gateway-logging reference) and Langfuse v4.56.0 (GitHub release), 2026-10-11

## Decide what leaves the gateway

| Setting                                                | Effect                                                                                            |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `litellm_settings.turn_off_message_logging: true`      | Messages and responses are not sent to logging providers; metadata such as spend is still tracked |
| `litellm_settings.redact_user_api_key_info: true`      | Key and user info is stripped from logging callbacks                                              |
| `prometheus_exclude_labels: [...]`                     | Drops high-cardinality or personal labels from every Prometheus metric                            |
| `general_settings.store_prompts_in_spend_logs`         | Keep `false` (the documented default) unless you need prompts in Postgres                         |
| `general_settings.maximum_spend_logs_retention_period` | Purges old spend logs; unset means never                                                          |

Per-request override: with message logging off globally, a request can opt back in; check the logging docs before relying on it. Decide this before first traffic: traces already stored in Langfuse are not unsent. Retention and deletion in Langfuse itself: `langfuse` skill, `privacy-retention.md`.

```yaml
litellm_settings:
  callbacks: ["prometheus", "langfuse_otel"]
  turn_off_message_logging: true
  redact_user_api_key_info: true
  prometheus_exclude_labels: [user_email, client_ip, user_agent, end_user]
general_settings:
  store_prompts_in_spend_logs: false
  maximum_spend_logs_retention_period: "30d"
  maximum_spend_logs_retention_interval: "1d"
```

Apply and confirm with a restart plus `docker compose logs litellm | grep -i -E 'error|invalid'` (invalid Prometheus label or metric names fail startup).

## Where cost lives

- **LiteLLM** computes cost per request from its model price data and exposes it as `litellm_spend_metric` (labelled by key alias, team, model) and in the Admin UI and spend reports (Postgres required). Local models without price data show zero cost: set `model_info` costs in the LiteLLM config if you want an internal chargeback figure.
- **Langfuse** shows model, tokens and cost on each generation and aggregates by model, user and tag in its dashboards.
- The two should agree on token counts; differences usually mean different price tables or missing usage on streamed responses. Treat Prometheus for trends and alerts, Langfuse for per-request drill-down.

## Useful queries

```promql
# spend per team over the last day (counter; confirm exact name with a curl of /metrics)
sum by (team_alias) (increase(litellm_spend_metric[24h]))
# token throughput by model
sum by (model) (rate(litellm_total_tokens_metric[5m]))
# errors as a share of requests
sum(rate(litellm_proxy_failed_requests_metric[5m])) / sum(rate(litellm_proxy_total_requests_metric[5m]))
```

Counter names may carry a `_total` suffix in the exposition; adjust after checking `/metrics`. Alert rules and Grafana provisioning: `llm-observability` skill.
