# DCGM Exporter: collectors, cadence, devices, labels

> Verified against dcgm-exporter 4.8.4 command reference and default-counters.csv / dcp-metrics-included.csv at tag 4.8.4, 2026-10-11

## Collector CSV

Exactly three columns: DCGM field name, type (`counter`, `gauge`, `untyped` or `label`), help. Lines starting with `#` are comments. A `label` row adds a string value (for example driver version) as a label on other samples. Pass it with `-f`/`--collectors` or `DCGM_EXPORTER_COLLECTORS`.

Shipped files in the container: `default-counters.csv` (default; no profiling fields), `dcp-metrics-included.csv` (adds `DCGM_FI_PROF_*`), `1.x-compatibility-metrics.csv` (legacy names). `assets/llm-counters.csv` is a trimmed set for LLM serving.

| Question                         | Field                                                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Is the GPU busy?                 | `DCGM_FI_PROF_GR_ENGINE_ACTIVE` (better than `DCGM_FI_DEV_GPU_UTIL`, which means only "a kernel was running") |
| Tensor cores used?               | `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE`                                                                             |
| Memory-bandwidth bound (decode)? | `DCGM_FI_PROF_DRAM_ACTIVE`                                                                                    |
| PCIe traffic                     | `DCGM_FI_PROF_PCIE_TX_BYTES`, `_RX_BYTES`                                                                     |
| Memory headroom                  | `DCGM_FI_DEV_FB_USED`, `_FB_FREE` (discrete GPUs)                                                             |
| Thermal and power                | `DCGM_FI_DEV_GPU_TEMP`, `DCGM_FI_DEV_POWER_USAGE`, `DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION`                     |
| Throttling                       | `DCGM_FI_DEV_THERMAL_VIOLATION`, `DCGM_FI_DEV_POWER_VIOLATION` (ns counters; commented out by default)        |
| Hardware faults                  | `DCGM_FI_DEV_XID_ERRORS` (last XID value; carries `err_code` and `err_msg` labels)                            |
| Exporter-owned XID counts        | `DCGM_EXP_XID_ERRORS_COUNT`, `DCGM_EXP_XID_ERRORS_TOTAL` (opt-in)                                             |

4.8.x notes: retired PCIe throughput fields were removed from supplied configs and custom CSVs using them fail (use `DCGM_FI_PROF_PCIE_TX_BYTES` and `_RX_BYTES`); more than 128 fields are batched; opt-in exporter self-metrics via `--enable-exporter-metrics`; `DCGM_FI_DEV_POWER_MGMT_LIMIT` and `DCGM_FI_DEV_ENFORCED_POWER_LIMIT` are opt-in.

The command reference's YAML example uses names such as `DCGM_FI_DEV_GPU_TEMP_CELSIUS` that do not appear in the 4.8.4 CSVs; treat YAML field names as unverified and prefer the CSV, whose names are checked against the live exporter.

## Cadence

`-c`/`--collect-interval` (ms, default 30000) is the DCGM watch cadence. A Prometheus scrape reads the latest cached sample, so scraping faster than the interval repeats values. YAML (`--config-file`, schema version 1, read at startup only) can give field groups their own intervals (`watchGroups`). A collector CSV on disk is watched and also reloads on `SIGHUP`; flags, env and YAML need a restart. Reloads reset exporter-owned counters.

## Devices

`-d`/`--devices`: `f` (default: each full GPU, or each GPU instance when MIG is on), `g[:ids]`, `i[:ids]`, combined like `g+i`. `-s` selects NvSwitches and NvLinks, `-p` CPUs. Example: `--devices g:0,2-3`.

## Labels

GPU samples carry `gpu` (index), `UUID` (or `uuid` with `--use-old-namespace`), `pci_bus_id`, `device`, `modelName`, and `hostname` unless `-n` is set; MIG adds profile labels. Casing has changed between releases, so read your own `/metrics` before writing queries. `--replace-blanks-in-model-name` hyphenates `modelName`.

Optional workload labels (each multiplies series): `--kubernetes` (pod, namespace, container), `--kubernetes-enable-pod-labels` with an allowlist regex, `--kubernetes-enable-pod-uid`, `--kubernetes-virtual-gpus`, `--kubernetes-enable-dra`, `--container-labels` plus `--container-runtime-socket` outside Kubernetes, `--hpc-job-mapping-dir`.

## Read-only checks

```bash
curl -fsS http://127.0.0.1:9400/metrics | grep -E '^# (HELP|TYPE)' | head -20
curl -fsS http://127.0.0.1:9400/metrics | grep -m3 '^DCGM_FI_DEV_GPU_TEMP'
dcgm-exporter --help | head -60
```

## Official links

- Command reference: https://docs.nvidia.com/datacenter/dcgm/latest/reference/command-line-reference/dcgm-exporter.html
- Metrics: https://docs.nvidia.com/datacenter/dcgm/latest/reference/dcgm-exporter-metrics.html
- Default counters: https://github.com/NVIDIA/dcgm-exporter/blob/main/etc/default-counters.csv
