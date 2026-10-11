# KTransformers

Install, serve, tune and troubleshoot KTransformers, the CPU+GPU hybrid inference stack (kt-kernel, the sglang-kt fork and the
`kt` CLI) for huge Mixture-of-Experts models such as DeepSeek, Kimi, GLM, MiniMax and Qwen3. Covers pip and source installs,
AMX, AVX512, AVX2 and llamafile backends, native FP8, BF16 and RAWINT4 weights, AMX conversion, GGUF experts, the `--kt-*` flags,
NUMA and thread sizing, expert placement and layerwise prefill. Verified against KTransformers v0.7.1.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill ktransformers
```

## Rules

- **Check the fit first.** Hybrid inference is for big MoE models with lots of RAM; dense or small models belong on other engines.
- **No default auth, wide default bind.** `kt run` defaults to `0.0.0.0`; always bind to loopback behind an authenticating proxy.
- **Use `sglang-kt`, not `sglang`, and pin both packages to one version.**
- **Secrets stay out of output.** Tokens live in `0600` files or environment variables.
- **Ask before changing the system.** `install.sh` runs apt, downloads are hundreds of GB, services and exposure need approval.

## References

- [`references/install.md`](references/install.md): pip, source builds, build variables, Docker status.
- [`references/serve-config.md`](references/serve-config.md): `kt` CLI, `--kt-*` flags, environment variables.
- [`references/models-and-formats.md`](references/models-and-formats.md): CPU backends, weights, models and hardware.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): tensor parallel, NUMA, expert placement.
- [`references/features.md`](references/features.md): deferred experts, layerwise prefill, LoRA, SFT pointer.
- [`references/api.md`](references/api.md): endpoints, auth, parsers.
- [`references/performance-tuning.md`](references/performance-tuning.md): order of knobs and reference numbers.
- [`references/integrations.md`](references/integrations.md): `kt chat`, LiteLLM, clients.
- [`references/observability.md`](references/observability.md): health, metrics, host monitoring.
- [`references/updating.md`](references/updating.md): versions, upgrade, rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- `templates/`: launch script, systemd unit, DeepSeek-V4-Flash compose file.

## Companion skills

- `sglang`: the server underneath.
- `moe-serving`, `cpu-inference`: concepts and CPU-only options.
- `choosing-inference-engine`: compare KTransformers with other engines.
- `litellm`, `llm-gateway`, `caddy`: routing, auth and TLS in front.

## License

MIT
