# DCGM metrics in Prometheus, joined with engine metrics

> Verified against dcgm-exporter 4.8.4, Prometheus v3.15.0 configuration docs and the NVIDIA "Configure Prometheus for DCGM Exporter" page, 2026-10-11

## Scrape job

```yaml
scrape_configs:
  - job_name: dcgm
    scrape_interval: 30s # matches the 30 s default collect interval
    static_configs:
      - targets: ["node-a:9400", "node-b:9400"]
```

Scraping faster than `--collect-interval` only repeats cached samples. Kubernetes with the Prometheus Operator uses the chart's `ServiceMonitor`. Add `node_exporter` per host for CPU and host memory (`prometheus-grafana-llm`).

## Join GPU and engine metrics by host

Engines and DCGM scrape from different ports on the same host. Give both jobs a common `host` label:

```yaml
relabel_configs:
  - source_labels: [__address__]
    regex: "([^:]+):\\d+"
    target_label: host
```

Then compare by `host`: a flat `rate(vllm:generation_tokens_total[5m])` with `DCGM_FI_PROF_DRAM_ACTIVE` near 1 says decode is memory-bandwidth bound; queueing (`vllm:num_requests_waiting` > 0) with low `DCGM_FI_PROF_GR_ENGINE_ACTIVE` points to a scheduling or concurrency limit rather than GPU saturation.

```promql
avg by (host) (DCGM_FI_PROF_GR_ENGINE_ACTIVE)
avg by (host) (DCGM_FI_PROF_DRAM_ACTIVE)
sum by (host) (rate(vllm:generation_tokens_total[5m]))
sum by (host) (rate(DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION[5m])) / 1000   # watts from the mJ counter
```

Tokens per joule: generation tokens/s divided by that power figure; useful for capacity and cost decisions. llama.cpp (`llamacpp:*`), SGLang (`sglang:*`) and llama-swap metrics join the same way. Ollama has no `/metrics`, so correlate GPU metrics with gateway metrics instead.

## Dashboards

NVIDIA's dashboard: grafana.com ID 12239, also checked in as `grafana/dcgm-exporter-dashboard.json`. Check its queries against your label names (`hostname` versus `Hostname`) after import.

## Alerts

`assets/dcgm-alerts.yml`: exporter down, up but exporting nothing, XID, high temperature, thermal and power throttling. Cause alerts warn; page on engine and gateway symptoms (`prometheus-grafana-llm`). Do not alert on framebuffer used: engines pre-allocate it (vLLM `--gpu-memory-utilization`); watch KV-cache usage.

## Sending from remote hosts

If Prometheus cannot reach the host, run Grafana Alloy or Prometheus agent mode next to the exporter and `remote_write` out; filter labels with `write_relabel_configs`. See `prometheus-grafana-llm`.

## Official links

- Configure Prometheus for DCGM Exporter: https://docs.nvidia.com/datacenter/dcgm/latest/learn/getting-started-for-system-administrators/configure-prometheus-for-dcgm-exporter.html
- Dashboard 12239: https://grafana.com/grafana/dashboards/12239
