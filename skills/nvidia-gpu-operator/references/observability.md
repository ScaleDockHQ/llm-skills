# Observability: DCGM exporter and node signals

> Verified against NVIDIA GPU Operator v26.7.1 (docs `getting-started`, `troubleshooting`) and dcgm-exporter v4.8.4 default counters, 2026-10-11

## DCGM exporter

Deployed by default (`dcgmExporter.enabled=true`) as a DaemonSet; it starts its own embedded DCGM unless a standalone
`nvidia-dcgm` is deployed (then it connects to `nvidia-dcgm:5555` and NetworkPolicies must allow it). Metrics on `/metrics`
(port 9400 by default in dcgm-exporter; confirm on your Service).

```bash
kubectl get svc,ds -n gpu-operator | grep -i dcgm
kubectl -n gpu-operator port-forward svc/nvidia-dcgm-exporter 9400:9400 &
curl -s localhost:9400/metrics | grep -E '^DCGM_FI_DEV_(GPU_UTIL|FB_USED|FB_FREE|POWER_USAGE|GPU_TEMP|XID_ERRORS)' | head
```

Default counters (dcgm-exporter 4.8.4) include `DCGM_FI_DEV_GPU_UTIL`, `DCGM_FI_DEV_MEM_COPY_UTIL`, `DCGM_FI_DEV_FB_USED`,
`DCGM_FI_DEV_FB_FREE`, `DCGM_FI_DEV_POWER_USAGE`, `DCGM_FI_DEV_GPU_TEMP`, `DCGM_FI_DEV_SM_CLOCK`, `DCGM_FI_DEV_XID_ERRORS`,
`DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL`, and profiling counters `DCGM_FI_PROF_GR_ENGINE_ACTIVE`, `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE`,
`DCGM_FI_PROF_DRAM_ACTIVE`, `DCGM_FI_PROF_PCIE_TX_BYTES`/`RX_BYTES`. Labels include `gpu`, `UUID`, `modelName`, `Hostname`;
`dcgmExporter.enablePodLabels=true` adds pod labels (limit with `podLabelAllowlistRegex` to avoid cardinality
explosions). Pod attribution does not work with time-slicing. Details and custom counters: skill `dcgm-exporter`.

## LLM-relevant queries

- GPU memory pressure: `DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)`.
- Real compute use: `DCGM_FI_PROF_GR_ENGINE_ACTIVE` and tensor pipe activity track serving load better than `GPU_UTIL`.
- Health: `DCGM_FI_DEV_XID_ERRORS` non-zero; the device plugin also marks GPUs with critical Xids unhealthy, lowering
  allocatable `nvidia.com/gpu`.
- Pair with the engine's own metrics (vLLM queue and KV usage) for scaling decisions: skill `keda`.

## Node and operator signals

```bash
kubectl get clusterpolicy -o jsonpath='{.items[0].status.state}{"\n"}'
kubectl describe node <node> | sed -n '/Allocatable:/,/pods:/p'
kubectl get node <node> -L nvidia.com/gpu.product -L nvidia.com/gpu.count -L nvidia.com/mig.config.state
kubectl get events -n gpu-operator --sort-by=.lastTimestamp | tail -20
```

The operator's Node Status Exporter raises `GPUOperatorNodeDeploymentFailed`-style alerts (v26.7.1 fixed false positives when the
device plugin is disabled). Prometheus Operator integration is available through chart values for the exporter's ServiceMonitor; read
`helm show values` for the exact keys of your version.
