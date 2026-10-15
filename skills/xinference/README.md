# Xinference

Install, serve and operate Xorbits Inference (Xinference), the Python model server and cluster for LLM, embedding, rerank, image, audio and video models behind OpenAI, Responses and Anthropic compatible APIs. Covers the uv installer, pip, Docker, Compose and Helm, vLLM, SGLang, llama.cpp and MLX engines, per-model virtual environments, auth and API keys, replicas, supervisor and worker clusters, Xavier KV sharing, P/D separation, reload, metrics, upgrades and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill xinference
```

## Rules

- **Auth is on by default.** Create the admin once with `POST /v1/admin/setup`, then use API keys from `0600` files.
- **Pin versions.** Server, workers, `xinference-client` and the Docker tag move together.
- **Bind loopback or a private network.** Metrics and the setup route are not behind the API key system.
- **Discover before acting.** `xinference engine`, `registrations` and `cal-model-mem` are read-only.
- **Ask before** installs, services, exposure, auth changes and upgrades.

## References

- [`references/install.md`](references/install.md): installer, pip, Docker, Helm, services.
- [`references/serve-config.md`](references/serve-config.md): CLI, launch options, environment variables.
- [`references/models-and-engines.md`](references/models-and-engines.md): engines, formats, custom models, virtualenvs.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): replicas, clusters, Xavier, P/D.
- [`references/features.md`](references/features.md): tools, reasoning, Responses, Anthropic, media.
- [`references/api-and-auth.md`](references/api-and-auth.md): endpoints, users, permissions, keys.
- [`references/performance-tuning.md`](references/performance-tuning.md): batching, memory, caches.
- [`references/integrations.md`](references/integrations.md): LiteLLM, clients, proxies, Kubernetes.
- [`references/observability.md`](references/observability.md): health, metrics, logs.
- [`references/updating.md`](references/updating.md): upgrade and breaking changes.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/`](templates): `docker-compose.yml`, `launch.sh`.

## Companion skills

- `choosing-inference-engine`: Xinference vs vLLM vs SGLang vs llama.cpp.
- `vllm`, `sglang`, `llama-cpp`: the engines underneath.
- `litellm`: keys, routing, fallbacks.
- `llama-swap`: on-demand swapping alternative.

## License

MIT
