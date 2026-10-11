# Aphrodite Engine

Install, serve and tune Aphrodite Engine (now branded Sonar), the vLLM-derived LLM inference server with OpenAI, Anthropic and Kobold-compatible APIs. Covers the pinned uv install and source builds for other platforms, serve flags and YAML config, memory and scheduler tuning, tensor, pipeline, data and expert parallelism, multi-node without Ray, speculative decoding, quantization formats, LoRA, multimodal limits, security, metrics, upgrades and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill aphrodite-engine
```

## Rules

- **Pin everything.** Package version, model and tokenizer commits, PyTorch and CUDA stack.
- **Keys from the environment.** `APHRODITE_API_KEY` and `HF_TOKEN` from `0600` files, not `--api-key`.
- **Keep `/metrics` and admin routes private.** `--api-key` is not a network boundary.
- **Memory fraction is of total GPU memory.** Lower `--gpu-memory-utilization` when sharing a GPU.
- **Ask before** installs, services, exposure, `--trust-remote-code` and upgrades.

## References

- [`references/install.md`](references/install.md): rename, platforms, uv, installer, source, Docker.
- [`references/serve-config.md`](references/serve-config.md): flags, YAML, environment variables.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): parallelism, multi-node, Ray security.
- [`references/features.md`](references/features.md): tools, speculation, quantization, LoRA, multimodal.
- [`references/api.md`](references/api.md): routes, auth, security.
- [`references/performance-tuning.md`](references/performance-tuning.md): benchmarks, tuning, Rust frontend.
- [`references/observability.md`](references/observability.md): health, metrics, logs, shutdown.
- [`references/updating.md`](references/updating.md): upgrade and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/`](templates): `serve.yaml`, `aphrodite.service`.

## Companion skills

- `choosing-inference-engine`: Aphrodite vs vLLM vs SGLang vs llama.cpp.
- `vllm`: the upstream engine.
- `choosing-hardware`: GPU memory and context sizing.
- `litellm`: keys, routing, fallbacks.

## License

MIT
