# Combo: DCGM metrics as KEDA triggers

> Verified against NVIDIA GPU Operator v26.7.1 (DCGM exporter) and KEDA v2.21.0 (Prometheus scaler), 2026-10-11

DCGM exporter metrics reach Prometheus (ServiceMonitor or scrape annotation); a KEDA `ScaledObject` with a Prometheus trigger
can scale a model Deployment on them. For LLM serving prefer the engine's own signals (`vllm:num_requests_waiting`) as the
primary trigger and use GPU memory or engine activity from DCGM as a guard, because `GPU_UTIL` stays high at any non-zero load.

Pod-count scaling is capped by GPU nodes: pending pods need node scaling (cluster autoscaler or Karpenter) and, with
the GPU Operator, the new node must finish driver install before `nvidia.com/gpu` appears; precompiled driver containers shorten that.

Trigger syntax and examples: skill `keda`.
