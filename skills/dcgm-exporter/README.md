# DCGM Exporter

An agent skill for installing and operating NVIDIA DCGM Exporter, the Prometheus exporter for GPU telemetry. It covers package, container, Helm and GPU Operator installs, version pairing, collector CSVs for LLM serving, scraping and joining GPU metrics with vLLM, llama.cpp and SGLang, alerts for XID and throttling, unified-memory caveats on DGX Spark, security, updates and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill dcgm-exporter
```

## Rules

- **Ask before changing the system.** Installs, `SYS_ADMIN`, exposed ports and restarts need approval.
- **Pair versions and pin tags**, never `latest`.
- **Bind privately.** Port 9400 has no auth by default.
- **Activity, not utilization.** Use `DCGM_FI_PROF_*` for saturation; framebuffer used is not pressure.
- **Verify live names.** Labels and fields change between releases.

## References

- [`references/install.md`](references/install.md): package, container, Helm, host engine.
- [`references/collectors-and-labels.md`](references/collectors-and-labels.md): CSV, cadence, devices, labels.
- [`references/prometheus-and-engines.md`](references/prometheus-and-engines.md): scrape, host joins, alerts.
- [`references/unified-memory.md`](references/unified-memory.md): DGX Spark GB10.
- [`references/privacy-and-security.md`](references/privacy-and-security.md): auth, sockets, labels.
- [`references/updating.md`](references/updating.md): version pairing, upgrades.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/vllm-prometheus.md`](references/combos/vllm-prometheus.md): beside vLLM.

**Templates and scripts:** [`assets/docker-compose.yaml`](assets/docker-compose.yaml), [`assets/llm-counters.csv`](assets/llm-counters.csv), [`assets/dcgm-alerts.yml`](assets/dcgm-alerts.yml), [`assets/nvidia-dcgm-exporter-collectors.conf`](assets/nvidia-dcgm-exporter-collectors.conf), [`scripts/check.sh`](scripts/check.sh).

## Upstream credits

- [NVIDIA dcgm-exporter](https://github.com/NVIDIA/dcgm-exporter) (Apache-2.0).

## Companion skills

- `prometheus-grafana-llm`: the stack that scrapes and alerts.
- `sparkdash`: DGX Spark dashboard.
- `vllm`, `llama-cpp`, `sglang`: engines to join with.
- `choosing-hardware`: GPU choice and sizing.

## License

MIT
