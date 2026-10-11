---
name: mistral-rs
description: Install, serve and tune mistral.rs, the Rust LLM inference engine with the `mistralrs` CLI (run, serve, tune, doctor, from-config), ISQ/UQFF/GGUF quantization, paged attention, and OpenAI, Responses and Anthropic APIs with a built-in web UI. Use for installer, Docker (ghcr.io/ericlbuehler/mistral.rs), Metal, CUDA or CPU setup, multi-GPU/NCCL, LoRA, MTP speculative decoding, agent/code-exec safety, Prometheus. Fixes OOM on load, gated repos, CUDA lane mismatch. Not for choosing an engine (choosing-inference-engine) or vLLM, llama.cpp.
license: MIT
compatibility: macOS Apple Silicon (Metal), Linux x86_64/aarch64 (NVIDIA Ampere or newer, or CPU) and Windows (CPU); bash, curl and jq. Installs, services, network exposure and agent code/shell execution need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# mistral.rs

Gets a `mistralrs` server running with the right accelerator build and quantization for the model and hardware,
exposed safely, observable and updatable. Verified against mistral.rs v0.9.4 (2026-10-11).

**Scope:** mistral.rs only: install, serve, quantize, tune, scale out, update, troubleshoot. Picking an engine,
gateways and agent clients belong to the sibling skills at the end.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# What is installed
command -v mistralrs && mistralrs --version
ls -la ~/.mistralrs 2>/dev/null | head -5
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -i 'mistral.rs' || true
pip list 2>/dev/null | grep -i '^mistralrs' || true

# Hardware and driver (the installer picks a CUDA lane from this)
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv 2>/dev/null
nvidia-smi | sed -n 3p            # header line shows "CUDA Version"
uname -sm; free -h 2>/dev/null | head -2

# Built-in diagnosis: hardware, compiled accelerator features, Hugging Face connectivity
mistralrs doctor

# What is running (default port 1234)
ss -ltnp 2>/dev/null | grep -E ':1234\b' || true
curl -s -m 3 http://127.0.0.1:1234/v1/models | jq '.data[] | {id, status}'
curl -s -m 3 -o /dev/null -w 'health %{http_code}\n' http://127.0.0.1:1234/health
```

`mistralrs serve -h` and `mistralrs <command> -h` are the source of truth for flags on the installed version.

## Decision flow

1. **No mistral.rs yet** -> `references/install.md`: the install script (read it first), a pinned release with
   `MISTRALRS_INSTALL_TAG`, a pinned Docker tag, `pip install mistralrs`, or a source build.
2. **Check the GPU.** NVIDIA must be Ampere (sm80) or newer; Turing and older have no prebuilts. Apple Silicon uses Metal.
   `references/install.md` has the driver-to-lane table.
3. **Does the model fit?** Run `mistralrs tune -m <model>` for a quantization and device-map estimate (it reads configs,
   it does not load or benchmark). Then `--quant 4` (or `auto`, or a GGUF repo with `--quant`) in
   `references/models-and-formats.md`.
4. **Write the serve command** from `references/serve-config.md`, or a TOML file with `mistralrs from-config`.
   Always set `--host 127.0.0.1` (default is `0.0.0.0`) and size the KV pool explicitly.
5. **There is no authentication.** Put TLS and auth in a reverse proxy (`references/api.md`). Never enable
   `--agent`, `--enable-shell` or `--enable-code-execution` on a server that others can reach.
6. **Start and verify**: `/health` (liveness only), `/v1/models` (per-model `status`), one chat completion, one tool call, one stream.
7. **Tune** concurrency, KV pool and prefix cache (`references/performance-tuning.md`), watch `/metrics`
   (`references/observability.md`).
8. **Persist** with `templates/mistralrs.toml` plus `templates/docker-compose.yml`, `templates/mistralrs.service` or
   `templates/k8s-deployment.yaml`.
9. **Break or upgrade**: `references/troubleshooting.md`, `references/updating.md`.

## Quick start

```bash
# Install (read the script before running it; pin a release)
curl -fsSL https://mistralrs.dev/install.sh -o /tmp/mistralrs-install.sh && less /tmp/mistralrs-install.sh
MISTRALRS_INSTALL_TAG=v0.9.4 sh /tmp/mistralrs-install.sh

mistralrs doctor
mistralrs serve --host 127.0.0.1 --port 1234 -m Qwen/Qwen3-4B --quant 4 --max-seqs 16

curl -s http://127.0.0.1:1234/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"default","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq '.choices[0].message'
```

The model name `default` always routes to the server's default model; `GET /v1/models` lists real IDs. The first
start downloads weights and (with `--quant 4`) may quantize while loading. Gated models: `mistralrs login`
(prompts for the token) or `HF_TOKEN` in the environment, never on a command line you will show.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules, exposure and updates need approval and an
  undo path. Never benchmark a server other people use.
- **Secrets never touch output.** `HF_TOKEN` and tokens saved by `mistralrs login` (`$HF_HOME/token`) stay in `0600`
  files or the environment. Do not use `--token-source literal:<token>`; use `env:NAME` or `path:FILE`.
- **No built-in auth, so bind to loopback or a private network.** `Authorization` and `x-api-key` headers are accepted
  and ignored. CORS allows any origin and the body limit is 50 MB, neither is CLI-configurable.
- **Agent tools are remote code execution.** `--agent`, `--enable-code-execution`, `--enable-shell` run model-written
  Python or shell on the host. Keep the sandbox on (default `auto` on Linux and macOS), prefer `--agent-permission ask`,
  and do not expose such a server.
- **Pin versions.** `MISTRALRS_INSTALL_TAG`, `pip install mistralrs==X.Y.Z` or a versioned image tag; never `*-latest`
  in production. Model IDs resolve to `main` at download time (the CLI has no revision flag).
- **Read installer scripts before running them.** `curl | sh` is upstream's quick path; download, read, then run.
- **Verify upstream.** Flags move between releases. Run `-h` on the installed binary.
- **Do not use `-l/--log` on shared hosts.** It records full requests and responses.
- **Measure before and after** every tuning change, with the version recorded.

## Facts that surprise people (v0.9.4)

- One binary, three jobs: `run` (chat), `serve` (HTTP), `bench`; plus `tune`, `doctor`, `from-config`, `quantize`,
  `login`, `cache`, `update`, `uninstall`. Default port 1234, default host `0.0.0.0`, web UI at `/ui` on by default.
- `--quant 4` is not always quantization: it first picks a published UQFF or GGUF artifact and only falls back to in-situ
  quantization (ISQ). `--isq` forces ISQ and skips the lookup.
- `/health` and `/` return 200 when the server listens, not when the model is loaded. Readiness is `/v1/models` `status`.
- Paged attention is on by default on CUDA only; off on Metal and CPU. Without a size flag the KV pool takes 90% of VRAM.
- `--max-seqs` defaults to 32 (CLI), 16 (Python `Runner`). Prefix cache holds 16 prefixes by default.
- One `serve -m` process loads one model; several models need `from-config` with `[[models]]`.
- Sessions, uploaded files and skills are in memory; sessions have a 30-minute idle TTL and a 128 cap.
- MTP and DFlash speculative decoding need paged attention (CUDA); drafts exist for Gemma 4 and Qwen3.5/3.8 only.
- Minimum NVIDIA GPU is Ampere (sm80). Prebuilts bundle CUDA libraries but the driver must be new enough for the lane.

## Workflows

### Serve a model on one machine

- [ ] Run discovery and `mistralrs doctor`; install per `references/install.md`.
- [ ] `mistralrs tune -m <model> --emit-config config.toml` for a starting plan; review it.
- [ ] Serve on loopback with an explicit KV pool (`--pa-memory-fraction` or `--pa-context-len`) and `--max-seqs`.
- [ ] Wait for `/v1/models` to show `loaded`; run the smoke tests in Decision flow step 6.
- [ ] Persist (`templates/`), behind a reverse proxy with auth if reachable by others.

### Fit a bigger model

- [ ] `--quant 4` (or 6, 8), a GGUF repo with `--quant`, or `--from-uqff`; then multi-GPU
      (`references/parallelism-multinode.md`) or CPU offload by device mapping.

### Local agent with tools

- [ ] Tool calls through the API need no extra flags (`references/features.md`). Server-side search, code and shell
      are opt-in and dangerous: loopback only, sandbox on, `--agent-permission ask`.

### Upgrade

- [ ] `references/updating.md`: read release notes, `mistralrs update --tag vX.Y.Z` or new image tag, smoke test, re-benchmark.

### Debug a failure

- [ ] `mistralrs doctor`, then `-v` logs and `references/troubleshooting.md`.

## Reference index

- `references/install.md`: installer, CUDA lane table, Docker tags, pip wheels, source builds, offline use.
- `references/serve-config.md`: `serve` flags by group, TOML config, environment variables.
- `references/models-and-formats.md`: supported architectures, ISQ, UQFF, GGUF, KV cache dtype, memory budget.
- `references/parallelism-multinode.md`: NCCL tensor parallel, device layers, multi-node, ring.
- `references/features.md`: tool calling, structured output, reasoning, LoRA, multimodal, MTP, agents.
- `references/api.md`: endpoints, auth gap, routing, sessions.
- `references/performance-tuning.md`: `bench`, concurrency, paged attention, prefix cache, CPU threads.
- `references/integrations.md`: LiteLLM, Open WebUI, Claude Code, Codex, Kubernetes.
- `references/observability.md`: access logs, request ids, `/metrics`.
- `references/updating.md`: upgrade procedure and recent releases.
- `references/troubleshooting.md`: error to cause to fix.
- `templates/`: `mistralrs.toml`, `docker-compose.yml`, `mistralrs.service`, `k8s-deployment.yaml`.

## Companion skills

- `choosing-inference-engine`: compare mistral.rs with vLLM, llama.cpp and others. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `litellm`, `llama-swap`, `llm-gateway`: routing and auth in front of mistral.rs. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `caddy`, `traefik`: reverse proxy for TLS and auth. Install: `npx skills add ScaleDockHQ/llms-skills --skill caddy`.
- `tool-calling-parsers`, `structured-outputs`, `model-quantization`: technique detail. Install: `npx skills add ScaleDockHQ/llms-skills --skill structured-outputs`.
- `apple-silicon`: Metal host setup. Install: `npx skills add ScaleDockHQ/llms-skills --skill apple-silicon`.
