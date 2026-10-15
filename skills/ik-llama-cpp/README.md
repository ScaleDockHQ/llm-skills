# ik_llama.cpp

Agent skill for building, serving and tuning ik_llama.cpp, the llama.cpp fork by Iwan Kawrakow with IQK and trellis quants, faster CPU inference, hybrid CPU/GPU MoE offload (`--fit`, `--n-cpu-moe`, `-ot`), split-mode graph multi-GPU, MTP and self-speculative decoding, and an OpenAI-compatible `llama-server`.

Verified against ik_llama.cpp `main` (89bba35c, the project has no tagged releases) on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill ik-llama-cpp
```

## Rules

- **Ask before changing the system.** Builds, installs, services and exposure need approval.
- **Secrets never touch output.** Use `--api-key-file` or env vars, never inline keys.
- **Loopback by default.** Never expose the server to the Internet.
- **No `-rtr` on hybrid MoE runs.** It forces matmuls onto the CPU.
- **Only CPU and CUDA are supported backends.** ROCm, Vulkan and Metal are not maintained upstream.
- **Pin the commit or image digest.** There are no releases.

## References

- [`references/install.md`](references/install.md): images, CMake, AVX-512, Windows, bake.
- [`references/serve-config.md`](references/serve-config.md): `llama-server` flags and env vars.
- [`references/models-and-formats.md`](references/models-and-formats.md): IQK, trellis quants, compatibility.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): hybrid offload, graph split, RPC.
- [`references/features.md`](references/features.md): tools, reasoning, vision, speculative, MTP.
- [`references/api.md`](references/api.md): endpoints.
- [`references/performance-tuning.md`](references/performance-tuning.md): KV cache, fused ops, benchmarks.
- [`references/integrations.md`](references/integrations.md): LiteLLM, clients, containers.
- [`references/observability.md`](references/observability.md): health, metrics, slots.
- [`references/updating.md`](references/updating.md): update and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/combos/llama-swap.md`](references/combos/llama-swap.md): the upstream swap image.
- [`templates/`](templates): compose, systemd and llama-swap templates.

## Companion skills

- `llama-cpp`: mainline llama.cpp.
- `choosing-inference-engine`: compare engines.
- `llama-swap`, `litellm`: swapping and gateway.
- `self-hosted-llms`: the full self-hosted stack.

## License

MIT
