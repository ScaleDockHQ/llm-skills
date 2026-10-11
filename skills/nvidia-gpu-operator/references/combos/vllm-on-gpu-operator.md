# Combo: vLLM pods on operator-managed GPU nodes

> Verified against NVIDIA GPU Operator v26.7.1 (docs `getting-started`) and vLLM Kubernetes guidance (skill `vllm`), 2026-10-11

- Request GPUs as `resources.limits."nvidia.com/gpu": N` (limits equal requests for extended resources). Tensor parallel size
  must equal or divide the GPUs on the pod (same node, ideally NVLink-connected).
- Add `/dev/shm` as a memory-backed `emptyDir` and `--ipc=host`-equivalent settings are not needed in Kubernetes if shm is mounted.
- Target product type with the GFD labels: `nodeSelector: {nvidia.com/gpu.product: <product label value>}` (look it up with
  `kubectl get nodes -L nvidia.com/gpu.product`); time-sliced nodes carry the `-SHARED` suffix.
- Tolerate the GPU taint your cluster uses; the operator itself does not add taints.
- Model cache on a PVC or node-local disk; the driver pod does not provide storage.
- Before the first model: run `templates/cuda-vectoradd.yaml`; if it fails the model server will too.
- Metrics: scrape the vLLM `/metrics` and DCGM exporter side by side (`references/observability.md`).
- Details for the workload: skills `vllm`, `ray-serve`; routing: `gateway-api-inference-extension`.
