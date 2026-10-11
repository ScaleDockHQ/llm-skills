# llama.cpp

Agent skill for installing, serving, tuning, scaling out, updating and troubleshooting llama.cpp (`llama-server`, `llama-cli`, `llama-bench`, `llama-quantize`, `llama-perplexity`, `llama-imatrix`) for GGUF models. It covers Homebrew, winget, release archives (`bNNNN` build tags), the `ghcr.io/ggml-org/llama.cpp` Docker images and CMake builds for Metal, CUDA, Vulkan, ROCm/HIP, SYCL and CPU, including aarch64, Blackwell and DGX Spark. Topics: `-hf` downloads, GGUF quant types, imatrix, KV cache types, flash attention, router mode and presets, tool calling with `--jinja`, reasoning flags, JSON schema and grammars, multimodal (`mmproj`), embeddings and rerank, speculative decoding, RPC multi-node, metrics and updating. Absorbs and deepens the earlier llama.cpp notes from `self-hosted-llms` and `local-llms`.

Flags and defaults were verified against llama.cpp master build b11556 and the v0.6.0 release on 2026-10-11. The default `llama-server` port is 9931 on master (8080 on v0.6.0 and older).

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill llama-cpp
```

## Rules

- **Ask before changing the system.** Installs, services, network exposure and compiling on a serving host need approval.
- **Secrets never touch output.** Use `--api-key-file` (mode `0600`) or `LLAMA_API_KEY`, and `HF_TOKEN` from the environment.
- **Always pass `--host` and `--port`.** `/health` is public and the default port changed.
- **Loopback by default.** Experimental tools/MCP flags and the RPC server are unsafe on untrusted networks.
- **Pin and smoke-test.** Record the build or image digest and test chat, tool calls and reasoning after every update.

## References

- [`references/install.md`](references/install.md): package managers, release archives, Docker images, CMake builds per backend.
- [`references/serve-config.md`](references/serve-config.md): flags, `LLAMA_ARG_*` env vars, router mode and presets, auth, services.
- [`references/models-and-formats.md`](references/models-and-formats.md): GGUF, quant types, conversion, `llama-quantize`, imatrix, perplexity/KLD, LoRA.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): multi-GPU split modes, MoE offload, RPC across hosts.
- [`references/features.md`](references/features.md): tools, reasoning, structured output, multimodal, embeddings, speculative decoding.
- [`references/api.md`](references/api.md): endpoints and request examples.
- [`references/performance-tuning.md`](references/performance-tuning.md): fit, KV types, batches, backend env vars, benchmarking.
- [`references/integrations.md`](references/integrations.md): clients, llama-swap, gateways, Kubernetes.
- [`references/observability.md`](references/observability.md): health, Prometheus metrics, logs.
- [`references/updating.md`](references/updating.md): update paths, pinning, rollback, smoke tests.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/combos/apple-metal.md`](references/combos/apple-metal.md), [`references/combos/strix-halo-vulkan.md`](references/combos/strix-halo-vulkan.md), [`references/combos/llama-swap-router.md`](references/combos/llama-swap-router.md): verified combinations.
- [`templates/`](templates/): systemd unit, launchd plist, Docker Compose, Kubernetes manifest, router preset INI.
- [`scripts/bench.sh`](scripts/bench.sh): shared end-to-end HTTP benchmark.

## Companion skills

- `choosing-inference-engine`: llama.cpp versus vLLM, SGLang and TensorRT-LLM.
- `model-quantization`: GGUF versus AWQ, GPTQ and FP8.
- `llm-gateway`, `litellm`: put a gateway in front.
- `local-llms`, `self-hosted-llms`: the workflow skills this one deepens.
- `llama-swap`, `nvidia-dgx-spark`, `amd-strix-halo`, `speculative-decoding`, `multi-node-inference`: planned neighbours.

## License

MIT
