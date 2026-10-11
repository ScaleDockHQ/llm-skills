# NVIDIA Dynamo observability

> Verified against Dynamo v1.5.1, 2026-10-11

| Family                     | Exposed by                 | Where                                             |
| -------------------------- | -------------------------- | ------------------------------------------------- |
| `dynamo_frontend_*`        | HTTP frontend              | `/metrics` on `DYN_HTTP_PORT` (8000)              |
| `dynamo_component_*`       | workers, standalone router | `/metrics` on `DYN_SYSTEM_PORT` (**must be set**) |
| `dynamo_router_overhead_*` | frontend with KV routing   | frontend `/metrics`                               |
| `dynamo_epp_*`             | GAIE endpoint picker       | `DYN_EPP_METRICS_PORT` (9090)                     |
| `dynamo_operator_*`        | Kubernetes operator        | operator metrics                                  |

Prometheus registers labeled series after the first matching request, so some families are empty until traffic arrives.
`--metrics-prefix` renames frontend families; `dynamo_frontend_worker_*` (per-worker load and timing) is not created
in some configurations (see the metrics catalog "availability by configuration" table).

```bash
curl -s localhost:8000/metrics | grep -E '^dynamo_frontend_' | cut -d'{' -f1 | sort -u
DYN_SYSTEM_PORT=8081 python3 -m dynamo.vllm --model Qwen/Qwen3-0.6B --enforce-eager &   # worker metrics on :8081
curl -s localhost:8081/metrics | grep -E '^dynamo_component_' | head
```

Local stack: `docker-observability.yml` in the repo (Prometheus, Grafana, Tempo, Loki, OTel Collector); Grafana on port
3000 with a "Dynamo Dashboard"; its default dev login is documented in the guide, change it on anything shared.
Tracing and logs: the launch scripts `agg_tracing.sh` and `disagg_tracing.sh` enable JSONL logging and OTLP export; send
`x-request-id` to correlate a request across traces and logs. On Kubernetes install kube-prometheus-stack and set
`dynamo-operator.dynamo.metrics.prometheusEndpoint`.

Health: `curl /health` on the frontend; workers expose health on `DYN_SYSTEM_PORT`. Use TCP/HTTP probes with generous
startup timeouts: large models load for many minutes.
