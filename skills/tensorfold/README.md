# TensorFold

Helps an agent install, serve, tune, scale out, update and troubleshoot [TensorFold](https://github.com/ashhart/TensorFold) (`tensorfold`, `tensorfold-native`), a Zig inference engine for Apple Silicon (Metal) and NVIDIA GPUs (CUDA) with exact speculative decoding. It is a young project with a short qualified-model list, so the skill is strict about what is verified: the native 1.0.x binary versus the Python 0.6.6 line versus community MiaAI-Lab DGX Spark recipes.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill tensorfold
```

## Rules

- **Qualified pairs only.** Do not claim a model or platform works unless upstream's table says so.
- **Explicit `--port`, `--name`, `--host`.** The default `127.0.0.1:8080` collides with common gateways.
- **Keys from `0600` files.** Never `--api-key` on a command line.
- **Living Weights rewrites the model folder.** Teach a copy only.
- **Recipes are upstream-owned.** Follow them; do not copy their defaults into your stack.

## References

- [`references/install.md`](references/install.md): macOS, Linux CUDA, legacy Python line, source build.
- [`references/serve-config.md`](references/serve-config.md): serve flags, env vars, auth.
- [`references/models-and-formats.md`](references/models-and-formats.md): qualified matrix and formats.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): lanes, two Macs, two Sparks.
- [`references/features.md`](references/features.md): exactness, prompt cache, compaction, Living Weights, vision.
- [`references/api.md`](references/api.md): routes and request fields.
- [`references/performance-tuning.md`](references/performance-tuning.md): memory, context, cache, thermals.
- [`references/integrations.md`](references/integrations.md): llama-swap, LiteLLM, clients, systemd.
- [`references/observability.md`](references/observability.md): health, metrics, dashboard.
- [`references/updating.md`](references/updating.md): upgrade and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/combos/miaai-lab-recipes.md`](references/combos/miaai-lab-recipes.md): community Spark recipes.
- [`references/combos/dgx-spark-dual.md`](references/combos/dgx-spark-dual.md): two DGX Sparks.
- [`templates/`](templates/): systemd unit, llama-swap entry.

## Companion skills

- `nvidia-dgx-spark`: GB10 hardware and networking.
- `llama-swap`: model swapping.
- `litellm`: gateway.
- `self-hosted-llms`: engine choice and stack.
- `multi-node-inference`, `speculative-decoding`: general concepts.

## License

MIT
