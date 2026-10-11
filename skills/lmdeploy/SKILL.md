---
name: lmdeploy
description: Install, serve and tune LMDeploy, the InternLM LLM/VLM inference toolkit with TurboMind and PyTorch engines (`lmdeploy serve api_server`, `lmdeploy lite`, openmmlab/lmdeploy). Use for pip or Docker installs, OpenAI, Anthropic and Responses endpoints, tool and reasoning parsers, AWQ and KV-cache quantization, tensor/data/expert parallel, the proxy server, Prometheus metrics, upgrades. Fixes OOM, "finish_reason length", unsupported model, parser errors. Not for choosing an engine (choosing-inference-engine) or vLLM, SGLang.
license: MIT
compatibility: Linux or Windows with an NVIDIA GPU (Volta sm70 or newer), Python 3.10-3.13 or Docker, bash, curl and jq. Installs, services and network exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LMDeploy

Gets an LMDeploy server running with the right engine, configured for the model and GPUs, observable and
updatable. Verified against LMDeploy v0.18.0 (2026-10-11).

**Scope:** LMDeploy only: install, serve, quantize, tune, scale out, update, troubleshoot. Picking an engine,
gateways and agent clients belong to the sibling skills at the end.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# What is installed
command -v lmdeploy && lmdeploy --version 2>/dev/null
pip list 2>/dev/null | grep -Ei '^(lmdeploy|torch|ray|xgrammar|flash)' || true
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -i lmdeploy || true

# Hardware and driver (sm70+ NVIDIA needed)
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv 2>/dev/null
uname -m; free -h | head -2; nproc

# What is running and listening (default port 23333)
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' | grep -i lmdeploy || true
ss -ltnp 2>/dev/null | grep -E ':23333\b' || true
curl -s -m 3 http://127.0.0.1:23333/v1/models | jq '.data[].id'
curl -s -m 3 -w '\nhealth %{http_code}\n' http://127.0.0.1:23333/health
```

`lmdeploy check_env` prints the environment for bug reports (review it before sharing).
`lmdeploy serve api_server -h` is the source of truth for flags on the installed version.

## Decision flow

1. **No LMDeploy yet** -> `references/install.md`: `pip install lmdeploy` in a Python 3.10-3.13 env, or the
   `openmmlab/lmdeploy` image with an exact tag. Pin the version.
2. **Pick the engine.** `--backend turbomind` is the default (C++/CUDA, fastest where supported);
   `--backend pytorch` is wider (more models, LoRA, speculative decoding, DP/EP, multi-node, sliding-window
   models). Check the model in `references/models-and-formats.md`; when unsure, start with the default and fall
   back to `pytorch` on an unsupported-model error.
3. **Does it fit?** Weights plus KV cache must fit. `--cache-max-entry-count` (default 0.8) is the share of _free_
   memory taken by KV cache after weights. If not: quantize (AWQ, `--quant-policy`), shorten `--session-len`, or
   `--tp` (`references/parallelism-multinode.md`).
4. **Write the serve command** from `references/serve-config.md`. Always set `--server-name 127.0.0.1` (the default
   is `0.0.0.0`), `--model-name`, `--session-len`, and the parsers for agents.
5. **Agent or tool use?** `--tool-call-parser <name>` and, for thinking models, `--reasoning-parser <name>`
   (`references/features.md`).
6. **Start and verify**: `/health`, `/v1/models`, one chat completion, one tool call, one stream.
7. **Tune and benchmark** (`references/performance-tuning.md`), watch `/metrics` (`references/observability.md`).
8. **Persist** with `templates/docker-compose.yml`, `templates/lmdeploy.service` or `templates/k8s-deployment.yaml`.
9. **Break or upgrade**: `references/troubleshooting.md`, `references/updating.md`.

## Quick start

```bash
# pip (Python 3.10-3.13), then serve on loopback
pip install lmdeploy==0.18.0
lmdeploy serve api_server Qwen/Qwen3-8B --server-name 127.0.0.1 --server-port 23333 \
  --model-name qwen --session-len 32768

curl -s http://127.0.0.1:23333/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq '.choices[0].message'
```

Docker (NVIDIA): the image tag form is `openmmlab/lmdeploy:v0.18.0-cu12.8` (or `-cu13.0`); the command is the full
`lmdeploy serve api_server ...` line (see `templates/docker-compose.yml`). The first start downloads weights and
can take many minutes. Gated models need `HF_TOKEN` forwarded with `-e HF_TOKEN` (never `-e HF_TOKEN=value`).

## Rules

- **Ask before changing the system.** Installs, services, firewall rules, exposure and updates need approval and an
  undo path. Never benchmark a server other people are using.
- **Secrets never touch output.** `HF_TOKEN` and the keys for `--api-keys` live in `0600` files or environment
  variables. `--api-keys` takes values on the command line (visible in `ps`): prefer a file you expand at launch
  and a proxy that holds the real key.
- **Bind to loopback or a private network.** `--server-name` defaults to `0.0.0.0` and CORS defaults to `*`.
  `--api-keys` protects only paths under `/v1`. `/health`, `/metrics`, `/docs`, `/generate`, `/sleep`, `/wakeup`,
  `/update_weights` and `/nodes/*` stay open. Put a gateway with auth in front for anything non-local.
- **Pin versions.** Exact `lmdeploy==X.Y.Z` or image tag/digest; never `latest` or `nightly-*` in production.
- **Verify upstream.** Flags move between minors. Run `lmdeploy serve api_server -h` on the installed version.
- **Set `--model-name` and `--session-len` explicitly.** The model name is what clients and routers use.
- **Do not enable `--allow-terminate-by-client`** on anything reachable by others.
- **One model per api_server.** For several models use `lmdeploy serve proxy` or a router (`llama-swap`, `litellm`).
- **Measure before and after** every tuning change, with the version recorded.

## Facts that surprise people (v0.18.0)

- Default `--backend turbomind` is really "auto": `api_server` runs a backend autodetect and falls back to the
  PyTorch engine when TurboMind does not support the model. `--backend pytorch` forces PyTorch.
- Default port is 23333 (unset `--server-port` means 23333). Default bind is `0.0.0.0`.
- KV cache takes 80% of _free_ memory after weights (`--cache-max-entry-count 0.8`) and is allocated once, so
  `nvidia-smi` shows a nearly full GPU even when idle. OOM -> lower it.
- Reasoning is returned as `reasoning_content` (not `reasoning`). Parser names are not vLLM's (`qwen3coder`,
  `interns2-preview`, `glm47`, `llama3`...).
- `/v1/embeddings` is tagged unsupported; there is a `/pooling` route instead (`references/api.md`).
- `--tp` should be a power of two (flag help: "Should be 2^n"). Going past the KV-head count duplicates KV heads and
  halves KV capacity; TurboMind's `--cp` avoids that (`references/parallelism-multinode.md`).
- LoRA adapters (`--adapters`) and speculative decoding are PyTorch-engine features; upstream marks speculative
  decoding experimental.
- Default log level is `WARNING`: a quiet server is not a hung server during load.

## Workflows

### Serve a model on one machine

- [ ] Run discovery; install per `references/install.md`.
- [ ] Check fit and engine (`references/models-and-formats.md`).
- [ ] Build the serve command (`references/serve-config.md`), parsers included, bound to loopback.
- [ ] Start; wait for `/health` 200; run the smoke tests (Decision flow step 6).
- [ ] Benchmark at concurrency 1 and the real concurrency; save the numbers.
- [ ] Persist (`templates/`).

### Quantize to fit a smaller GPU

- [ ] `lmdeploy lite auto_awq` for 4-bit weights; `--quant-policy 8` for int8 KV cache
      (`references/models-and-formats.md`).
- [ ] Serve with `--model-format awq` if it is not auto-detected; compare quality on your own prompts.

### Scale out

- [ ] `--tp N` inside a node first; replicas behind `lmdeploy serve proxy` next; multi-node only when one node
      cannot hold the model (`references/parallelism-multinode.md`).

### Upgrade

- [ ] `references/updating.md`: read release notes, pin, smoke test, benchmark, keep the old version until verified.

### Debug a failure

- [ ] Capture the exact error and the first 100 log lines (use `--log-level INFO`), then match
      `references/troubleshooting.md`.

## Reference index

- `references/install.md`: pip, Docker, source, ROCm and other devices, offline use.
- `references/serve-config.md`: `lmdeploy serve api_server` and `proxy` flags by group, env vars.
- `references/models-and-formats.md`: engine support, AWQ/GPTQ, KV-cache quantization, memory budget.
- `references/parallelism-multinode.md`: tp, dp, ep, cp, Ray multi-node, proxy, DistServe.
- `references/features.md`: tool and reasoning parsers, structured output, LoRA, VLM, speculative decoding.
- `references/api.md`: endpoints, auth limits, admin routes.
- `references/performance-tuning.md`: knobs by symptom, benchmark scripts.
- `references/integrations.md`: LiteLLM, llama-swap, OpenAI SDK, Claude Code, Codex, Kubernetes.
- `references/observability.md`: `lmdeploy:*` metrics, Grafana stack, health.
- `references/updating.md`: upgrade procedure.
- `references/troubleshooting.md`: error string to cause to fix.
- `templates/`: `docker-compose.yml`, `lmdeploy.service`, `k8s-deployment.yaml`.

## Companion skills

- `choosing-inference-engine`: compare LMDeploy with vLLM, SGLang and others. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `llama-swap`, `litellm`: routing and gateways in front of LMDeploy. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `tool-calling-parsers`, `structured-outputs`: parser and schema detail. Install: `npx skills add ScaleDockHQ/llms-skills --skill tool-calling-parsers`.
- `model-quantization`: other quantization paths. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `llm-observability`: traces, cost and evals. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
