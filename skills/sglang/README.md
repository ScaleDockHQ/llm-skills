# SGLang

Helps an agent install, serve, tune, scale and update SGLang (`python3 -m sglang.launch_server`, `sglang serve`) for fast LLM and VLM inference. Covers pip/uv and `lmsysorg/sglang` Docker images, NVIDIA (CUDA 13, Blackwell, aarch64), ROCm, DGX Spark, RadixAttention, TP/DP/EP, DP-attention, multi-node, PD disaggregation, tool and reasoning parsers, structured outputs, speculative decoding, LoRA, multimodal, embeddings, `bench_serving`, metrics and troubleshooting. Verified against SGLang v0.5.21 (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill sglang
```

## Rules

- **Discover first.** Read-only commands before any change; confirm GPU, driver, arch and the running version.
- **Pin versions.** Use an exact image tag or package version, never `latest` or `dev`, and re-verify flags after every update because they drift.
- **Never print secrets.** Keys live in 0600 files or env vars; `/server_info` can contain the launch command, so filter it.
- **Bind loopback by default.** Use `--api-key` or a gateway before exposing a port; `/health` and `/metrics` stay open.
- **Ask before** installing, starting services, opening ports or changing multi-node setups.

## References

- [`references/install.md`](references/install.md): pip/uv, Docker tags, ROCm, aarch64, source builds.
- [`references/serve-config.md`](references/serve-config.md): entry points, core flags, env vars, security.
- [`references/models-and-formats.md`](references/models-and-formats.md): model sources, quantization, KV dtype, model notes.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): TP/DP/EP/PP, DP-attention, router, multi-node.
- [`references/features.md`](references/features.md): RadixAttention, HiCache, parsers, structured outputs, speculative decoding, LoRA, multimodal, embeddings.
- [`references/api.md`](references/api.md): compatible APIs, smoke tests, operational endpoints.
- [`references/performance-tuning.md`](references/performance-tuning.md): reading logs, tuning, `bench_serving`.
- [`references/observability.md`](references/observability.md): metrics, logging, tracing, health checks.
- [`references/integrations.md`](references/integrations.md): llama-swap, LiteLLM, Claude Code, router.
- [`references/updating.md`](references/updating.md): release cadence and safe update procedure.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom table and NCCL diagnostics.
- [`references/combos/dgx-spark.md`](references/combos/dgx-spark.md): SGLang on DGX Spark, single and dual node.
- [`references/combos/pd-disaggregation.md`](references/combos/pd-disaggregation.md): prefill/decode disaggregation with Mooncake or NIXL.
- [`templates/`](templates/): Docker Compose, systemd unit, Kubernetes manifest and config file.

## Companion skills

- `self-hosted-llms`: choosing an engine and the surrounding stack.
- `vllm`: the alternative engine.
- `nvidia-dgx-spark`: host setup and memory safety on Spark.
- `llama-swap`: model switching in front of SGLang.
- `litellm`: gateway with keys and budgets.
- `speculative-decoding`, `multi-node-inference`, `model-quantization`, `llm-observability`: deeper topic guidance.

## License

MIT
