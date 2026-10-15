---
name: vllm
description: Install, serve and tune vLLM, the OpenAI-compatible LLM inference server (`vllm serve`, `vllm bench`, vllm/vllm-openai, nvcr.io/nvidia/vllm). Use for pip/uv, Docker, NGC, ROCm or CPU installs, serve flags, tool-call and reasoning parsers, structured outputs, LoRA, multimodal, embeddings, FP8/NVFP4, tensor/pipeline/expert/data parallel, multi-node (Ray or mp, two DGX Sparks), EAGLE-3, benchmarking, Prometheus metrics, Kubernetes, upgrades. Fixes CUDA out of memory, "Estimated maximum model length", NCCL, "architectures not supported", wrong parser. Not for choosing an engine (choosing-inference-engine) or llama.cpp, SGLang, TensorRT-LLM.
license: MIT
compatibility: Linux with an NVIDIA GPU (also AMD ROCm, CPU, DGX Spark/aarch64), Python 3.10+ or Docker, bash, curl and jq. Installs, services, firewall and network changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# vLLM

Gets a vLLM server running, correctly configured for the model and hardware, benchmarked, observable and
updatable. Verified against vLLM v0.31.0 (2026-10-11).

**Scope:** vLLM only: install, serve, tune, scale out, update, troubleshoot. Picking an engine, quantizing a
model, gateways and agent clients belong to the sibling skills at the end.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# What is installed
command -v vllm && vllm --version
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -Ei 'vllm' || true
pip list 2>/dev/null | grep -Ei '^(vllm|torch|ray|flashinfer)' || true

# Hardware and driver
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv 2>/dev/null
rocm-smi --showproductname 2>/dev/null | head -5
uname -m; free -h | head -2; nproc

# What is running and listening
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' | grep -i vllm || true
ss -ltnp 2>/dev/null | grep -E ':8000\b' || true
curl -s -m 3 http://127.0.0.1:8000/version; curl -s -m 3 http://127.0.0.1:8000/v1/models | jq '.data[].id'
curl -s -m 3 -o /dev/null -w 'health %{http_code}\n' http://127.0.0.1:8000/health
```

`vllm collect-env` prints the full environment for bug reports (review it before sharing).

## Decision flow

1. **No vLLM yet** -> pick the install path in `references/install.md`: DGX Spark or Jetson, NGC image;
   other NVIDIA, the `vllm/vllm-openai` image or `uv pip install vllm --torch-backend=auto`; AMD,
   `vllm/vllm-openai-rocm`; no GPU, the CPU build. Pin the version.
2. **Model chosen?** If not, the format and fit rules are in `references/models-and-formats.md`
   (weights, FP8/NVFP4/AWQ/GGUF, memory budget). For choosing between engines use the skill
   `choosing-inference-engine`.
3. **Does it fit one node?** Weights + KV cache must fit in GPU memory after `--gpu-memory-utilization`. If not:
   quantize, lower `--max-model-len`, or scale out (`references/parallelism-multinode.md`). TP inside a node first;
   multi-node only when needed.
4. **Write the serve command** from `references/serve-config.md` and `templates/config.yaml`. Always set
   `--served-model-name`, `--max-model-len`, parsers for agents and tools, and a loopback or private bind.
5. **Agent or tool use?** Needs `--enable-auto-tool-choice --tool-call-parser <name>` and for reasoning models
   `--reasoning-parser <name>`: table in `references/features.md`.
6. **Start and verify**: `/health`, `/v1/models`, one chat completion, one tool call, one streamed request.
7. **Tune and benchmark** with `vllm bench serve` (`references/performance-tuning.md`) and watch `/metrics`
   (`references/observability.md`).
8. **Persist** with `templates/docker-compose.yml`, `templates/vllm.service` or `templates/k8s-deployment.yaml`.
9. **Break or upgrade**: `references/troubleshooting.md`, `references/updating.md`.

## Quick start

```bash
# NVIDIA GPU, Docker. The image entrypoint is `vllm serve`, so the model is the first argument.
docker run --rm --gpus all --ipc=host -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_TOKEN \
  vllm/vllm-openai:v0.31.0 Qwen/Qwen3-Coder-30B-A3B-Instruct \
  --served-model-name qwen-coder --max-model-len 65536 \
  --enable-auto-tool-choice --tool-call-parser qwen3_xml

curl -s http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen-coder","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq '.choices[0].message'
```

`-e HF_TOKEN` forwards the variable from your environment without printing it; only gated models need it.
The first start downloads weights and compiles kernels, so it can take many minutes.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules, exposure and updates need approval and an
  undo path. Never benchmark a server other people are using.
- **Secrets never touch output.** `HF_TOKEN`, `VLLM_API_KEY` and NGC keys live in `0600` files or environment
  variables; forward with `-e NAME`, never `-e NAME=value` on a command line you will show.
- **Bind to loopback or a private network.** `--api-key` protects `/v1` only; `/metrics`, `/health`, `/tokenize`
  stay open. Never set `VLLM_SERVER_DEV_MODE=1` on an exposed server. Multi-node traffic is unencrypted: keep it
  on an isolated link.
- **Pin versions.** Exact image tag or digest or `vllm==X.Y.Z`; never `latest` or nightly in production. Same
  image ID on every node.
- **Verify upstream.** Flags and defaults change between minors. Run `vllm serve --help=all` on the installed
  version and check the release notes before trusting any remembered flag.
- **Set `--served-model-name`** to the ID clients and routers use, and `--max-model-len` explicitly.
- **Unified memory (DGX Spark, GB10) is shared with the OS.** Use 0.7-0.8 for `--gpu-memory-utilization`, keep
  headroom, never copy discrete-GPU settings (`references/performance-tuning.md`).
- **One model per server.** For several models use a router (`llama-swap`, `llm-gateway`) rather than
  loading everything into one process.
- **Measure before and after** every tuning change, with the version recorded.

## Facts that surprise people (v0.31.0)

- Default `--gpu-memory-utilization` is 0.92. The V1 engine has no swap space (`--swap-space` removed).
- Reasoning goes in `message.reasoning`, not `reasoning_content`. Tool and reasoning parsers are per model family.
- The executor defaults to `mp`, including `--nnodes > 1`; Ray only when asked. Upstream docs still say Ray.
- Structured outputs use the `structured_outputs` request field (not `guided_*`); attention backend is a flag
  (`--attention-backend`), not `VLLM_ATTENTION_BACKEND`.
- Sampling defaults come from the model's `generation_config.json`; `--generation-config vllm` restores neutral defaults.
- `/v1/models` does not report tool support; declare capabilities in the router.
- Cold start (weights, compile, CUDA graphs) is long: raise probe and router timeouts.

## Workflows

### Serve a model on one machine

- [ ] Run discovery; choose image or wheel (`references/install.md`).
- [ ] Check fit: weights + KV budget (`references/models-and-formats.md`).
- [ ] Write `config.yaml` (`templates/config.yaml`), parsers included.
- [ ] Start; wait for `/health`; run the smoke tests in Decision flow step 6.
- [ ] Benchmark at concurrency 1 and the real concurrency; save the numbers.
- [ ] Persist as compose, systemd or K8s (`templates/`).

### Two DGX Sparks (or two single-GPU nodes)

- [ ] Confirm one node truly cannot hold the model.
- [ ] Ray (NVIDIA-tested): `references/combos/dgx-spark-dual-ray.md`. mp (no Ray, unvalidated on Spark):
      `references/combos/dgx-spark-dual-mp.md`.
- [ ] Same image ID, weights path and flags on both nodes; traffic on the CX7 link only.
- [ ] Verify with `ray status` or the headless node log, then a completion.

### Speed up single-user decode

- [ ] Baseline with `vllm bench serve`.
- [ ] FP8/NVFP4 or MoE first (`references/models-and-formats.md`, `references/combos/llm-compressor-fp8.md`).
- [ ] Add EAGLE-3 or n-gram speculation (`references/combos/eagle3.md`); re-measure; watch acceptance on `/metrics`.

### Upgrade

- [ ] Follow `references/updating.md`: read release notes, pull on every node, compare image IDs, swap the tag in
      one place, smoke test, benchmark, keep the old image until verified.

### Debug a failure

- [ ] Capture the exact error text and the first 100 log lines, then match `references/troubleshooting.md`.

## Reference index

- `references/install.md`: image and package map; uv/pip, Docker, NGC, aarch64 and Blackwell, ROCm, CPU, Apple, XPU.
- `references/serve-config.md`: `vllm serve` flags by group, config file, env vars, removed flags.
- `references/models-and-formats.md`: weights, formats (FP8, NVFP4, MXFP4, AWQ, GPTQ, GGUF), kernels, KV dtype, memory budget.
- `references/parallelism-multinode.md`: TP/PP/EP/DP/DCP, mp vs Ray, multi-node recipes, NCCL, disaggregated prefill.
- `references/features.md`: tool and reasoning parsers, structured outputs, LoRA, multimodal, embeddings, speculative decoding.
- `references/api.md`: endpoints, request extensions, auth limits, dev-only routes.
- `references/performance-tuning.md`: `vllm bench`, knobs by symptom, CPU sizing, unified memory.
- `references/integrations.md`: LiteLLM, llama-swap, Open WebUI, Claude Code, Codex, Kubernetes stacks.
- `references/observability.md`: logs, `vllm:*` Prometheus metrics, tracing, probes.
- `references/updating.md`: upgrade procedure and v0.31.0 breaking changes.
- `references/troubleshooting.md`: error string to cause to fix.
- `references/combos/dgx-spark-dual-ray.md`, `dgx-spark-dual-mp.md`: two-Spark tensor parallel.
- `references/combos/amd-instinct-rocm.md`: ROCm containers, AITER, backends.
- `references/combos/rtx-blackwell.md`: SM120/SM121, NVFP4, b12x.
- `references/combos/llm-compressor-fp8.md`: make and serve an FP8 checkpoint.
- `references/combos/eagle3.md`: EAGLE-3 speculative decoding.
- `templates/`: `config.yaml`, `docker-compose.yml`, `vllm.service`, `k8s-deployment.yaml`.

## Companion skills

- `choosing-inference-engine`: vLLM vs llama.cpp vs SGLang vs TensorRT-LLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-inference-engine`.
- `self-hosted-llms`: the llama-swap + LiteLLM stack on owned GPU servers. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `nvidia-dgx-spark`: DGX Spark host setup. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`.
- `llama-swap`: on-demand model swapping in front of vLLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `litellm` and `llm-gateway`: keys, routing, fallbacks. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `tool-calling-parsers` and `structured-outputs`: model-level parser and schema detail. Install: `npx skills add ScaleDockHQ/llm-skills --skill tool-calling-parsers`.
- `llm-compressor`, `nvidia-modelopt`, `model-quantization`: make quantized checkpoints. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-compressor`.
- `speculative-decoding`, `multi-node-inference`, `disaggregated-serving`: technique-level guidance. Install: `npx skills add ScaleDockHQ/llm-skills --skill speculative-decoding`.
- `llm-observability`: traces, cost and evals around the server. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
