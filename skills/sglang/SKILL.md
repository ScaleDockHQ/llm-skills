---
name: sglang
description: Install, serve, tune and scale SGLang (sglang.launch_server, `sglang serve`) for fast LLM/VLM inference with RadixAttention. Use for lmsysorg/sglang images, pip/uv installs, NVIDIA/ROCm/DGX Spark/Jetson/Apple, TP/DP/EP, DP-attention, multi-node, PD disaggregation, tool/reasoning parsers, EAGLE speculative decoding, LoRA, embeddings, bench_serving, /metrics, updates, and errors like CUDA OOM, "KV cache pool is full", NCCL hangs. Not for choosing an engine (self-hosted-llms) or vLLM.
license: MIT
compatibility: Linux with NVIDIA (CUDA 13) or AMD GPUs, DGX Spark/Jetson, or Apple Silicon (MLX); Docker or Python 3.10+, curl and jq. Installs, services, exposed ports and multi-node changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# SGLang

Gets an SGLang server (v0.5.21 verified) running, tuned and monitored: one OpenAI/Anthropic-compatible endpoint with RadixAttention prefix caching, continuous batching, speculative decoding and TP/DP/EP/multi-node scaling.

**Scope:** this one product: install, serve, tune, scale out, update, troubleshoot. Choosing between engines, gateways and quantization formats belongs to other skills (see Companion skills).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens or API keys.

```bash
# Hardware and driver
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv 2>/dev/null
rocm-smi --showproductname 2>/dev/null | head -5
uname -m; command -v docker && docker info --format '{{.Runtimes}}' 2>/dev/null

# Is SGLang already installed or running?
command -v sglang && sglang version
python3 -c 'import sglang; print(sglang.__version__)' 2>/dev/null
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i sglang
ss -ltnp 2>/dev/null | grep -E ':30000\b'

# A running server: version, effective args, health
curl -fsS http://127.0.0.1:30000/health -o /dev/null -w '%{http_code}\n'
curl -fsS http://127.0.0.1:30000/server_info | jq -r 'del(.launch_command) | [paths(scalars) as $p | {k: ($p|map(tostring)|join(".")), v: getpath($p)}] | .[] | select(.k|test("version$|tp_size|dp_size|mem_fraction|context_len")) | "\(.k)=\(.v)"'
curl -fsS http://127.0.0.1:30000/v1/models | jq -r '.data[].id'
```

## Decision flow

1. **Which platform?** NVIDIA x86_64/aarch64 (incl. DGX Spark GB10, B200/GB200) -> Docker `lmsysorg/sglang:v<ver>-cu130` or `uv pip install sglang`. AMD Instinct -> ROCm images. Jetson Orin -> jetson-containers. Apple Silicon -> MLX backend (`SGLANG_USE_MLX=1`). -> `references/install.md`.
2. **CUDA 12 host or driver?** Not supported on 0.5.20+: the last CUDA 12 lane is `v0.5.19-cu129`. Upgrade the driver or pin the old tag, and say so.
3. **Does the model fit on one GPU?** Yes -> single process, optionally data parallel replicas behind the model gateway. No -> `--tp`, or multi-node `--nnodes` -> `references/parallelism-multinode.md`.
4. **MoE / MLA model (DeepSeek, Kimi, MiniMax, Qwen MoE)?** Consider `--enable-dp-attention` and `--ep` -> `references/parallelism-multinode.md`.
5. **Agent/tool workload?** Set `--tool-call-parser` and `--reasoning-parser` (or `auto`) -> `references/features.md`.
6. **Throughput vs. latency?** Speculative decoding for low-concurrency latency; bigger batches and `--schedule-policy lpm` for throughput -> `references/performance-tuning.md`.
7. **Prefill and decode contending?** Consider PD disaggregation -> `references/combos/pd-disaggregation.md`.
8. **DGX Spark?** Start from `references/combos/dgx-spark.md`.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules, `--network host`, `--privileged` and exposure need approval and an undo path.
- **Bind locally unless told otherwise.** The server default is `--host 127.0.0.1`. With Docker `-p`, `--host 0.0.0.0` inside the container is fine if the port is published to `127.0.0.1:`; with `--network host` bind `127.0.0.1` or set `--api-key`.
- **Secrets never touch output.** `HF_TOKEN`, `--api-key` and `--admin-api-key` come from `0600` files or environment variables; never inline them in commands you print. `/health*`, `/ready*` and `/metrics` are always exempt from `--api-key` (source: `srt/utils/auth.py`).
- **Pin versions.** `latest` and `dev` Docker tags are mutable. Use `v0.5.21-cu130` (or the newest verified tag), record the image digest, and keep the same version on every node.
- **Verify upstream.** Flags move fast (`--cuda-graph-max-bs` became `--cuda-graph-max-bs-decode`; `--disable-cuda-graph` is deprecated). Check `python3 -m sglang.launch_server --help` or `/server_info` on the installed version before claiming a flag exists.
- **One model per process.** Cold start is slow (weights + CUDA graph capture, minutes for large models): do not poll `/health_generate` frequently.
- **Do not combine online `--quantization` with a pre-quantized checkpoint.**
- **Measure before and after tuning** with `python3 -m sglang.bench_serving`, same dataset and concurrency.

## Workflows

### Serve a model

- [ ] Install (`references/install.md`), pin the version.
- [ ] Pick model and format (`references/models-and-formats.md`); pre-download weights with `hf download` into the HF cache.
- [ ] Start with the minimal command below; add flags from `references/serve-config.md`.
- [ ] Wait for `/health` -> 200, then test `/v1/chat/completions`.
- [ ] Put it under systemd, compose or Kubernetes (`templates/`).
- [ ] Enable `--enable-metrics` and scrape `/metrics` (`references/observability.md`).
- [ ] Benchmark with `bench_serving` and record the numbers.

Minimal Docker command (single GPU, local only):

```bash
# ~/.config/sglang/env is a 0600 file containing HF_TOKEN=... (drop --env-file for public models)
docker run -d --name sglang --gpus all --ipc=host --shm-size 32g \
  -p 127.0.0.1:30000:30000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  --env-file ~/.config/sglang/env \
  lmsysorg/sglang:v0.5.21-cu130 \
  python3 -m sglang.launch_server --model-path Qwen/Qwen3-8B \
    --served-model-name qwen3-8b --host 0.0.0.0 --port 30000 \
    --mem-fraction-static 0.85 --enable-metrics
curl -fsS http://127.0.0.1:30000/health -o /dev/null -w '%{http_code}\n'
```

Equivalent pip/uv launch: `sglang serve Qwen/Qwen3-8B --port 30000` (or `python3 -m sglang.launch_server --model-path ...`). Settings can live in YAML: `--config config.yaml` (CLI overrides file; keys are flag names without `--`; see `templates/config.yaml`).

Smoke test:

```bash
curl -fsS http://127.0.0.1:30000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-8b","messages":[{"role":"user","content":"Say hi"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

### Scale out

- [ ] More memory than one GPU: `--tp N`. More throughput with memory to spare: DP replicas (router) -> `references/parallelism-multinode.md`.
- [ ] Multi-node: same command on every node with `--nnodes`, `--node-rank`, `--dist-init-addr`; same image everywhere; NCCL interface set.
- [ ] Verify with `/server_info` and a load test; stop and start all ranks together.

### Tune

- [ ] Read the decode log line (`#running-req`, `token usage`, `#queue-req`) and `available_gpu_mem` at startup -> `references/performance-tuning.md`.
- [ ] Change one knob at a time; rerun the same benchmark.

### Update

- [ ] Read release notes, pull the pinned tag on every node, compare image IDs, restart in a window, rerun smoke test and benchmark -> `references/updating.md`.

### Troubleshoot

- [ ] Match the symptom in `references/troubleshooting.md` (OOM, hangs, illegal memory access, no startup, tool calls empty, port, NCCL, FlashInfer).

## Verify before done

- `/health` returns 200 and `/v1/models` lists the intended `--served-model-name`.
- A chat completion returns text; a tool call returns `tool_calls` if `--tool-call-parser` was set.
- `/server_info` shows the intended TP/DP, `mem_fraction_static`, context length and version.
- The listener is on `127.0.0.1` (or auth is enabled) when reachable from other hosts.
- `/metrics` returns `sglang:` series when `--enable-metrics` is set.
- The version and image digest are recorded, and a benchmark baseline exists.

## Reference index

| File                                     | Load when                                                                                                |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `references/install.md`                  | pip/uv, Docker tags, ROCm, aarch64/Blackwell, Jetson, Apple, K8s, source                                 |
| `references/serve-config.md`             | launch flags, config file, memory, scheduling, security, env vars                                        |
| `references/models-and-formats.md`       | model sources, load formats, quantization (FP8, NVFP4, AWQ, GPTQ, GGUF), KV dtype                        |
| `references/parallelism-multinode.md`    | TP, PP, DP, DP-attention, EP, multi-node, SLURM, router                                                  |
| `references/features.md`                 | RadixAttention, HiCache, parsers, structured outputs, speculative decoding, LoRA, multimodal, embeddings |
| `references/api.md`                      | OpenAI, Anthropic, native endpoints, request extras, admin endpoints                                     |
| `references/performance-tuning.md`       | memory fraction, chunked prefill, CUDA graphs, schedule policy, bench_serving                            |
| `references/integrations.md`             | llama-swap, LiteLLM, Claude Code, Open WebUI-style clients, SkyPilot, SageMaker                          |
| `references/observability.md`            | Prometheus metrics, logging, tracing, crash dumps, Grafana                                               |
| `references/updating.md`                 | version bump procedure, breaking changes to watch                                                        |
| `references/troubleshooting.md`          | symptom to fix table                                                                                     |
| `references/combos/dgx-spark.md`         | NVIDIA DGX Spark (GB10) single and dual node, llama-swap                                                 |
| `references/combos/pd-disaggregation.md` | prefill/decode split with Mooncake or NIXL and the router                                                |
| `templates/`                             | compose, systemd, Kubernetes, YAML config                                                                |

## Companion skills

- `self-hosted-llms`: choose and run engines on GPU servers with llama-swap and LiteLLM. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `vllm`: the main alternative engine. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `nvidia-dgx-spark`: host setup for GB10 machines. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-spark`.
- `llama-swap`: model swapping in front of engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.
- `litellm`: gateway with keys and routing. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `speculative-decoding`: draft-model strategy across engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill speculative-decoding`.
- `multi-node-inference`: cross-engine cluster design. Install: `npx skills add ScaleDockHQ/llms-skills --skill multi-node-inference`.
- `model-quantization`: producing FP8/NVFP4/AWQ checkpoints. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `llm-observability`: Prometheus/Grafana for engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
