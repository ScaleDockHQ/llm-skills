# Triton Inference Server Skill

An agent skill for running [NVIDIA Triton Inference Server](https://github.com/triton-inference-server/server) from a model repository. It walks an AI coding agent through picking and pinning an NGC container, laying out models and `config.pbtxt`, choosing a model-control mode, dynamic batching and instance groups, LLM serving through the vLLM and TensorRT-LLM backends and the OpenAI frontend, metrics, Kubernetes, upgrades and the common failures. Every command is read-only first and never prints secrets. Verified against Triton v2.73.0 / NGC 26.09 (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill triton-inference-server
```

## Rules

- **Never expose Triton to untrusted networks.** It has no authentication; use a gateway.
- **Model repositories are code.** Restrict writes and the load/unload API.
- **Pin the `YY.MM` container tag** and keep clients on the same release.
- **Write full configs** and use `--disable-auto-complete-config` in production.
- **Measure** with `perf_analyzer` before and after every tuning change.
- **Secrets never touch output.** Storage and Hugging Face credentials come from the environment.

## References

- [`references/install.md`](references/install.md): images, tags, flavors, source builds.
- [`references/serve-config.md`](references/serve-config.md): flags, ports, control modes, cloud repositories.
- [`references/models-and-formats.md`](references/models-and-formats.md): repository layout, backends, config.pbtxt.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): instance groups, ensembles, scaling out.
- [`references/features.md`](references/features.md): batching, decoupled models, response cache, LLM backends.
- [`references/api.md`](references/api.md): KServe v2 endpoints and clients.
- [`references/performance-tuning.md`](references/performance-tuning.md): perf_analyzer, Model Analyzer, tuning order.
- [`references/integrations.md`](references/integrations.md): Kubernetes, KServe, SageMaker, gateways.
- [`references/observability.md`](references/observability.md): Prometheus metrics, logging, tracing.
- [`references/updating.md`](references/updating.md): upgrade procedure.
- [`references/troubleshooting.md`](references/troubleshooting.md): error to fix.

Templates: [`templates/config.pbtxt`](templates/config.pbtxt), [`templates/docker-compose.yml`](templates/docker-compose.yml), [`templates/k8s-deployment.yaml`](templates/k8s-deployment.yaml).

## Companion skills

From [ScaleDockHQ/llms-skills](https://github.com/ScaleDockHQ/llms-skills); install any of them with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `vllm`, `tensorrt-llm`: the engines behind the LLM backends.
- `nvidia-dynamo`, `nvidia-nim`: LLM orchestration and packaged microservices.
- `choosing-inference-engine`, `litellm`, `llm-gateway`, `llm-observability`, `dcgm-exporter`.
