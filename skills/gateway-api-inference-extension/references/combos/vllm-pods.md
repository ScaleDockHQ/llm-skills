# Combo: vLLM pods behind the inference gateway

> Verified against vLLM v0.31.0 metrics names (skill `vllm`), Gateway API Inference Extension v1.6.2 model server protocol and llm-d router v0.11.0, 2026-10-11

- One Deployment per base model, label it (for example `app: vllm-qwen3-32b`), and set the chart's
  `router.modelServers.matchLabels` to that label. Use `templates/vllm-deployment.yaml`.
- Enable automatic prefix caching (default on in vLLM V1) and keep `--served-model-name` identical on all replicas and equal to the
  `model` your clients send.
- LoRA: all adapters of a base model live in one pool; each replica loads adapters at runtime
  (`--enable-lora`); the EPP reads `vllm:lora_requests_info`.
- Probes: readiness on `/health` with a long `initialDelaySeconds`/`failureThreshold` (model load is slow); a pod that is
  Ready but still compiling kernels would be picked by the EPP.
- Metrics: `/metrics` is on the API port; `/metrics` and `/health` are not covered by `--api-key`.
- Scaling the Deployment: HPA or KEDA on `vllm:num_requests_waiting` (skill `keda`); the EPP discovers new pods on its own.
- Disaggregated P/D: separate prefill and decode Deployments plus the router's sidecar (`references/epp-and-routing.md`).
