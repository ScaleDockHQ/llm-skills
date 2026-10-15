# Ollama Skill

An agent skill for installing, serving, tuning, connecting, updating and troubleshooting [Ollama](https://github.com/ollama/ollama), the local model runner with a model library, Modelfiles, a background server and REST, OpenAI-compatible and Anthropic-compatible APIs. It covers macOS, Linux (NVIDIA, AMD ROCm, Vulkan, ARM64, Jetson), Windows and Docker, the `OLLAMA_*` environment variables, context length, KV cache and flash attention, keep-alive and parallelism, GGUF and Hugging Face imports, tool calling, thinking, structured outputs, vision, embeddings, Ollama cloud models, LAN exposure and the known pitfalls. Verified against Ollama v0.40.3.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill ollama
```

## Rules

- **Ask before changing the system.** Install scripts, systemd units, `OLLAMA_HOST` changes and Docker runs need approval and an undo path.
- **The local API has no auth.** Keep it on loopback or behind a VPN, tunnel or authenticating proxy.
- **Set the context explicitly.** The default depends on VRAM (4k under 24 GiB); `/v1` cannot set it per request.
- **`ollama ps` must say `100% GPU`.** A CPU share means the model, context or parallel slots do not fit.
- **One scheduler per memory pool.** Combine with llama-swap only with fixed limits.
- **No LoRA adapters.** Merge into the base and import the merged weights.
- **Secrets never touch output.** `OLLAMA_API_KEY` and the `~/.ollama` key live in env vars or `0600` files.

## References

- [`references/install.md`](references/install.md): macOS, Linux, Windows, Docker, GPU support, version pinning, uninstall.
- [`references/serve-config.md`](references/serve-config.md): every `OLLAMA_*` variable, per-platform setup, binding, CORS, proxy.
- [`references/models-and-formats.md`](references/models-and-formats.md): CLI, library, `hf.co`, GGUF and safetensors import, Modelfile.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): scheduler, multi-GPU, instances, when to switch engines.
- [`references/features.md`](references/features.md): tools, thinking, structured outputs, vision, embeddings, cloud, web search.
- [`references/api.md`](references/api.md): native, OpenAI and Anthropic endpoints and their gaps.
- [`references/performance-tuning.md`](references/performance-tuning.md): context, KV cache, flash attention, keep-alive, offload, measuring.
- [`references/integrations.md`](references/integrations.md): `ollama launch`, LiteLLM, Open WebUI, Kubernetes, DGX Spark.
- [`references/observability.md`](references/observability.md): logs, status endpoints, debug.
- [`references/updating.md`](references/updating.md): upgrade and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom, cause, fix.
- [`references/combos/hugging-face-gguf.md`](references/combos/hugging-face-gguf.md), [`llama-swap.md`](references/combos/llama-swap.md), [`lan-and-tunnels.md`](references/combos/lan-and-tunnels.md): verified combinations.
- [`templates/`](templates/): systemd drop-in, docker-compose, Kubernetes manifest, Modelfile.

## Companion skills

- `llama-cpp`: exact engine flags and new architectures.
- `llama-swap`: model swapping in front of engines.
- `litellm`: keys, routing and budgets in front of Ollama.
- `llm-clients`: pointing agents and chat UIs at Ollama.
- `local-llms` and `self-hosted-llms`: runtime choice and the full self-hosted stack.
- `tailscale` and `cloudflare-tunnel`: private or tunnelled access.
- `nvidia-dgx-spark`: unified-memory specifics.

## License

MIT
