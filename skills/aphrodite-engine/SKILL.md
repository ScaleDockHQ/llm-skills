---
name: aphrodite-engine
description: Install, serve and tune Aphrodite Engine (now branded Sonar), the vLLM-derived LLM inference server with OpenAI, Anthropic and Kobold APIs. Use for the aphrodite CLI, aphrodite serve, aphrodite-engine pip package, sonar.dphn.ai, port 2242, quantization (exl3, gptq, awq, fp8), speculative decoding, LoRA, multi-node, upgrades. Fixes CUDA OOM, unsupported architecture, parser errors. Not for choosing an engine (choosing-inference-engine).
license: MIT
compatibility: Linux with NVIDIA CUDA (compute capability 8.0+), AMD ROCm, Intel XPU, CPU, Apple silicon Metal (source builds for most non-CUDA targets), WSL 2 on Windows; Python 3.10-3.13, uv, bash, curl and jq. Installs, services, exposure and upgrades need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# Aphrodite Engine

Gets an Aphrodite Engine (Sonar) server installed, pinned, serving a model with explicit memory settings and
authentication, connected to clients, and updatable. Verified against v0.24.1 (2026-10-11).

**Scope:** this one product: install, serve, tune, scale out, update, troubleshoot. Picking an engine, sizing
hardware and gateways belong to the sibling skills at the end.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# What is installed
command -v aphrodite uv && aphrodite --version
uv pip list 2>/dev/null | grep -Ei '^(aphrodite|torch|flashinfer|xformers)'
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -i 'aphrodite\|sonar' || true

# Hardware and driver
nvidia-smi --query-gpu=name,memory.total,memory.used,compute_cap,driver_version --format=csv 2>/dev/null
nvidia-smi topo -m 2>/dev/null | head -12
uname -sm; free -h 2>/dev/null | head -2

# Running server (default http://127.0.0.1:2242)
ss -ltnp 2>/dev/null | grep -E ':2242\b' || true
curl -s -m 3 http://127.0.0.1:2242/health -o /dev/null -w '%{http_code}\n'
curl -s -m 3 http://127.0.0.1:2242/version
echo "HF_HOME=$HF_HOME CACHE=${APHRODITE_CACHE_ROOT:-~/.cache/aphrodite}"
```

With `--api-key` or `APHRODITE_API_KEY` set, `/v1/models` needs `Authorization: Bearer`; read the key from a
`0600` file, for example `-H "Authorization: Bearer $(cat ~/.aphrodite-key)"`.

## Decision flow

1. **Is Aphrodite the right engine?** It fits when you want vLLM-style serving plus extra quantization formats
   (exl3, humming, mxfp6), extra samplers (DRY, phrase suppression), Kobold-compatible routes, or its extra
   models and platforms. For the mainstream stack with the broadest support and docs use vLLM; compare with
   the `choosing-inference-engine` skill. Note AGPL-3.0.
2. **Not installed** -> `references/install.md`. Prefer a pinned `uv pip install "aphrodite-engine==X.Y.Z"` in a
   fresh venv. There is no current official Docker image; build `docker/Dockerfile`.
3. **Fit the model.** Check compute capability 8.0+ for the CUDA wheel, the model's `architectures` against the
   generated model table, and the quantization matrix for your GPU (`references/features.md`).
4. **Serve** with explicit `--served-model-name`, `--max-model-len`, `--gpu-memory-utilization`,
   `--max-num-seqs`, `--host` and a key (`references/serve-config.md`, `templates/serve.yaml`).
5. **Needs more than one GPU** -> `references/parallelism-multinode.md` (TP, PP, DP, EP; multi-node is the
   `mp` executor with `--nnodes/--node-rank`, no Ray needed).
6. **Features:** tools, reasoning, structured output, speculative decoding, LoRA, multimodal
   (`references/features.md`).
7. **Tune** only with a baseline (`references/performance-tuning.md`).
8. **Persist and expose:** `templates/aphrodite.service`, a TLS proxy, private metrics
   (`references/api.md`, `references/observability.md`).
9. **Upgrade or break:** `references/updating.md`, `references/troubleshooting.md`.

## Quick start

```bash
export APHRODITE_API_KEY="$(openssl rand -hex 32)"      # store it in a 0600 file for clients
aphrodite serve Qwen/Qwen3-8B --host 127.0.0.1 --port 2242 \
  --served-model-name qwen3 --max-model-len 32768 --gpu-memory-utilization 0.90
curl -s -H "Authorization: Bearer $APHRODITE_API_KEY" http://127.0.0.1:2242/v1/chat/completions \
  -H 'Content-Type: application/json' -d '{"model":"qwen3","messages":[{"role":"user","content":"hi"}],"max_tokens":32}'
```

## Rules

- **Ask before changing the system.** Installs, services, exposure, upgrades and `--trust-remote-code` need
  approval and an undo path.
- **Secrets never touch output or command lines.** Use `APHRODITE_API_KEY` and `HF_TOKEN` from `0600` env files
  rather than `--api-key` (visible in the process list).
- **Pin everything.** Package version, `--revision` and `--tokenizer-revision` commit ids, PyTorch/CUDA stack.
- **Never expose `/metrics`, profiling, LoRA management, cache reset or sleep routes.** `--api-key` is not a
  network boundary.
- **Check flags with `aphrodite serve --help`** and the generated reference; names change between releases.
- **Do not pipe an installer into a shell for the user.** Download, read, `--dry-run`, then run with approval.

## Facts that surprise people (v0.24.1)

- **Renamed to Sonar.** Docs at sonar.dphn.ai, repo `dphnAI/sonar`; the package `aphrodite-engine`, command
  `aphrodite`, `APHRODITE_*` variables and default port 2242 are unchanged.
- **`--gpu-memory-utilization` is a fraction of total GPU memory** (default 0.92): a second process on the GPU
  makes startup fail rather than rescaling.
- **Prefix caching is on by default**; opt out with `--no-enable-prefix-caching`.
- **Multi-node does not need Ray.** The recipes page still shows `--distributed-executor-backend ray`; the
  distributed guide says `mp` for multi-node launches.
- **The Docker Hub image is stale** (last pushed 2025-11-09); build from source.
- **Docs mention `--launch-kobold-api`**, but the generated flag reference does not list it: verify locally.
- **The Rust frontend is experimental** and rejects unsupported options at startup.
- Release notes are commit lists with many vLLM sync ports; read them for your model family.

## Workflows

### Fresh server

- [ ] Run discovery; pick a pinned install (`references/install.md`).
- [ ] Choose model, quantization and context; set explicit memory and scheduler flags.
- [ ] Start with a key from the environment, bound to loopback; check `/health` and one chat request.
- [ ] Add parsers for tools or reasoning and test streaming.
- [ ] Persist with `templates/aphrodite.service`; front with TLS and rate limits.

### Multi-GPU or multi-node

- [ ] Map topology (`nvidia-smi topo -m`); TP inside NVLink, PP across nodes.
- [ ] Same commit, model files and flags on every node; unique `--node-rank`; data-plane NCCL interface.
- [ ] Test one node, then the minimal multi-node model, then production.

### Upgrade

- [ ] `references/updating.md`: record state, fresh venv, compare flags, smoke test, keep the old venv.

### Troubleshoot

- [ ] Capture the first error and the full command; match `references/troubleshooting.md`.

## Reference index

- `references/install.md`: rename, support matrix, uv wheel, installer, source builds, Docker.
- `references/serve-config.md`: serve flags, YAML config, environment variables, model storage.
- `references/parallelism-multinode.md`: TP/PP/DP/EP, multi-node launch, disaggregation, Ray security.
- `references/features.md`: tools, reasoning, structured output, speculation, quantization, LoRA, multimodal.
- `references/api.md`: routes, auth, security, client examples.
- `references/performance-tuning.md`: benchmarking, tuning order, Rust frontend, recipes.
- `references/observability.md`: health, metrics, logs, traces, shutdown.
- `references/updating.md`: upgrade and rollback.
- `references/troubleshooting.md`: symptom to fix.
- `templates/`: `serve.yaml`, `aphrodite.service`.

## Companion skills

- `choosing-inference-engine`: Aphrodite vs vLLM vs SGLang vs llama.cpp. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-inference-engine`.
- `vllm`: the upstream engine whose flags mostly carry over. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `choosing-hardware`: sizing math for GPU memory and context. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
- `litellm`: keys, routing, fallbacks in front of the server. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `disaggregated-serving`: prefill/decode technique guidance. Install: `npx skills add ScaleDockHQ/llm-skills --skill disaggregated-serving`.
- `llm-observability`: traces and cost around the server. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
