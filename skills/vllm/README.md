# vLLM Skill

An agent skill for running [vLLM](https://github.com/vllm-project/vllm), the OpenAI-compatible LLM inference server, on NVIDIA, AMD or CPU hosts. It walks an AI coding agent through installing the right image or wheel, fitting a model into memory, writing the `vllm serve` command with the correct tool-call and reasoning parsers, scaling across GPUs and nodes (including two DGX Sparks), benchmarking, monitoring, upgrading and fixing the common failures. Every command is read-only first and never prints secrets. Verified against vLLM v0.31.0 (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill vllm
```

## Rules

- **Pin versions.** Exact image tag or digest, same image ID on every node; never `latest` in production.
- **Loopback or private bind.** `--api-key` protects `/v1` only; never expose `/metrics` or dev routes.
- **Secrets never touch output.** Tokens come from the environment or `0600` files.
- **Fit first.** Weights plus KV cache must fit; set `--max-model-len` and `--served-model-name` explicitly.
- **Unified memory is shared.** Use 0.7-0.8 `--gpu-memory-utilization` on DGX Spark.
- **Verify upstream flags.** Run `vllm serve --help=all` on the installed version.
- **Measure before and after** every tuning change.

## References

- [`references/install.md`](references/install.md): uv/pip, Docker, NGC, aarch64, ROCm, CPU, Apple, XPU.
- [`references/serve-config.md`](references/serve-config.md): flags, config file, env vars, removed flags.
- [`references/models-and-formats.md`](references/models-and-formats.md): weights, quantization formats, kernels, memory budget.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): TP/PP/EP/DP, mp vs Ray, NCCL.
- [`references/features.md`](references/features.md): tool and reasoning parsers, structured outputs, LoRA, multimodal, embeddings, speculation.
- [`references/api.md`](references/api.md): endpoints, extensions, dev-only routes.
- [`references/performance-tuning.md`](references/performance-tuning.md): `vllm bench`, knobs by symptom, CPU sizing.
- [`references/integrations.md`](references/integrations.md): LiteLLM, llama-swap, Open WebUI, Claude Code, Codex, Kubernetes.
- [`references/observability.md`](references/observability.md): logs, Prometheus metrics, tracing, probes.
- [`references/updating.md`](references/updating.md): upgrade procedure and breaking changes.
- [`references/troubleshooting.md`](references/troubleshooting.md): error string to fix.

Combos:

- [`references/combos/dgx-spark-dual-ray.md`](references/combos/dgx-spark-dual-ray.md): two Sparks with Ray.
- [`references/combos/dgx-spark-dual-mp.md`](references/combos/dgx-spark-dual-mp.md): two Sparks without Ray.
- [`references/combos/amd-instinct-rocm.md`](references/combos/amd-instinct-rocm.md): ROCm containers and AITER.
- [`references/combos/rtx-blackwell.md`](references/combos/rtx-blackwell.md): SM120/SM121, NVFP4, b12x.
- [`references/combos/llm-compressor-fp8.md`](references/combos/llm-compressor-fp8.md): make and serve FP8.
- [`references/combos/eagle3.md`](references/combos/eagle3.md): EAGLE-3 speculative decoding.

Templates: [`templates/config.yaml`](templates/config.yaml), [`templates/docker-compose.yml`](templates/docker-compose.yml), [`templates/vllm.service`](templates/vllm.service), [`templates/k8s-deployment.yaml`](templates/k8s-deployment.yaml).

## Companion skills

From [ScaleDockHQ/llm-skills](https://github.com/ScaleDockHQ/llm-skills); install any of them with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `choosing-inference-engine`: vLLM vs llama.cpp vs SGLang vs TensorRT-LLM.
- `self-hosted-llms`: the llama-swap + LiteLLM stack on owned GPU servers.
- `nvidia-dgx-spark`: DGX Spark host setup.
- `llama-swap`, `litellm`, `llm-gateway`: routing in front of vLLM.
- `tool-calling-parsers`, `structured-outputs`: parser and schema detail.
- `llm-compressor`, `nvidia-modelopt`, `model-quantization`: quantized checkpoints.
- `speculative-decoding`, `multi-node-inference`, `disaggregated-serving`: techniques.
- `llm-observability`: traces, cost and evals.

## License

MIT
