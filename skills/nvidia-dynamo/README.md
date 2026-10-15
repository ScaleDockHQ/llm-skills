# NVIDIA Dynamo Skill

An agent skill for deploying [NVIDIA Dynamo](https://github.com/ai-dynamo/dynamo), the open-source datacenter-scale inference stack that orchestrates vLLM, SGLang and TensorRT-LLM workers behind an OpenAI-compatible frontend. It walks an AI coding agent through a local install, the Kubernetes platform and `DynamoGraphDeployment` manifests, disaggregated prefill/decode, KV-aware routing, the Planner and DGDR, observability, upgrades and the common failures. Every command is read-only first and never prints secrets. Verified against Dynamo v1.5.1 (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill nvidia-dynamo
```

## Rules

- **Start aggregated**, then add KV routing, then disaggregation; one change at a time.
- **Pin one release** for images, wheel and Helm chart; never `latest`.
- **The frontend has no auth.** Keep it private or behind a gateway.
- **File discovery is single-machine only** and disables KV events, routing and the Planner.
- **Disaggregation needs RDMA** in production; TCP fallback is far slower.
- **Secrets never touch output.** `HF_TOKEN` comes from the environment or a Kubernetes Secret.

## References

- [`references/install.md`](references/install.md): requirements, containers, wheels, Kubernetes platform, discovery modes.
- [`references/serve-config.md`](references/serve-config.md): frontend, router and worker flags and env vars.
- [`references/models-and-formats.md`](references/models-and-formats.md): models, recipes, weights on Kubernetes.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): disaggregation, DGD, DGDR, Grove, RDMA.
- [`references/features.md`](references/features.md): backend support matrix, KV routing, KVBM, Planner, fault tolerance.
- [`references/api.md`](references/api.md): endpoints, Anthropic API, KServe gRPC, `nvext`.
- [`references/performance-tuning.md`](references/performance-tuning.md): AIPerf, AIConfigurator, tuning order.
- [`references/integrations.md`](references/integrations.md): LiteLLM, GAIE, agents, Kubernetes ecosystem.
- [`references/observability.md`](references/observability.md): metric families, ports, tracing.
- [`references/updating.md`](references/updating.md): upgrade procedure and v1.5.1 changes.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

Templates: [`templates/docker-compose.yml`](templates/docker-compose.yml), [`templates/dgd-agg.yaml`](templates/dgd-agg.yaml), [`templates/dgd-disagg-router.yaml`](templates/dgd-disagg-router.yaml), [`templates/dgdr-rapid.yaml`](templates/dgdr-rapid.yaml).

## Companion skills

From [ScaleDockHQ/llm-skills](https://github.com/ScaleDockHQ/llm-skills); install any of them with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `vllm`, `sglang`, `tensorrt-llm`: the engines Dynamo drives.
- `disaggregated-serving`, `multi-node-inference`: technique-level guidance.
- `choosing-inference-engine`, `litellm`, `llm-gateway`, `llm-observability`.
