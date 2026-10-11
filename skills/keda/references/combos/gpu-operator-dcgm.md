# Combo: KEDA with the NVIDIA GPU Operator and DCGM

> Verified against KEDA v2.21.0, 2026-10-11

The GPU Operator (skill `nvidia-gpu-operator`) deploys dcgm-exporter; `dcgm-exporter` (skill) covers metrics in depth.
KEDA reads those metrics through Prometheus.

```bash
kubectl get pods -n gpu-operator | grep -i dcgm          # exporter running on GPU nodes
kubectl get servicemonitor -A | grep -i dcgm             # enable serviceMonitor in the operator values if absent
```

- Prometheus must scrape the exporter (ServiceMonitor, label selection depends on your Prometheus install).
- Pod-level labels (`pod`, `namespace`) are present when the exporter maps metrics to Kubernetes pods; confirm with a
  query before writing the trigger.
- Use `DCGM_FI_DEV_GPU_UTIL` as a secondary or idle signal only (`references/llm-triggers.md`). KV-cache and waiting
  requests from the engine track LLM load better than GPU utilization.
- KEDA scales pods; new GPU pods need free GPUs. GPU capacity comes from nodes (cluster autoscaler or manual), time-slicing
  or MIG (skill `nvidia-gpu-operator`).
