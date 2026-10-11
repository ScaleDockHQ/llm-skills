# Dynamo with TensorRT-LLM, disaggregated

Helps an agent deploy TensorRT-LLM prefill and decode as separate NVIDIA Dynamo workers on Kubernetes: platform install, `DynamoGraphDeployment` templates and engine YAMLs, NIXL KV transfer over RDMA, the KV-aware router, Planner scaling and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill dynamo-trtllm-disaggregated
```

## Rules

- **Ask before changing the cluster.** CRDs, operators, GPU pods and privileged containers need approval and an undo path.
- **Measure aggregated first.** Keep that deployment until the split wins on your workload and passes a quality check.
- **Know the pins.** Dynamo 1.5.1 bundles a TRT-LLM release candidate; pin images and keep both roles on one tag.
- **RDMA or accept the cost.** TCP fallback makes TTFT collapse.
- **No secrets in output.** The HF token Secret comes from a `0600` file.

## References

- [`references/install-platform.md`](references/install-platform.md): GPU operator, chart, Grove or LWS, uninstall.
- [`references/deploy-disagg.md`](references/deploy-disagg.md): aggregated baseline, disaggregated DGD, multinode.
- [`references/kv-transfer-and-networking.md`](references/kv-transfer-and-networking.md): `cache_transceiver_config`, NIXL, RDMA, EFA, GB200.
- [`references/routing-scaling-ops.md`](references/routing-scaling-ops.md): KV router, Planner, failure table, gaps.

## Companion skills

- `nvidia-dynamo` (install later if not yet listed), `tensorrt-llm`, `disaggregated-serving`, `multi-node-inference`, `prefix-aware-routing`.
- `nccl-rdma-networking`, `nvidia-gpu-operator`, `llm-evals`, `choosing-hardware`.

## License

MIT
