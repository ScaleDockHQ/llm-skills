# ExLlamaV3

Agent skill for running ExLlamaV3 (the EXL3 quantization format and inference library) and its recommended server TabbyAPI: install on Docker, wheels, source, ROCm and DGX Spark (aarch64), configure `config.yml`, load and unload models over the API, tensor and expert parallel, KV cache quantization, speculative decoding, tool calling, updating and troubleshooting.

Verified against ExLlamaV3 v1.6.1 and TabbyAPI `main` on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill exllamav3
```

## Rules

- **Ask before changing the system.** Installs, services and exposure need approval.
- **Secrets never touch output.** TabbyAPI keys stay in `api_tokens.yml` (`0600`) or env vars.
- **Auth off means loopback only**, with `allowed_origins` restricted.
- **Keep `--shm-size=8g`** in containers; pin image digests because TabbyAPI is a rolling release.

## References

- [`references/install.md`](references/install.md): Docker, wheels, start scripts, source, ROCm, aarch64 and the MiaAI-Lab fork.
- [`references/serve-config.md`](references/serve-config.md): `config.yml`, auth, per-model `tabby_config.yml`.
- [`references/models-and-formats.md`](references/models-and-formats.md): EXL3 bitrates, sizing, architectures, downloading.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): multi-GPU, MoE offload, cache tiers.
- [`references/features.md`](references/features.md): tool calling, reasoning, vision, LoRA, embeddings.
- [`references/api.md`](references/api.md): endpoints and model loading.
- [`references/performance-tuning.md`](references/performance-tuning.md): KV cache, batching, drafting.
- [`references/integrations.md`](references/integrations.md): llama-swap, LiteLLM, clients, Kubernetes.
- [`references/observability.md`](references/observability.md): health, logs, timings.
- [`references/updating.md`](references/updating.md): update and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`templates/`](templates): compose, config, systemd and Kubernetes templates.

## Companion skills

- `choosing-inference-engine`: compare engines.
- `self-hosted-llms`: the full self-hosted stack.
- `llama-swap`, `litellm`: swapping and gateway in front of TabbyAPI.
- `nvidia-dgx-spark`: GB10 host specifics.
- `model-quantization`, `exl3-quantization` (planned): formats and deep EXL3 conversion.

## License

MIT
