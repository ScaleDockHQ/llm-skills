# SGLang Diffusion

Install, serve, tune and troubleshoot SGLang Diffusion, the image and video generation runtime in the SGLang
project. Covers `sglang generate` and `sglang serve`, the OpenAI-style image and video routes, component offload,
sequence, tensor and CFG parallelism, caching, quantization, batching, metrics and security.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill sglang-diffusion
```

## Rules

- **Keep the loopback bind.** The diffusion server has no API key option and CORS allows all origins; front it with a gateway.
- **Use `--help` for flags.** They change between releases.
- **Tune one lever at a time**, with a fixed prompt and seed.
- **Poll video jobs**, with long timeouts.
- **Secrets stay out of output.**

## References

- [`references/install.md`](references/install.md): pip, uv, source, Docker, platforms.
- [`references/models-and-api.md`](references/models-and-api.md): models, endpoints, LoRA, ComfyUI.
- [`references/performance-memory.md`](references/performance-memory.md): modes, offload, parallelism, caches, quantization.
- [`references/serving-and-ops.md`](references/serving-and-ops.md): serve options, probes, metrics, security.
- [`references/updating.md`](references/updating.md): pinning and upgrades.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `sglang`: LLM runtime.
- `self-hosted-genmedia`: choose an engine.
- `comfyui`: node UI with an SGLang plugin.
- `hugging-face`: tokens and cache.
- `caddy`: TLS and auth.

## License

MIT
