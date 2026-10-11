# llm-d

Deploy and operate llm-d, the CNCF distributed LLM inference stack for Kubernetes: the llm-d Router (EPP plus proxy, InferencePool) in front of vLLM, SGLang or TensorRT-LLM pools. Covers the optimized-baseline quickstart (standalone and gateway mode), precise prefix-cache routing, prefill/decode disaggregation, wide expert parallelism, tiered KV offload, flow control, KEDA autoscaling, rollouts, operations and upgrades.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill llm-d
```

## Rules

- **Ask before cluster-wide changes.** CRDs and gateways are shared state.
- **Use the release branch's guides** (`release-0.10`) and pin chart versions after sourcing `env.sh`.
- **Secrets from `0600` files**, not literals.
- **Calibrate `peakPrefillThroughput`** for hardware other than H100 TP=2 with Qwen3-32B.
- **`llm-d-cuda` is deprecated** since v0.10.0.

## References

- [`references/install.md`](references/install.md): prerequisites, versions, standalone and gateway mode.
- [`references/well-lit-paths.md`](references/well-lit-paths.md): every guide and when to pick it.
- [`references/scaling-and-rollouts.md`](references/scaling-and-rollouts.md): KEDA signals, WVA status, blue-green, adapter rollout.
- [`references/operations.md`](references/operations.md): metrics, probes, drain, router HA, startup time.
- [`references/updating.md`](references/updating.md): release notes and upgrade steps.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/`](templates): probe patch and router values override.

## Companion skills

- `vllm`, `kserve`, `vllm-production-stack`, `gateway-api-inference-extension`, `keda`, `disaggregated-serving`, `prefix-aware-routing`, `kv-cache-offloading`.

## License

MIT
