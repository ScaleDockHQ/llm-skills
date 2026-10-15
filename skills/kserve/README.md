# KServe

Install and operate KServe on Kubernetes for LLMs and classic models: `LLMInferenceService` (llm-d based scheduler routing, prefill/decode, multi-node, WVA autoscaling, canary groups) and `InferenceService` with the Hugging Face vLLM runtime, storage containers, LocalModelCache and KEDA. Covers the install matrix (Helm OCI charts, kustomize, release scripts), dependencies, upgrades and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill kserve
```

## Rules

- **Ask before cluster-wide changes.** CRDs, gateways and controllers affect every namespace.
- **Check chart tags first.** At verification time no plain `v0.21.0` OCI chart existed, only `v0.21.0-rc1`.
- **Use `v1alpha2`** for `LLMInferenceService`.
- **Secrets from `0600` files**, never literals or committed manifests.

## References

- [`references/install.md`](references/install.md): components, dependencies, Helm, kustomize, scripts.
- [`references/llminferenceservice.md`](references/llminferenceservice.md): spec, composition, scheduler, parallelism, status.
- [`references/inferenceservice-huggingface.md`](references/inferenceservice-huggingface.md): HF runtime, multi-node, KEDA.
- [`references/scaling-and-rollout.md`](references/scaling-and-rollout.md): WVA, canary, LocalModelCache, LoRA, KV offloading.
- [`references/integrations.md`](references/integrations.md): LiteLLM, Envoy AI Gateway, metrics, security.
- [`references/updating.md`](references/updating.md): upgrade notes and order.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/`](templates): `LLMInferenceService` and `InferenceService` manifests.

## Companion skills

- `llm-d`, `vllm-production-stack`: related Kubernetes serving stacks.
- `vllm`: engine flags. `litellm`: gateway in front. `cloud-llms`: hosting choices.

## License

MIT
