# Observability for MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

- **Readiness:** `curl -s http://127.0.0.1:8000/v1/models`.
- **Metrics:** `GET /metrics` returns Prometheus text from the first loaded engine's `metrics().prometheus_text()`. It is outside `--api-key` auth.
- **Debug endpoints** (only with `--enable-debug`): `POST /debug/dump_event_trace`, `/debug/cuda_profiler_start`, `/debug/cuda_profiler_stop`, `/debug/dump_engine_metrics`, `/debug/reset_engine`. Enabling debug also adds extra usage and debug config to responses. Keep it off on reachable hosts.
- **Tracing:** `--enable-tracing` records request events; dump them with `/debug/dump_event_trace` when debug is on.
- **Chat CLI:** `/stats` and `/metrics` inside `mlc_llm chat`.
- **Logs:** the log prints the JIT policy, the model library path (cached or newly compiled) and the memory plan; capture them with systemd or `tee`. Prompts are not logged by default.

```bash
curl -s http://127.0.0.1:8000/metrics | head -30
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv
```
