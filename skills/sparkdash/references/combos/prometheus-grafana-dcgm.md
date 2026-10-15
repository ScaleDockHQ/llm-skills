# sparkDash with Prometheus, Grafana and DCGM

> Verified against sparkDash v2.32.0, Prometheus v3.15.0 and dcgm-exporter 4.8.4, 2026-10-11

sparkDash is the glance; Prometheus is history and alerts. Use both when you operate more than a couple of nodes.

- **Discrete NVIDIA GPUs:** run `dcgm-exporter` for profiling counters (engine, tensor and DRAM activity) and XID; sparkDash adds engine probes, RoCE and power controls.
- **DGX Spark (GB10, unified memory):** DCGM framebuffer fields may not be meaningful; sparkDash's `sparkdash_memory_available_bytes` and `node_exporter` `MemAvailable` are the trusted headroom signals. Whether DCGM reports usefully on GB10 is unverified here.
- **Do not double-alert.** Alert on engine metrics straight from the engines (see `prometheus-grafana-llm`); use sparkDash alerts for unit down, stale collectors and throttling.
- **One scrape path.** Prometheus scrapes sparkDash over the tunnel or Tailscale name with the bearer token file; keep the dashboard on loopback.

```yaml
scrape_configs:
  - job_name: sparkdash
    static_configs: [{ targets: ["127.0.0.1:5555"] }]
  - job_name: dcgm
    static_configs: [{ targets: ["node-a:9400", "node-b:9400"] }]
  - job_name: node
    static_configs: [{ targets: ["node-a:9100", "node-b:9100"] }]
```

Install companions: `npx skills add ScaleDockHQ/llm-skills --skill prometheus-grafana-llm`, `--skill dcgm-exporter`.
