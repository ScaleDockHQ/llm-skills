# AIBrix

Teaches an agent to install and operate AIBrix on Kubernetes: the vLLM project's control plane with an Envoy-based
gateway and LLM-aware routing, PodAutoscaler, LoRA ModelAdapter, StormService prefill/decode and multi-node, and KV
cache offload. Verified against v0.7.0.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill aibrix
```

## Rules

- **Ask before cluster-wide changes.** The dependency manifest installs Envoy Gateway and more.
- **Names must match.** Service, `model.aibrix.ai/name`, `--served-model-name` and the request `model`.
- **Pin the release** (`v0.7.0`), not nightly.
- **Protect the endpoint** with engine API keys from Secrets; enable Redis state sync for several gateways.
- **Check sample image provenance** before applying KV cache and P/D samples.

## References

- [`references/install.md`](references/install.md): manifests, Helm, controllers, uninstall.
- [`references/model-deployment.md`](references/model-deployment.md): labels, runtime sidecar, routing profile.
- [`references/gateway-and-routing.md`](references/gateway-and-routing.md): strategies, headers, rate limits, Redis.
- [`references/autoscaling.md`](references/autoscaling.md): PodAutoscaler HPA, KPA, APA.
- [`references/features.md`](references/features.md): LoRA, StormService, Ray fleets, KV cache.
- [`references/updating.md`](references/updating.md), [`references/troubleshooting.md`](references/troubleshooting.md).
- [`templates/`](templates/): model and autoscaler manifests.

## Companion skills

- `vllm`: engine flags. `npx skills add ScaleDockHQ/llm-skills --skill vllm`
- `vllm-production-stack`: Helm alternative. `npx skills add ScaleDockHQ/llm-skills --skill vllm-production-stack`
- `llm-d`: scheduler-based alternative. `npx skills add ScaleDockHQ/llm-skills --skill llm-d`

## License

MIT
