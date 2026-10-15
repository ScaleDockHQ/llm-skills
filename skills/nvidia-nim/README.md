# NVIDIA NIM Skill

An agent skill for running [NVIDIA NIM for LLMs and VLMs](https://docs.nvidia.com/nim/large-language-models/latest/), the prebuilt containers that wrap vLLM or SGLang behind an OpenAI-compatible API. It walks an AI coding agent through choosing model-specific or model-free images, selecting profiles, Docker, Helm and NIM Operator deployments, air-gapped caches, multi-node serving, tool calling, LoRA, observability, upgrades and the common failures. Every command is read-only first and never prints secrets. Verified against NIM LLM 2.0.13 (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill nvidia-nim
```

## Rules

- **Pin the image tag**; never `latest`. Take the exact tag from the Support Matrix.
- **Copy profile IDs** from `list-model-profiles`; do not build them by hand.
- **No built-in API key** is documented for `/v1`. Bind to loopback or put a gateway in front.
- **Persist the cache** on `NIM_CACHE_PATH`; use `download-to-cache` for air-gapped hosts.
- **Tool calling is opt-in**: `--enable-auto-tool-choice` plus a matching `--tool-call-parser`.
- **Secrets never touch output.** `NGC_API_KEY` and `HF_TOKEN` are forwarded with `-e NAME` or Kubernetes Secrets.

## References

- [`references/install.md`](references/install.md): requirements, images, login, air-gap, Helm, NIM Operator.
- [`references/serve-config.md`](references/serve-config.md): CLI actions, `NIM_*` variables, passthrough arguments.
- [`references/models-and-formats.md`](references/models-and-formats.md): profiles, model-free NIM, offerings.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): TP, PP, Ray, LeaderWorkerSet.
- [`references/features.md`](references/features.md): tool calling, LoRA, speculative decoding.
- [`references/api.md`](references/api.md): endpoints, authentication, Anthropic clients.
- [`references/performance-tuning.md`](references/performance-tuning.md): memory math and tuning order.
- [`references/integrations.md`](references/integrations.md): gateways, SDKs, agents, platforms.
- [`references/observability.md`](references/observability.md): logs, metrics, tracing headers.
- [`references/updating.md`](references/updating.md): upgrade procedure.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

Templates: [`templates/docker-compose.yml`](templates/docker-compose.yml), [`templates/helm-values.yaml`](templates/helm-values.yaml), [`templates/nim-operator.yaml`](templates/nim-operator.yaml).

## Companion skills

From [ScaleDockHQ/llm-skills](https://github.com/ScaleDockHQ/llm-skills); install any of them with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `vllm`, `sglang`: the backends inside the image.
- `nvidia-dynamo`, `triton-inference-server`: the other NVIDIA serving products.
- `litellm`, `llm-gateway`: auth, keys and routing in front of NIM.
- `llm-observability`: traces and cost.
