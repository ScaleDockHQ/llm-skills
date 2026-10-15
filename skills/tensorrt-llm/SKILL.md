---
name: tensorrt-llm
description: Install, serve, tune and update NVIDIA TensorRT-LLM (trtllm-serve, trtllm-bench, trtllm-eval, LLM API) on NVIDIA GPUs incl. Blackwell and DGX Spark GB10. Covers NGC release containers, pip, PyTorch backend vs legacy engine builds, --config / --extra_llm_api_options YAML, FP8/NVFP4 ModelOpt checkpoints, TP/PP/EP, MPI/Slurm multi-node, speculative decoding, reasoning/tool parsers, metrics and Dynamo disaggregation. Use for TensorRT-LLM, TRT-LLM or trtllm questions, and errors like "Bus error (core dumped)", MPI_ERR_UNKNOWN, "OMPI was not built with SLURM support", "ptxas fatal", CUDA out of memory. Not for vLLM, SGLang or making quants (model-quantization).
license: MIT
compatibility: Linux with NVIDIA GPUs (Blackwell, Hopper, Ada, Ampere), x86_64 or arm64 (DGX Spark), Docker with NVIDIA Container Toolkit, bash, curl and jq. Pulling images, starting services and multi-node runs need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# TensorRT-LLM

Run NVIDIA TensorRT-LLM as an OpenAI-compatible server (`trtllm-serve`) from the NGC release container or pip, tune it, scale it over several GPUs or nodes, and update it safely.

**Scope:** this one product: install, serve, tune, scale out, update, troubleshoot. Cross-product choices (which engine, which quant) belong to `choosing-inference-engine` and `model-quantization`.

Work through the steps in order. Load a reference only when a step names it. Verified against TensorRT-LLM v1.2.1 (latest stable) and the 1.3.0rc line on 2026-10-11; `main` is already 1.4.0rc0 and its docs differ, so always confirm flags with `trtllm-serve --help` in the exact image you run.

## Discover first

Every command is read-only and never prints secrets.

```bash
command -v trtllm-serve trtllm-bench trtllm-eval docker nvidia-smi
nvidia-smi --query-gpu=name,compute_cap,memory.total,driver_version --format=csv
uname -m                                   # x86_64 or aarch64 (DGX Spark)
docker images --format '{{.Repository}}:{{.Tag}}  {{.ID}}' | grep -i tensorrt-llm
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' | grep -i -e trtllm -e tensorrt
curl -s http://127.0.0.1:8000/version; echo   # a running trtllm-serve
free -g; df -h "$HOME/.cache/huggingface" 2>/dev/null
python3 -c "import tensorrt_llm; print(tensorrt_llm.__version__)" 2>&1 | tail -1
```

## Decision flow

1. **GPU is Blackwell (B200, GB200, B300, GB300, RTX 50 / PRO, DGX Spark), Hopper, Ada or Ampere** -> supported (`references/install.md`). Quant formats differ per architecture (`references/models-and-formats.md`). No macOS, Windows, AMD or Apple path exists; use `llama-cpp`, `mlx` or `vllm` there.
2. **Want it running quickly** -> NGC `release` container, `trtllm-serve <model>` (`references/install.md`, `references/serve-config.md`). Prefer NVIDIA's `nvidia/*` FP8 / NVFP4 checkpoints.
3. **Pick the image tag**: stable `1.2.1` (amd64 + arm64) unless a model needs the rc line (`1.3.0rc29`, which NVIDIA's DGX Spark playbooks and Dynamo 1.5 track). Pin the tag, never `latest`.
4. **Model larger than one GPU / one node** -> TP, PP, EP and `trtllm-llmapi-launch` under MPI or Slurm (`references/parallelism-multinode.md`). Two DGX Sparks: the dual-Spark section in the same file.
5. **Prefill/decode split, KV-aware routing, Kubernetes** -> `references/combos/dynamo.md`.
6. **Need a quantized model** -> NVIDIA Model Optimizer NVFP4 / FP8 (`references/combos/modelopt-nvfp4.md`), then `model-quantization` for the full workflow.
7. **Slow, OOM or hanging** -> `references/troubleshooting.md` first, then `references/performance-tuning.md`.
8. **Updating** -> `references/updating.md`.

## Rules

- **Ask before changing the system.** Pulling multi-GB images, starting containers or services, binding ports beyond loopback, multi-node launches and cache drops need approval and an undo path.
- **Secrets never touch output.** `HF_TOKEN` comes from the environment or a `0600` file; never echo it, never pass it with `--set` or in command lines that land in history.
- **Verify upstream.** Flags marked beta or prototype change between rc builds. Read `--help` and the docs for the pinned tag before editing a recipe.
- **Loopback by default.** `trtllm-serve` has no authentication; bind `127.0.0.1` and put a gateway (`llm-gateway`, LiteLLM) or a tunnel in front.
- **Memory is shared on GB10.** `free_gpu_memory_fraction` is computed from memory the OS also needs; start at 0.8 and stop other engines first.

## Workflows

### Serve one model on one GPU

- [ ] Discover (above); confirm driver and free memory.
- [ ] Pull a pinned image: `docker pull nvcr.io/nvidia/tensorrt-llm/release:1.2.1` -> `references/install.md`
- [ ] Write a small YAML (`templates/config.yml`) and start `trtllm-serve` with `--ipc=host --ulimit memlock=-1 --ulimit stack=67108864` -> `references/serve-config.md`
- [ ] Verify: `curl -s 127.0.0.1:8000/health` returns 200, `/v1/models` lists the model, one `/v1/chat/completions` request answers.
- [ ] Benchmark with `trtllm-bench` or `trtllm-serve` plus a load tool -> `references/performance-tuning.md`

### Serve across several GPUs or nodes

- [ ] Choose TP / PP / EP and attention DP -> `references/parallelism-multinode.md`
- [ ] Single node: `--tp_size N`. Multi node: one container per node, `mpirun` or `srun` + `trtllm-llmapi-launch trtllm-serve ...`.
- [ ] Verify: the server starts only on rank 0's port, `/health` is 200, a request returns, GPUs on every node show memory use.

### Add speculative decoding, parsers, structured output

- [ ] EAGLE-3, MTP, NGram or draft-target through YAML `speculative_config` -> `references/features.md`
- [ ] `--reasoning_parser` / `--tool_parser`; `guided_decoding_backend` for JSON schema -> `references/features.md`

### Observe

- [ ] `/metrics`, `/prometheus/metrics`, `/perf_metrics`, `print_iter_log`, OTLP traces -> `references/observability.md`

### Update

- [ ] Diff release notes, pull the new tag on all nodes, compare YAML keys, restart in a window, re-benchmark -> `references/updating.md`

## Reference index

- `references/install.md`: NGC containers, pip, nightly, from source, DGX Spark and Blackwell notes, Slurm/enroot.
- `references/serve-config.md`: `trtllm-serve` flags, YAML (`--config`, `--extra_llm_api_options`, `--set`), minimal and Spark configs, env vars.
- `references/models-and-formats.md`: HF checkpoints, FP8/NVFP4/MXFP4 matrices per GPU, multimodal, legacy TensorRT engines.
- `references/parallelism-multinode.md`: TP, PP, DP, EP, CP, Wide-EP, MPI, Slurm, dual DGX Spark.
- `references/features.md`: speculative decoding, parsers, guided decoding, KV cache reuse and offload, chunked prefill, overlap scheduler, CUDA graphs.
- `references/api.md`: endpoints, request examples, LLM Python API, `trtllm-eval`.
- `references/performance-tuning.md`: `trtllm-bench`, batch and token limits, KV fraction, MoE backends, profiling.
- `references/integrations.md`: llama-swap, LiteLLM, Open WebUI, Cursor, systemd, compose, Kubernetes.
- `references/observability.md`: metrics endpoints, logging, tracing.
- `references/updating.md`: release channels, safe upgrade procedure, what changed between 1.2.1, 1.3 rc and main.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/modelopt-nvfp4.md`: Model Optimizer PTQ to a TensorRT-LLM NVFP4 / FP8 server.
- `references/combos/dynamo.md`: NVIDIA Dynamo with the TensorRT-LLM backend (disaggregated serving, KV routing, Kubernetes).
- `templates/`: `config.yml`, `docker-compose.yml`, `trtllm-serve.service`, `k8s-deployment.yaml` (untested starting points).

## Companion skills

- `vllm`: alternative engine with wider model coverage. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `sglang`: alternative engine. Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.
- `nvidia-dgx-spark`: GB10 memory, networking and dual-Spark setup. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`.
- `llama-swap`: model swapping in front of engines. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `litellm`: authenticated gateway and key management. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `model-quantization`: produce FP8 / NVFP4 checkpoints. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `self-hosted-llms`: whole-stack workflow (gateway, swap, exposure). Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `speculative-decoding`, `multi-node-inference`: cross-engine techniques. Install: `npx skills add ScaleDockHQ/llm-skills --skill speculative-decoding`.
