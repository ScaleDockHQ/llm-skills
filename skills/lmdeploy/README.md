# LMDeploy

Install, serve, quantize, tune, scale out, update and troubleshoot LMDeploy, the InternLM toolkit for LLM and VLM
inference with the TurboMind and PyTorch engines. Covers pip and Docker installs, the OpenAI, Anthropic and
Responses endpoints, tool and reasoning parsers, AWQ and KV-cache quantization, tensor, data, expert and context
parallelism, the proxy server, Prometheus metrics and Kubernetes. Verified against LMDeploy v0.18.0.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill lmdeploy
```

## Rules

- **Loopback by default.** `--server-name` defaults to `0.0.0.0`, and `--api-keys` covers only `/v1`.
- **Pin versions.** Exact `lmdeploy==X.Y.Z` or image tag; never `latest`.
- **Secrets stay out of output.** Tokens live in `0600` files or environment variables.
- **Ask before changing the system.** Installs, services and exposure need approval.

## References

- [`references/install.md`](references/install.md): pip, Docker, ROCm, source builds.
- [`references/serve-config.md`](references/serve-config.md): flags, defaults, environment variables.
- [`references/models-and-formats.md`](references/models-and-formats.md): engines, AWQ, KV quantization, memory.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): tp, cp, dp, ep, proxy, Ray, DistServe.
- [`references/features.md`](references/features.md): parsers, structured output, LoRA, VLM, speculative decoding.
- [`references/api.md`](references/api.md): endpoints and the auth boundary.
- [`references/performance-tuning.md`](references/performance-tuning.md): benchmarks and knobs.
- [`references/integrations.md`](references/integrations.md): LiteLLM, Claude Code, Codex, Kubernetes.
- [`references/observability.md`](references/observability.md): health, metrics, Grafana stack.
- [`references/updating.md`](references/updating.md): upgrade procedure and v0.18.0 notes.
- [`references/troubleshooting.md`](references/troubleshooting.md): error to fix.
- `templates/`: compose, systemd, Kubernetes.

## Companion skills

- `choosing-inference-engine`: compare LMDeploy with other engines.
- `litellm`, `llama-swap`, `llm-gateway`: routing in front of LMDeploy.
- `tool-calling-parsers`, `structured-outputs`, `model-quantization`, `speculative-decoding`: technique detail.

## License

MIT
