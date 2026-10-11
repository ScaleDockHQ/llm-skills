# vLLM-Omni

Install, serve, tune and troubleshoot vLLM-Omni, the vLLM extension that serves diffusion image and video models,
text-to-speech and audio generators and omni-modal chat models over OpenAI-style HTTP routes. Covers
`vllm serve MODEL --omni`, the image, video, speech and chat endpoints, offload, parallelism, quantization,
sleep mode and version pairing.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill vllm-omni
```

## Rules

- **Match versions.** vLLM and vLLM-Omni must share major.minor; pin both.
- **Bind loopback.** vLLM binds all interfaces by default; set `--host 127.0.0.1` and use `--api-key` or a gateway to expose.
- **One model per server.** An endpoint works only if the loaded model supports the task.
- **Use async video jobs.** `POST /v1/videos` over the blocking route.
- **Secrets stay out of output.**

## References

- [`references/install.md`](references/install.md): requirements, uv, wheels, source, Docker.
- [`references/models-and-api.md`](references/models-and-api.md): model families, endpoints, request fields.
- [`references/serving-and-stages.md`](references/serving-and-stages.md): serve flags, deploy configs, stages.
- [`references/performance-memory.md`](references/performance-memory.md): offload, parallelism, caches, quantization, sleep.
- [`references/updating.md`](references/updating.md): upgrades and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `vllm`: text-only engine underneath.
- `self-hosted-genmedia`: choose an image or video engine.
- `comfyui`: node UI with a vLLM-Omni custom node.
- `hugging-face`: tokens and cache.
- `litellm`: gateway.

## License

MIT
