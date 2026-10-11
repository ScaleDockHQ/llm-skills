# Combo: KEDA with the inference gateway (GAIE, llm-d)

> Verified against KEDA v2.21.0, 2026-10-11

With `gateway-api-inference-extension` an InferencePool selects the model-server pods and an endpoint picker (EPP)
routes by queue depth and KV-cache use. The pool's pods are still a normal Deployment, so KEDA scales that
Deployment; the pool picks up new endpoints by label selector.

- Scale on the engine metrics of the pool's pods (`references/llm-triggers.md`), not on the EPP's own metrics, unless you
  verified an EPP/gateway metric that tracks pool load. The EPP's metric names change between versions; list them from
  its `/metrics` first.
- A gateway or EPP metric that survives zero pods can drive 0 to 1 (`references/scale-to-zero.md`), but the gateway must
  hold or retry requests while the pool is empty. Verify that behavior on your gateway before promising scale to zero.
- Scale-in drops prefix caches the EPP was exploiting: slow `scaleDown` (`references/scaledobject-tuning.md`).
- llm-d with KServe: skill `vllm-kserve-keda` (`LLMInferenceService` `spec.scaling.keda`) and `llm-d-vllm-kubernetes`.
