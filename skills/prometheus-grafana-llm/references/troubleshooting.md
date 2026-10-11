# Troubleshooting Prometheus and Grafana for LLM serving

> Verified against Prometheus v3.15.0, Alertmanager v0.34.1, Grafana v13.2.3, vLLM v0.31.0, LiteLLM v1.105.0, 2026-10-11

| Symptom                                    | Cause                                                                  | Fix                                                                                                |
| ------------------------------------------ | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Target `down`, `connection refused`        | Prometheus runs in a container and uses `127.0.0.1`                    | Use LAN or tailnet names, or `host.docker.internal` with `extra_hosts`                             |
| Target `down`, `context deadline exceeded` | Slow `/metrics` or timeout too low                                     | Raise `scrape_timeout` (at most the interval); trim LiteLLM series                                 |
| `401` or `403` on `/metrics`               | LiteLLM (since 1.85.0), llama.cpp `--api-key`, or llama-swap `apiKeys` | `authorization` with `credentials_file`, or LiteLLM's dedicated metrics port on a private network  |
| `credentials_file` unreadable              | Image runs as uid 65534; file mode 600 owned by you                    | `chown 65534` the secret directory and file                                                        |
| `/metrics` 404 on SGLang                   | Missing `--enable-metrics`                                             | Add the flag                                                                                       |
| llama.cpp `/metrics` 404                   | Missing `--metrics`                                                    | Add the flag; router mode needs `?model=`                                                          |
| Ollama target never works                  | No `/metrics` endpoint                                                 | Measure at the gateway; see `scrape-engines.md`                                                    |
| Rule returns nothing after upgrade         | Metric renamed                                                         | Diff live names; add `absent()` guards                                                             |
| `histogram_quantile` jumps or NaN          | Missing `sum by (le)`, idle series, short `rate` window                | Aggregate by `le`; guard on traffic; window at least 4x scrape interval                            |
| LiteLLM values jump between scrapes        | Multi-worker without `PROMETHEUS_MULTIPROC_DIR`                        | Set it per LiteLLM docs                                                                            |
| Prometheus memory or disk growth           | High cardinality labels                                                | `prometheus_tsdb_head_series`, `labeldrop`, gateway label exclusion                                |
| `promtool` not installed                   | n/a                                                                    | Run it from the `prom/prometheus` image with `--entrypoint promtool`                               |
| Reload ignored                             | `--web.enable-lifecycle` missing                                       | Add it, or restart the container                                                                   |
| Alerts fire but nothing arrives            | Alertmanager not wired or receiver URL wrong                           | `curl :9090/api/v1/alertmanagers`; check `amtool` and receiver logs                                |
| Grafana login fails after restart          | Password file empty or wrong mount                                     | Check the `__FILE` mount; reset with `grafana cli admin reset-admin-password` inside the container |
| Dashboard panels empty                     | Metric names differ or label `model_name` missing                      | Query in Explore; adjust variables                                                                 |

## Diagnose

```bash
scripts/check.sh
docker compose logs --tail 80 prometheus
curl -fsS 'http://127.0.0.1:9090/api/v1/query' --data-urlencode 'query=up == 0' | jq -r '.data.result[]|.metric.job+" "+.metric.instance'
curl -fsS http://127.0.0.1:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName[0:10]'
```

## Official links

- Prometheus troubleshooting FAQ: https://prometheus.io/docs/introduction/faq/
- Grafana CLI: https://grafana.com/docs/grafana/latest/cli/
