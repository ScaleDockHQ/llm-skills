# llm-d with vLLM on Kubernetes

Helps an agent deploy vLLM behind the llm-d router (endpoint picker on Gateway API Inference Extension) on Kubernetes: the optimized baseline with cache-aware and load-aware routing, optional prefill/decode pools over NIXL, and KEDA autoscaling from router metrics.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill llm-d-vllm-kubernetes
```

## Rules

- **Ask before changing the cluster.** CRDs, Helm releases and GPU workloads need approval and an undo path.
- **Pin and preview.** Clone llm-d at `v0.10.0`, pin charts, run `kubectl kustomize` to catch placeholder or floating images.
- **Calibrate for your hardware.** Replica counts, TP and `peakPrefillThroughput` are for the reference setup.
- **Baseline before split.** Keep the aggregated deployment until the P/D numbers and a quality check pass.
- **No secrets in output.** The HF token Secret comes from a `0600` file.

## References

- [`references/install-baseline.md`](references/install-baseline.md): CRDs, router chart, model servers, verification, cleanup.
- [`references/pd-disaggregation.md`](references/pd-disaggregation.md): P/D guide, NIXL settings, scale-down.
- [`references/autoscaling.md`](references/autoscaling.md): KEDA plus EPP signals, overlays, WVA status.
- [`references/troubleshooting.md`](references/troubleshooting.md): failure table and verification gaps.

## Companion skills

- `vllm`, `gateway-api-inference-extension`, `prefix-aware-routing`, `disaggregated-serving`, `kserve`: component and technique depth.
- `llm-d`, `keda`: product depth.
- `nvidia-gpu-operator`, `nccl-rdma-networking`, `prometheus-grafana-llm`, `llm-evals`.

## License

MIT
