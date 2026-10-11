# sparkDash: Prometheus export and alerting

> Verified against sparkDash v2.32.0 (README Prometheus section), Prometheus v3.15.0 configuration docs, 2026-10-11

Opt-in. **Settings -> Prometheus metrics** serves every unit's metrics at `GET /metrics` in Prometheus text format 0.0.4. While off the path returns 404. It uses the same auth as the REST API: open on loopback, bearer token on a remote bind with `SPARKDASH_TOKEN`.

The exporter reads the snapshot sparkDash already holds, so scraping adds no SSH or `nvidia-smi` calls; values are as fresh as the poll interval. Every series carries `unit`, `unit_name`, `kind` (`spark` or `host`) and `role` (`head`, `worker`, `standalone`). Unknown values are omitted, not zero.

## Scrape config

```yaml
scrape_configs:
  - job_name: sparkdash
    scrape_interval: 15s
    static_configs:
      - targets: ["127.0.0.1:5555"]
    # Only with SPARKDASH_TOKEN on a non-loopback bind; file mode 0600, readable by the Prometheus user:
    # authorization:
    #   type: Bearer
    #   credentials_file: /etc/prometheus/secrets/sparkdash.token
```

Scrape through the tunnel or Tailscale name if Prometheus runs elsewhere; never open the port to the LAN just for this.

## Metric families

| Family                                                                                          | Meaning                                                                                           |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `sparkdash_up`                                                                                  | 1 when the unit answered liveness; unreachable units export only this, as 0                       |
| `sparkdash_collector_last_success_timestamp_seconds{collector}`                                 | Last real poll per collector (`gpu`, `cpu`, `ram`, `memory`, `network`, `storage`, `llm`, `roce`) |
| `sparkdash_gpu_utilization_ratio`, `_temperature_celsius`, `_power_watts`, `_power_limit_watts` | Per `gpu`                                                                                         |
| `sparkdash_gpu_memory_used_bytes`, `_total_bytes`                                               | GB10: GPU share of the unified pool                                                               |
| `sparkdash_gpu_throttled{reason}`                                                               | 1 for `thermal`, `power` or `hw`                                                                  |
| `sparkdash_memory_available_bytes`                                                              | Headroom for GPU work (unified-pool `MemAvailable` on GB10)                                       |
| `sparkdash_cpu_*`, `sparkdash_ram_*`, `sparkdash_network_*`, `sparkdash_disk_*`                 | Host basics                                                                                       |
| `sparkdash_llm_up{port,backend,model}`                                                          | Per probed endpoint                                                                               |
| `sparkdash_llm_generation_tokens_per_second`, `_prefill_tokens_per_second`                      | Rates                                                                                             |
| `sparkdash_llm_kv_cache_usage_ratio`, `_requests_running`, `_requests_waiting`                  | Where the backend reports them                                                                    |
| `sparkdash_llm_generated_tokens_total`, `_prompt_tokens_total`, `_cached_prompt_tokens_total`   | Engine lifetime counters; `rate()` handles restarts                                               |

## Alerts

`assets/sparkdash-alerts.yml` ships starting rules: unit down, stale collector (the upstream-recommended `time() - ...last_success... > 60`), throttling, low memory headroom, endpoint down and queueing. Validate with `promtool check rules`. A stuck collector stops advancing while `sparkdash_up` stays 1, so alert on staleness, not only on `up`. For discrete NVIDIA GPUs prefer DCGM metrics for per-engine activity; see `dcgm-exporter`.

## Read-only check

```bash
curl -fsS http://127.0.0.1:5555/metrics | grep -E '^sparkdash_(up|llm_up)' | head
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5555/metrics   # 404 means the setting is off
```

## Official links

- README Prometheus: https://github.com/MiaAI-Lab/sparkDash#prometheus
- Prometheus configuration: https://prometheus.io/docs/prometheus/latest/configuration/configuration/
