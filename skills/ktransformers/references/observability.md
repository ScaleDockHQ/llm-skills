# Observability

> Verified against KTransformers v0.7.1 (sglang-kt `server_args.py` and `http_server.py`; no KT-specific metrics are documented), 2026-10-11

KT adds no metrics of its own that this skill could find; observability is SGLang's plus host monitoring.

## SGLang side

```bash
curl -s -o /dev/null -w 'live %{http_code}\n' http://127.0.0.1:30000/health            # liveness
curl -s -o /dev/null -w 'gen %{http_code}\n' -m 60 http://127.0.0.1:30000/health_generate   # runs a tiny generation
curl -s http://127.0.0.1:30000/v1/models | jq '.data[].id'
```

`--enable-metrics` exposes Prometheus metrics at `/metrics` (and `--enable-metrics-for-all-schedulers` for every scheduler). Series names depend on the SGLang version in
`sglang-kt`: list them with `curl -s localhost:30000/metrics | grep '^# TYPE' | head -50` before building dashboards, and see the `sglang` and `prometheus-grafana-llm` skills.
Scrape from the private network only.

## Host side (where KT bottlenecks show up)

```bash
nvidia-smi dmon -s um -d 5                 # GPU utilisation and memory
numastat -m | head -20                     # per-NUMA memory
numactl --hardware | grep free
top -H -p $(pgrep -f sglang.launch_server | head -1)    # CPU inference threads busy?
sudo turbostat --quiet --interval 5 2>/dev/null | head   # frequency throttling (AMX/AVX512 can lower clocks)
```

High GPU idle with all CPU threads at 100% means CPU-bound decode (add GPU experts or bandwidth); free memory on one NUMA node near zero means imbalanced placement.

## Logs

Startup logs print the chosen method, thread pools and GPU expert counts; keep them for each deployment. SGLang flags `--log-requests` and `--log-level` exist in upstream
SGLang (confirm with `--help`) and `--log-requests` records prompts, so treat it as a retention decision.
