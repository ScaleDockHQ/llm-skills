# vLLM on KServe with KEDA

Helps an agent deploy a vLLM model on Kubernetes with KServe in Standard mode and autoscale it with KEDA from vLLM's Prometheus metrics. It covers `InferenceService` with a pinned vLLM runtime, the `LLMInferenceService` direct-KEDA option, install paths, version pins, load-test calibration, troubleshooting and teardown.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill vllm-kserve-keda
```

## Rules

- **Ask before changing the cluster.** Installs, CRDs, runtimes and GPU workloads need approval and an undo path.
- **Standard mode for KEDA.** One autoscaler per component; never add a second HPA.
- **Pin and verify.** KServe's bundled runtimes use older or floating vLLM tags, and its website lags the code. Check `kubectl explain` first.
- **Calibrate, do not copy.** Metric targets and replica limits come from a load test.
- **No secrets in output.** Tokens live in Secrets built from `0600` files.

## References

- [`references/install.md`](references/install.md): versions, install paths, token Secret, pinned vLLM runtime.
- [`references/inferenceservice-keda.md`](references/inferenceservice-keda.md): InferenceService manifest, Prometheus trigger, verification.
- [`references/llminferenceservice-keda.md`](references/llminferenceservice-keda.md): LLMInferenceService direct KEDA, prefill scaling, WVA status.
- [`references/tuning-and-troubleshooting.md`](references/tuning-and-troubleshooting.md): thresholds, cooldowns, failure table, teardown.

## Companion skills

- `kserve`, `keda`, `vllm`: component depth. `llm-d` and `keda` are published.
- `llm-d-vllm-kubernetes`: llm-d router with vLLM outside KServe.
- `prometheus-grafana-llm`, `nvidia-gpu-operator`, `llm-evals`, `self-hosted-llms`.

## License

MIT
