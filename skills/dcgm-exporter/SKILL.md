---
name: dcgm-exporter
description: NVIDIA DCGM Exporter, the Prometheus exporter for GPU telemetry (utilization, memory, power, temperature, XID errors, profiling counters). Use to install it as a package, Docker container or Helm release, pick collector CSV fields, scrape it from Prometheus, join GPU metrics with vLLM or llama.cpp metrics, alert on XID and throttling, update, or fix no DCGM_ metrics, missing PROF fields, GB10 memory. Not for the Prometheus stack (prometheus-grafana-llm).
license: MIT
compatibility: Needs an NVIDIA GPU, driver, and for containers the NVIDIA Container Toolkit; Linux only. Commands assume bash, curl and Docker; installs, capabilities (SYS_ADMIN), exposure and restarts need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# DCGM Exporter

A working `dcgm-exporter` (NVIDIA, Apache-2.0) per GPU host that Prometheus scrapes on port 9400, with a collector set suited to LLM serving, alert rules for XID and throttling, and an honest reading of what the numbers mean.

**Scope:** this one exporter: install (package, container, Helm), collectors, devices, labels, scrape, alerts, update, troubleshoot. The Prometheus and Grafana stack is `prometheus-grafana-llm`. Engine metrics are in `vllm`, `sglang`, `llama-cpp`. The DGX Spark dashboard is `sparkdash`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secrets.

```bash
nvidia-smi -L && nvidia-smi --query-gpu=index,name,driver_version --format=csv
docker ps --format '{{.Names}}\t{{.Image}}' | grep -i dcgm || true
systemctl status nvidia-dcgm nvidia-dcgm-exporter --no-pager 2>/dev/null | head -12
command -v dcgm-exporter && dcgm-exporter --version
docker info 2>/dev/null | grep -i -E 'runtimes|nvidia'
curl -fsS -m 5 http://127.0.0.1:9400/metrics | grep -c '^DCGM_'
uname -m; nvidia-smi -q 2>/dev/null | grep -i -E 'Product Name|Memory-Usage|Not Supported' | head
gh api repos/NVIDIA/dcgm-exporter/releases/latest --jq .tag_name
```

Ask only what discovery cannot show: bare metal, container or Kubernetes, discrete GPU or unified memory (DGX Spark GB10), whether profiling counters are wanted, and who scrapes.

## Decision flow

1. **Kubernetes with GPU Operator:** already managed; edit its metrics ConfigMap. Without it, Helm. -> `references/install.md`
2. **Single GPU host:** container or package. -> `references/install.md`
3. **Choose fields, cadence, devices:** -> `references/collectors-and-labels.md`
4. **Scrape and join with engines, dashboards, alerts:** -> `references/prometheus-and-engines.md`
5. **DGX Spark or other unified-memory GPU:** -> `references/unified-memory.md`
6. **Labels, sockets, exposure:** -> `references/privacy-and-security.md`
7. **New release:** -> `references/updating.md`
8. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, `--cap-add SYS_ADMIN`, exposed ports and restarts need approval.
- **Pair versions.** Run the DCGM version paired with the exporter release; image tags are `<dcgm>-<exporter>-<variant>`. Pin one, not `latest`.
- **Bind privately.** Port 9400 has no auth by default; bind it to the Prometheus-facing interface or use `--web-config-file`.
- **GPU activity beats utilization.** `DCGM_FI_DEV_GPU_UTIL` only means a kernel ran; use `DCGM_FI_PROF_*` for saturation.
- **Memory used is not pressure.** Engines pre-allocate; alert on the engine's KV-cache metric, not framebuffer used.
- **Each label is a series.** Enable Kubernetes, pod-label and container labels only when queries need them.
- **Secrets never touch output.** Web config passwords live in `0600` files.
- **Verify live names.** Label and field names change between releases; read `/metrics`.

## Workflows

### Install and first scrape

- [ ] Choose package, container or Helm -> `references/install.md`.
- [ ] Copy `assets/llm-counters.csv`, trim to fields your GPU supports, start with `--collectors`.
- [ ] `scripts/check.sh` lists families; profiling fields present if `SYS_ADMIN` was granted.
- [ ] Add the scrape job and `assets/dcgm-alerts.yml` -> `references/prometheus-and-engines.md`.

### Unified memory host

- [ ] Do not trust framebuffer fields; use host `MemAvailable` -> `references/unified-memory.md`.

### Update

- [ ] Check the pairing table, bump the tag or package, restart, rerun `scripts/check.sh` -> `references/updating.md`.

## Reference index

| File                                   | Read when                                                                         |
| -------------------------------------- | --------------------------------------------------------------------------------- |
| `references/install.md`                | Package, container, Helm, GPU Operator, host engine, systemd drop-in              |
| `references/collectors-and-labels.md`  | CSV format, field choices, cadence, devices, labels, YAML config                  |
| `references/prometheus-and-engines.md` | Scrape job, host label joins, queries with vLLM and llama.cpp, dashboards, alerts |
| `references/unified-memory.md`         | DGX Spark GB10 and other iGPU systems                                             |
| `references/privacy-and-security.md`   | Auth and TLS, sockets, labels, debug dumps                                        |
| `references/updating.md`               | Version pairing, upgrade paths, reloads                                           |
| `references/troubleshooting.md`        | Symptom to cause to fix                                                           |
| `references/combos/vllm-prometheus.md` | GPU metrics beside vLLM on one host                                               |

Templates: `assets/docker-compose.yaml`, `assets/llm-counters.csv`, `assets/dcgm-alerts.yml`, `assets/nvidia-dcgm-exporter-collectors.conf`. Script: `scripts/check.sh`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `prometheus-grafana-llm`: the stack that scrapes, stores and alerts.
- `sparkdash`: DGX Spark dashboard when DCGM is a poor fit.
- `vllm`, `llama-cpp`, `sglang`: engines whose metrics you join with GPU metrics.
- `choosing-hardware`: picking GPUs and sizing memory.
