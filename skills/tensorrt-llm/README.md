# TensorRT-LLM

An agent skill for running [NVIDIA TensorRT-LLM](https://github.com/NVIDIA/TensorRT-LLM) as an OpenAI-compatible server on NVIDIA GPUs, including Blackwell and DGX Spark (GB10, single or dual node). It walks an AI coding agent through choosing a pinned NGC release container or pip install, starting `trtllm-serve` with a YAML (`--config` / `--extra_llm_api_options`), using FP8 and NVFP4 Model Optimizer checkpoints, scaling out with TP, PP and EP over MPI or Slurm, speculative decoding, reasoning and tool parsers, metrics, benchmarking with `trtllm-bench` and `trtllm-eval`, updating safely, and troubleshooting. Combos cover Model Optimizer NVFP4 quantization and NVIDIA Dynamo disaggregated serving.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill tensorrt-llm
```

## Rules

- **Pin the image.** Stable `1.2.1` by default, an exact rc only when a model needs it, never `latest`.
- **Loopback only.** `trtllm-serve` has no authentication; put a gateway or tunnel in front.
- **Ask before changing the system.** Pulls, services, ports, cache drops and multi-node runs need approval.
- **Secrets stay out of output.** `HF_TOKEN` comes from the environment or a `0600` file.
- **Verify upstream.** Flags are beta or prototype and differ between 1.2.1, the 1.3 rc line and `main`.

## References

- [`references/install.md`](references/install.md): NGC containers, pip, nightly, source, DGX Spark and dual Spark.
- [`references/serve-config.md`](references/serve-config.md): `trtllm-serve` flags, YAML keys, environment variables.
- [`references/models-and-formats.md`](references/models-and-formats.md): checkpoints, FP8/NVFP4/MXFP4 matrices, multimodal, legacy engines.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): TP, PP, EP, DP attention, MPI, Slurm, disaggregation.
- [`references/features.md`](references/features.md): speculative decoding, parsers, guided decoding, KV cache, scheduling.
- [`references/api.md`](references/api.md): endpoints, LLM API, `trtllm-eval`.
- [`references/performance-tuning.md`](references/performance-tuning.md): `trtllm-bench`, knobs, profiling.
- [`references/integrations.md`](references/integrations.md): llama-swap, LiteLLM, Open WebUI, systemd, compose, Kubernetes.
- [`references/observability.md`](references/observability.md): health, metrics, tracing.
- [`references/updating.md`](references/updating.md): release channels and upgrade procedure.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix table.
- [`references/combos/modelopt-nvfp4.md`](references/combos/modelopt-nvfp4.md): Model Optimizer NVFP4 / FP8 to TensorRT-LLM.
- [`references/combos/dynamo.md`](references/combos/dynamo.md): NVIDIA Dynamo with the TensorRT-LLM backend.
- [`templates/`](templates/): `config.yml`, `docker-compose.yml`, `trtllm-serve.service`, `k8s-deployment.yaml`.

## Companion skills

- `vllm`, `sglang`: alternative engines.
- `nvidia-dgx-spark`: GB10 memory and networking.
- `llama-swap`, `litellm`: swapping and gateway in front of the engine.
- `model-quantization`: produce FP8 / NVFP4 checkpoints.
- `self-hosted-llms`: whole-stack workflow.

## License

MIT
