# Observe LocalAI

> Verified against LocalAI v4.11.0, 2026-10-11

## Health

- `GET /healthz`: liveness. `GET /readyz`: readiness. Both stay open when API keys or auth are on.
- Container probe: `curl -fsS http://127.0.0.1:8080/readyz`. Loading a model is lazy, so readiness does not prove a model works; also run a small chat request.
- `GET /version` returns the running version.

## Logs

```bash
docker logs --tail 200 local-ai
DEBUG=true local-ai run          # or --log-level=debug: backend stdout and stderr, load parameters, per-token timing
```

A 500 body is generic; the real backend gRPC error is in the server log. The UI lists per-backend process output under Operate, Logs (live, filterable, exportable). `LOCALAI_REQUEST_PHASE_TIMING=true` logs sanitized request and config-reload phase timings at INFO.

## Metrics

`GET /metrics` returns Prometheus text. Per the upstream Traffic page it needs an admin credential, so give the scraper an admin API key. Disable it with `LOCALAI_DISABLE_METRICS_ENDPOINT=true`.

- `api_call`: histogram of request duration in seconds by method and route; always present.
- Others appear while their feature runs, for example `localai_failover_switches_total{chain,from,to,reason}`, `localai_failover_target_up`, and `localai_compression_*`.
- The Traffic page in the UI shows the live list, a scrape config snippet and a check against the running server.

```yaml
scrape_configs:
  - job_name: localai
    metrics_path: /metrics
    authorization:
      credentials_file: /etc/prometheus/localai.key # 0600 file with the key
    static_configs:
      - targets: ["localai:8080"]
```

## Traces

Enable with `LOCALAI_ENABLE_TRACING=true` or in runtime settings. The Traces page keeps recent API exchanges and backend operations, with request and response bodies, in a bounded persistent history.

- `LOCALAI_TRACING_MAX_ITEMS` (default 1024) bounds each history.
- `LOCALAI_TRACING_MAX_BODY_BYTES` (default 65536) caps captured bodies.
- Traces contain prompts and responses. Treat them as sensitive and clear them from the page when needed; they are stored under the data path.

## Usage and activity

With `LOCALAI_AUTH=true` the UI shows per-user usage and token consumption. Operate, Activity lists in-flight backend and model installs. `LOCALAI_EXPOSE_NODE_HEADER=true` adds `X-LocalAI-Node` in distributed mode. Failover responses carry `X-LocalAI-Served-Model` and `X-LocalAI-Failover`.

## Profiling

`LOCALAI_PPROF=true` starts a loopback-only pprof listener (`LOCALAI_PPROF_ADDRESS`, default `127.0.0.1:6060`). Leave it off normally.

## What to alert on

Request error rate and latency from `api_call`, 429 and 503 counts, backend restarts in the log, GPU memory from `nvidia-smi` or DCGM, and node status in distributed mode.
