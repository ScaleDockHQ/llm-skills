# DCGM Exporter beside vLLM and Prometheus

> Verified against dcgm-exporter 4.8.4, vLLM v0.31.0 metrics docs and Prometheus v3.15.0, 2026-10-11

One host runs vLLM on 8000 and dcgm-exporter on 9400; Prometheus scrapes both with a shared `host` label.

```yaml
scrape_configs:
  - job_name: vllm
    static_configs:
      [
        {
          targets: ["node-a:8000"],
          labels: { backend: vllm, model: "<served-model-name>" },
        },
      ]
    relabel_configs:
      [
        {
          source_labels: [__address__],
          regex: "([^:]+):\\d+",
          target_label: host,
        },
      ]
  - job_name: dcgm
    static_configs: [{ targets: ["node-a:9400"] }]
    relabel_configs:
      [
        {
          source_labels: [__address__],
          regex: "([^:]+):\\d+",
          target_label: host,
        },
      ]
```

Reading it:

- High `vllm:kv_cache_usage_perc` and rising `vllm:num_preemptions_total`: KV pressure; GPU activity does not tell you this.
- Waiting requests with low `DCGM_FI_PROF_GR_ENGINE_ACTIVE`: the limit is concurrency or scheduling, not compute.
- `DCGM_FI_PROF_DRAM_ACTIVE` high at steady decode: memory-bandwidth bound, expected for decode.
- Thermal or power violation counters rising while TTFT worsens: throttling is a cause.

Install the companions: `npx skills add ScaleDockHQ/llm-skills --skill prometheus-grafana-llm`, `--skill vllm`.
