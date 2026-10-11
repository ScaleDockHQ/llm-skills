# Observability

> Verified against TensorRT-LLM v1.2.1 (`openai_server.py`, `llm_args.py`, `serve.py`) and `main` serve docs, 2026-10-11

## Health

- `GET /health`: process is up (no generation). Use for llama-swap `checkEndpoint`, compose and Kubernetes probes.
- `GET /health_generate`: runs a real generation probe (v1.2.1 route); heavier, do not poll fast.
- `GET /version`: version string; record it in your inventory.
- Cold starts are long (weights load, CUDA graph capture). Give probes a generous start period (minutes for 100B+ models).

## Iteration stats: `/metrics`

JSON list of per-iteration records (GPU memory use, iteration latency, `kvCacheStats` with `cacheHitRate`, `maxNumBlocks`, `usedNumBlocks`, `numActiveRequests`, ...). Beta; some fields (CPU memory) are not populated. Enable in the YAML:

```yaml
enable_iter_perf_stats: true
iter_perf_stats_interval: 10 # per main docs; build stats every N iterations to cut overhead (confirm in your tag)
```

Statistics sit in an internal queue and are removed once read, so poll shortly after requests and store what you need:

```bash
curl -s http://127.0.0.1:8000/metrics | jq '.[-1] | {iter, numActiveRequests, kv: .kvCacheStats | {cacheHitRate, usedNumBlocks, maxNumBlocks}}'
```

Enabling stats can slightly affect performance. Through llama-swap: `curl -s http://127.0.0.1:8080/upstream/<model>/metrics`.

## Prometheus and per-request metrics

With `return_perf_metrics: true` in the YAML (field names from v1.2.1 `llm_args.py`), the server mounts `/prometheus/metrics` and can keep per-request timing at `/perf_metrics` when `perf_metrics_max_requests > 0`. The mount uses prometheus multiprocess mode, so set `PROMETHEUS_MULTIPROC_DIR` to a writable directory in the container (documented in the source comment; confirm it is needed on your tag). Metric names were not enumerated here. (unverified)

```yaml
return_perf_metrics: true
perf_metrics_max_requests: 1000
```

Scrape example (Prometheus):

```yaml
scrape_configs:
  - job_name: trtllm
    metrics_path: /prometheus/metrics
    static_configs: [{ targets: ["127.0.0.1:8000"] }]
```

## Logs

- `docker logs -f <container>`; `--log_level debug|info|warning|error`.
- `print_iter_log: true` adds per-iteration lines (the Spark playbook sets it `false`).
- Startup lines to look for: model load, KV cache allocation (`free_gpu_memory_fraction`, number of blocks), CUDA graph capture, `Uvicorn running on ...`.
- Source commit of an image: `docker exec <c> printenv TRT_LLM_GIT_COMMIT`.

## Tracing

`--otlp_traces_endpoint http://collector:4317` sends OpenTelemetry traces (prototype). Dynamo's launch scripts pair it with `return_perf_metrics` in `--override-engine-args` (see `combos/dynamo.md`).

## Telemetry to NVIDIA

Docs on `main` describe usage telemetry, with `--no-telemetry` to opt out and a note that eligible configuration fields may be included. v1.2.1's `serve` command has no such flag. Check the tag you run and opt out where policy requires it.

## Cross-stack

For gateway-level metrics, traces and cost dashboards use `llm-observability` (`npx skills add ScaleDockHQ/llms-skills --skill llm-observability`).

## Official links

- Metrics endpoint: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/trtllm-serve.html#metrics-endpoint
- Runtime profiling endpoints: same page, section "Runtime Profiling Endpoints"
