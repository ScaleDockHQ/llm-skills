# DCGM Exporter troubleshooting

> Verified against dcgm-exporter 4.8.4 install docs and command reference, 2026-10-11

| Symptom                                      | Cause                                                                             | Fix                                                                                                            |
| -------------------------------------------- | --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Endpoint up, no `DCGM_` series               | Driver or DCGM mismatch, GPUs not visible                                         | `nvidia-smi` on host; container needs `--gpus all` and the Container Toolkit; match DCGM and exporter versions |
| `DCGM_FI_PROF_*` missing                     | No `SYS_ADMIN`, GPU unsupported, or another profiler (Nsight) holds counters      | `--cap-add SYS_ADMIN`; use the `dcp-metrics-included.csv` preset or add the fields; stop the other profiler    |
| Container exits at start                     | Bad CSV (not three columns), retired field in a custom CSV, malformed `--devices` | Read `docker logs`; fix the CSV; see failure list in the command reference                                     |
| `Memory-Usage: Not Supported`, FB fields odd | Unified memory (GB10)                                                             | `unified-memory.md`                                                                                            |
| Changing the CSV has no effect               | Wrong file mounted, or flags/YAML changed                                         | Reload with `SIGHUP` for CSV; restart for flags and YAML                                                       |
| Values repeat between scrapes                | Scrape interval below collect interval                                            | Scrape at the collect interval or lower `--collect-interval`                                                   |
| Counters reset                               | Exporter restart or reload                                                        | Use `rate()`                                                                                                   |
| Queries return nothing after upgrade         | Label casing or field renamed                                                     | Compare labels in `/metrics` (`hostname`, `UUID`)                                                              |
| Prometheus cannot reach the exporter         | Bound to loopback, firewall                                                       | Publish on the private address; open the port to Prometheus only                                               |
| Helm install fails on ServiceMonitor         | Prometheus Operator CRDs missing                                                  | `--set serviceMonitor.enabled=false`                                                                           |
| Too many series                              | Pod labels, UID or container labels on                                            | Allowlist or disable                                                                                           |
| Wrong GPU shows in MIG setups                | Selector                                                                          | `--devices` with `g`, `i`, `f`; restart after live MIG changes                                                 |
| Remote host engine fails                     | Version relationship or transport                                                 | Client library must be at least the host engine version; check endpoint and socket mount                       |

## Diagnose

```bash
scripts/check.sh
docker logs --tail 80 dcgm-exporter
journalctl -u nvidia-dcgm-exporter --since today --no-pager | tail -40
dcgm-exporter --debug --collectors /etc/dcgm-exporter/llm-counters.csv   # foreground, debug logs
```

## Official links

- DCGM troubleshooting: https://docs.nvidia.com/datacenter/dcgm/latest/learn/getting-started-for-system-administrators/
- Issues: https://github.com/NVIDIA/dcgm-exporter/issues
