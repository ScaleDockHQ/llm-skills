# MLC LLM

Agent skill for installing, serving and compiling models with MLC LLM (MLCEngine on Apache TVM): nightly pip wheels or source builds, `mlc_llm serve`, `chat`, `convert_weight`, `gen_config` and `compile`, the OpenAI-compatible REST server and Python engines, tensor parallel, speculative decoding, MicroServing, and the JIT model-library cache, across CUDA, ROCm, Vulkan and Metal.

Verified against MLC LLM `main` (8978ea9a, tags v0.20.0 and v0.26.dev0) on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill mlc-llm
```

## Rules

- **Ask before changing the system.** Installs, builds, downloads, JIT compiles and exposure need approval.
- **Secrets never touch output.** Keep the API key and `HF_TOKEN` in `0600` files or env vars.
- **Auth is off by default and CORS allows `*`.** Bind loopback, set `--api-key`, narrow origins, never use `--enable-debug` on reachable hosts.
- **Pin the wheels or commit.** Nightly builds move daily.
- **The JIT cache is part of the deployment.** Warm it, then use `MLC_JIT_POLICY=READONLY`.

## References

- [`references/install.md`](references/install.md): wheels, source build, device check.
- [`references/serve-config.md`](references/serve-config.md): serve and chat flags, overrides, env vars.
- [`references/models-and-formats.md`](references/models-and-formats.md): quant codes, architectures, convert and compile.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): tensor parallel, speculation, MicroServing.
- [`references/features.md`](references/features.md): tools, structured output, embeddings, web and mobile.
- [`references/api.md`](references/api.md): endpoints and Python engines.
- [`references/performance-tuning.md`](references/performance-tuning.md): modes, memory, compile options.
- [`references/integrations.md`](references/integrations.md): LiteLLM, clients, systemd.
- [`references/observability.md`](references/observability.md): metrics, debug, tracing.
- [`references/updating.md`](references/updating.md): update and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`templates/`](templates): systemd unit and LiteLLM config.

## Companion skills

- `choosing-inference-engine`: compare engines.
- `vllm`, `llama-cpp`: other engines.
- `litellm`: gateway.
- `model-quantization`: choosing a quantization.

## License

MIT
