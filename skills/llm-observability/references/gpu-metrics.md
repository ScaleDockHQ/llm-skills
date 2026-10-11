# GPU metrics: DCGM exporter, nvidia-smi, unified memory

> Verified against dcgm-exporter 4.8.4 (DCGM 4.6.1) docs and source, NVIDIA DGX Spark known-issues docs, 2026-10-11

## What it is and when to choose it

- **DCGM exporter**: NVIDIA's Prometheus exporter for GPU telemetry (utilization, memory, power, temperature, XID errors, profiling counters). Choose it for any NVIDIA host scraped by Prometheus.
- **nvidia-smi**: ad-hoc inspection and quick scripts; not a monitoring system.
- **llama-swap `/metrics`**: if llama-swap already runs on the host, it exports basic GPU metrics (`llamaswap_gpu_*`) without another container; see `metrics-engines.md`.

GPU metrics explain causes (saturation, thermal throttling, memory pressure). Alert on user-facing symptoms first (see `alerting.md`).

## Install

Docker (one exporter per GPU host):

```bash
export DCGM_EXPORTER_TAG=latest   # pin a release tag for production
docker run -d --rm --name dcgm-exporter \
  --gpus all --cap-add SYS_ADMIN \
  -p 9400:9400 \
  nvcr.io/nvidia/k8s/dcgm-exporter:${DCGM_EXPORTER_TAG}
curl -fsS http://localhost:9400/metrics | grep -c '^DCGM_'
```

`--cap-add SYS_ADMIN` enables the `DCGM_FI_PROF_*` profiling fields. Kubernetes:

```bash
helm repo add gpu-helm-charts https://nvidia.github.io/dcgm-exporter/helm-charts
helm repo update
helm install dcgm-exporter gpu-helm-charts/dcgm-exporter \
  --namespace gpu-monitoring --create-namespace \
  --set serviceMonitor.enabled=false   # drop this if the Prometheus Operator CRDs exist
```

With the NVIDIA GPU Operator, the exporter is already managed; configure it through the Operator's metrics ConfigMap.

## Minimal working config

Default collectors (`etc/default-counters.csv`) are a sensible start. To trim, write a 3-column CSV (`field, type, help`) and pass `--collectors`:

```csv
DCGM_FI_DEV_GPU_UTIL, gauge, GPU utilization (in %).
DCGM_FI_DEV_FB_USED, gauge, Framebuffer memory used (in MiB).
DCGM_FI_DEV_FB_FREE, gauge, Framebuffer memory free (in MiB).
DCGM_FI_DEV_GPU_TEMP, gauge, GPU temperature (in C).
DCGM_FI_DEV_POWER_USAGE, gauge, Power draw (in W).
DCGM_FI_DEV_XID_ERRORS, gauge, Value of the last XID error encountered.
DCGM_FI_PROF_GR_ENGINE_ACTIVE, gauge, Ratio of time the graphics engine is active.
DCGM_FI_PROF_PIPE_TENSOR_ACTIVE, gauge, Ratio of cycles the tensor (HMMA) pipe is active.
DCGM_FI_PROF_DRAM_ACTIVE, gauge, Ratio of cycles the device memory interface is active.
```

```bash
docker run -d --rm --name dcgm-exporter --gpus all --cap-add SYS_ADMIN -p 9400:9400 \
  --mount type=bind,src=/opt/dcgm-exporter/custom.csv,dst=/etc/dcgm-exporter/custom.csv,readonly \
  nvcr.io/nvidia/k8s/dcgm-exporter:${DCGM_EXPORTER_TAG} \
  --collectors /etc/dcgm-exporter/custom.csv
```

## How it plugs into the stack

- Endpoint `http://<gpu-host>:9400/metrics`, no auth by default. `--web-config-file` takes a Prometheus exporter-toolkit web config for TLS or basic auth.
- Labels include `gpu` (index), a UUID label, `modelName`, and a hostname label; check your exposition, label spelling has changed across releases.
- Join with engine metrics by `instance` host: relabel both jobs to a common `host` label in Prometheus.
- Grafana: NVIDIA's DCGM exporter dashboard is ID 12239 on grafana.com.

What to read:

| Question | Metric |
| --- | --- |
| Is the GPU busy? | `DCGM_FI_PROF_GR_ENGINE_ACTIVE` (better than `DCGM_FI_DEV_GPU_UTIL`, which only means "a kernel was running") |
| Are tensor cores used? | `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE` |
| Memory-bandwidth bound (decode)? | `DCGM_FI_PROF_DRAM_ACTIVE` |
| Memory headroom | `DCGM_FI_DEV_FB_USED`, `DCGM_FI_DEV_FB_FREE` (discrete GPUs only, see below) |
| Thermal / power | `DCGM_FI_DEV_GPU_TEMP`, `DCGM_FI_DEV_POWER_USAGE` |
| Hardware faults | `DCGM_FI_DEV_XID_ERRORS` (last XID value; non-zero means investigate) |

Note: engines pre-allocate most GPU memory for KV cache (vLLM `--gpu-memory-utilization`), so FB used near 90%+ is normal and not an alert. Use the engine's KV-cache usage metric for real pressure.

### nvidia-smi for quick checks

```bash
nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv
nvidia-smi dmon -s pucm      # rolling power/util/clock/memory view; Ctrl-C to stop
```

## Operating

- Collection cadence: `--collect-interval` in milliseconds (default 30000). A Prometheus scrape reads the latest cached sample, so scraping faster than the collect interval just repeats values.
- Changing the collector CSV reloads metric selection (file watch or SIGHUP); changing the YAML config requires a restart. Restarts reset exporter-owned counters.
- `--kubernetes` adds `pod`, `namespace` and `container` labels; enable only labels your queries use, each label set is another series.

## Tuning knobs worth knowing

- `--collectors <csv>` / `-f`: field selection.
- `-a <addr>`: listen address (default `:9400`).
- `-r <host:port>`: use a separately managed DCGM host engine instead of the embedded one.
- `--devices`: select GPUs / MIG instances.
- `--web-config-file`: TLS/basic auth; required before enabling `--enable-pprof`.

## Unified memory: DGX Spark / GB10 and other iGPU systems

- DGX Spark uses a unified memory architecture: the GPU shares system DRAM with the CPU. There is no dedicated framebuffer.
- NVIDIA documents that `nvidia-smi` shows **"Memory-Usage: Not Supported"** on these iGPU platforms even though per-process GPU memory is listed. This is expected.
- `cudaMemGetInfo` underestimates allocatable memory because it does not account for pages the OS could reclaim to swap. Tools that rely on it (some engines' memory planners) can under-size KV cache.
- Whether DCGM `DCGM_FI_DEV_FB_*` fields report meaningful values on GB10 is **unverified**. Treat them as untrusted until you compare them with host memory.
- Monitor memory with host metrics instead: node_exporter `node_memory_MemAvailable_bytes` and `node_memory_SwapFree_bytes` (from `/proc/meminfo` `MemAvailable` / `SwapFree`, which is what NVIDIA's guidance uses), or `llamaswap_memory_used_bytes` / `llamaswap_swap_used_bytes`.
- For DGX-specific dashboards, the `self-hosted-llms` skill's sparkDash reference covers it; this skill stays generic.

## Known pitfalls

- **`DCGM_FI_DEV_GPU_UTIL` at 100% ≠ saturated**; it is time-based. Use `DCGM_FI_PROF_GR_ENGINE_ACTIVE` and tensor/DRAM activity.
- **Profiling fields missing**: container lacks `SYS_ADMIN`, or another profiler (Nsight) holds the counters.
- **Exporter up, no `DCGM_` metrics**: driver/DCGM mismatch or GPUs not visible to the container (`--gpus all`, NVIDIA container toolkit).
- **Alerting on FB used**: engines reserve memory up front; alert on engine KV-cache usage or OOM/restart instead.
- **Port 9400 exposed publicly** leaks host and workload details; restrict it.

## Official links

- DCGM exporter docs: https://docs.nvidia.com/datacenter/dcgm/latest/gpu-telemetry/dcgm-exporter.html
- DCGM exporter repo: https://github.com/NVIDIA/dcgm-exporter
- Default counters: https://github.com/NVIDIA/dcgm-exporter/blob/main/etc/default-counters.csv
- Grafana dashboard 12239: https://grafana.com/grafana/dashboards/12239
- DGX Spark known issues (memory reporting on UMA): https://docs.nvidia.com/dgx/dgx-spark/known-issues.html
- nvidia-smi: https://docs.nvidia.com/deploy/nvidia-smi/index.html
