---
name: xinference
description: Install, serve and operate Xorbits Inference (Xinference), the Python model server and cluster for LLM, embedding, rerank, image, audio and video models behind OpenAI, Responses and Anthropic APIs. Use for xinference-local, xinference launch, xinference-supervisor/worker, xprobe/xinference Docker or Helm, vLLM/SGLang/llama.cpp/MLX engines, auth and API keys, replicas, Xavier, P/D, upgrades. Fixes "model_engine" missing, 401, virtualenv install, GPU OOM. Not for choosing an engine (choosing-inference-engine).
license: MIT
compatibility: Linux (NVIDIA CUDA), macOS Apple Silicon, Windows and Docker or Kubernetes; Python 3.10+ (or the uv-based installer), bash, curl and jq. Installs, services, exposure, auth changes and upgrades need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# Xinference

Gets an Xinference server or cluster running with the right engine per model, authentication on, models
launched with explicit settings, clients connected and the whole thing updatable. Verified against Xinference
v4.0.0 (2026-10-11).

**Scope:** Xinference only: install, serve, tune, scale out, update, troubleshoot. Picking an engine,
quantizing a model and gateways belong to the sibling skills at the end.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# What is installed
command -v xinference xinference-local && xinference --version
pip list 2>/dev/null | grep -Ei '^(xinference|xoscar|xllamacpp|vllm|sglang|mlx)'
uv tool list 2>/dev/null | grep -i xinference
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -i 'xprobe/xinference' || true

# Hardware
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv 2>/dev/null
uname -sm; free -h 2>/dev/null | head -2; nproc 2>/dev/null

# Running server (default http://127.0.0.1:9997)
ss -ltnp 2>/dev/null | grep -E ':9997\b' || true
curl -s -m 3 http://127.0.0.1:9997/status
curl -s -m 3 http://127.0.0.1:9997/v1/admin/setup/status          # needs_setup true = nobody is admin yet
echo "$XINFERENCE_HOME"; ls "${XINFERENCE_HOME:-$HOME/.xinference}" 2>/dev/null
xinference service status 2>/dev/null
```

With authentication on (default since v3.0) `/v1/models` needs a token or API key; use the key from a `0600`
file, for example `curl -H "Authorization: Bearer $(cat ~/.xinference-key)" .../v1/models`.

## Decision flow

1. **Is Xinference the right tool?** It fits one server for many model types (LLM, embedding, rerank, image,
   audio, video), a Web UI, per-model virtual environments and a supervisor/worker cluster. For raw LLM
   throughput on one engine use that engine directly (vLLM, SGLang): see `choosing-inference-engine`.
2. **No Xinference yet** -> `references/install.md`: the one-command installer (uv, isolated), `pip install
   xinference`, `xprobe/xinference` Docker or Helm. Pin the version.
3. **Authentication**: on by default. First start has no admin: create it with `POST /v1/admin/setup` before
   exposing the port (`references/api-and-auth.md`).
4. **Pick the engine per model** with `xinference engine -n <model>`: vLLM or SGLang on Linux+CUDA, MLX on
   Apple Silicon, llama.cpp for GGUF and low memory, Transformers for everything else
   (`references/models-and-engines.md`).
5. **Launch with explicit settings**: `xinference launch --model-engine ... -n ... -s ... -f ... -q ...`, plus
   engine kwargs such as `--gpu_memory_utilization`, a `--model-uid`, `--replica`
   (`references/serve-config.md`).
6. **Verify**: `/status`, `xinference list`, one chat completion, one streamed request, tool call if needed
   (`references/features.md`).
7. **Scale or tune**: replicas, multi-worker, Xavier, P/D, reload without weights
   (`references/parallelism-multinode.md`, `references/performance-tuning.md`).
8. **Persist**: `xinference service install`, `templates/docker-compose.yml`, or Helm.
9. **Connect clients and gateways** (`references/integrations.md`); watch metrics
   (`references/observability.md`).
10. **Upgrade or break**: `references/updating.md`, `references/troubleshooting.md`.

## Quick start

```bash
# Isolated install and foreground start (review the script first: https://github.com/xorbitsai/inference/blob/main/scripts/install.sh)
# or: pip install xinference==4.0.0   (use a venv)
xinference-local --host 127.0.0.1 --port 9997

# First run: create the admin (choose your own password, do not paste secrets into shared logs)
curl -s -X POST http://127.0.0.1:9997/v1/admin/setup -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"<choose-a-strong-password>"}'
xinference login -e http://127.0.0.1:9997 --username admin --password "$(cat ~/.xinference-admin-pass)"   # 0600 file; stores a token under XINFERENCE_HOME/auth/

# Launch a small model. The engine is required for LLMs.
xinference launch --model-engine transformers -n qwen2.5-instruct -s 0_5 -f pytorch
xinference list
```

Use `xinference engine -n qwen2.5-instruct` to see which engine, format and size combinations the model
supports on your workers. The first launch downloads weights and builds a per-model virtual environment, so it
can take many minutes and needs access to PyPI or a mirror.

## Rules

- **Ask before changing the system.** Installs, services, exposure, disabling auth and upgrades need approval
  and an undo path.
- **Keep authentication on.** `XINFERENCE_AUTH_ADVANCED=false` serves every endpoint with no login.
  Whoever reaches `/v1/admin/setup` first on a fresh install becomes admin: create the admin before exposing
  the port, or bind to loopback.
- **Secrets never touch output.** API keys and admin passwords live in `0600` files or environment variables;
  never echo them. The auto-generated JWT secret and encryption key sit under `XINFERENCE_HOME/auth/`: back
  up and protect that directory.
- **Bind deliberately.** `xinference-local` defaults to `127.0.0.1`; containers need `-H 0.0.0.0` plus a
  published port bound to loopback or a private interface. Restrict with `XINFERENCE_ALLOWED_IPS` or a proxy.
- **Pin versions.** Exact `pip` version, image tag `v<release>` or digest, never `latest` or `nightly-main`
  in production; same version on supervisor and every worker; `xinference-client` matches the server.
- **Verify upstream.** Flags change between majors; run `xinference launch --help` and read release notes.
- **Per-model virtual environments install packages at launch** (code runs from PyPI with the worker's
  privileges). Use a private mirror or the offline compose profile for locked-down hosts.
- **Name models.** Set `--model-uid` to the name clients use; default UID equals the model name.
- **Measure before and after** every tuning change, with the version recorded.

## Facts that surprise people (v4.0.0)

- Default port 9997; `/docs` serves the API docs; the Web UI is at `/`. Health: `GET /status`.
- LLM launch needs `--model-engine`; supported combinations depend on the model: `xinference engine`.
- The GPU Docker image is slim (CUDA 13.0, host driver 580+): engines other than Transformers install at
  first launch into a per-model virtualenv. Some older doc pages still show CUDA 12.x tags.
- Authentication is on by default since v3.0; the old `--auth-config` JSON is gone. Roles are permissions such
  as `models:read`, `models:write`, `keys:create`, `admin`.
- Media fetch is locked down since v3.5: private-network `image_url` hosts and `file://` paths are rejected
  unless `XINFERENCE_MEDIA_BLOCK_PRIVATE_ADDRESS=false` or `XINFERENCE_MEDIA_ALLOW_LOCAL_PATH=true`.
- `/v1/responses` is stateless (no `previous_response_id`); `/anthropic/v1/messages` serves Anthropic clients.
- `xinference service install --start` registers a systemd user, LaunchAgent or Windows service (v4.0).
- `--replica-config` (kebab) is preferred over `--replica_config`; `--model-path` over `--model_path`.
- llama.cpp runs through `xllamacpp` (maintained by the Xinference team); `llama-cpp-python` was removed.

## Workflows

### Serve models on one machine

- [ ] Run discovery; install and pin (`references/install.md`).
- [ ] Create the admin and an API key for clients (`references/api-and-auth.md`).
- [ ] Choose engine and size (`references/models-and-engines.md`); launch with explicit options.
- [ ] Smoke test chat, streaming, tools, embeddings if used; save the launch command.
- [ ] Persist (`xinference service install`, `templates/`).

### Multi-GPU and multi-node

- [ ] Replicas for throughput, `--n-gpu`, `--n-worker` for models too big for one node
      (`references/parallelism-multinode.md`). Same version everywhere; supervisor reachable from workers.

### Offline or restricted network

- [ ] Docker Compose `offline` profile with the private PyPI mirror, or `XINFERENCE_MODEL_SRC` and mirrors
      (`references/install.md`, `references/troubleshooting.md`).

### Upgrade

- [ ] `references/updating.md`: read release notes, upgrade with the same installer or a new image tag, relaunch
      models (running models are not preserved across a service restart), smoke test, keep a rollback.

### Debug a failure

- [ ] Capture the exact error and `xinference-local` log, then match `references/troubleshooting.md`.

## Reference index

- `references/install.md`: installer, pip, uv, Docker, Compose (incl. offline), Helm, services, GPU image notes.
- `references/serve-config.md`: CLI commands and flags, launch options, environment variables.
- `references/models-and-engines.md`: engines, formats, custom models, virtual environments, LoRA, downloads.
- `references/parallelism-multinode.md`: replicas, supervisor and workers, distributed vLLM/SGLang/MLX, Xavier, P/D, reload.
- `references/features.md`: tools, reasoning, Responses and Anthropic APIs, embeddings, rerank, image, audio, video.
- `references/api-and-auth.md`: endpoints, users, permissions, API keys, OIDC, audit, IP allow list.
- `references/performance-tuning.md`: batching, memory, engine kwargs, caches.
- `references/integrations.md`: LiteLLM, llama-swap, Open WebUI, Dify and others, Kubernetes, proxies.
- `references/observability.md`: `/metrics`, logs, request logs, health.
- `references/updating.md`: upgrade and rollback, breaking changes.
- `references/troubleshooting.md`: error to cause to fix.
- `templates/`: `docker-compose.yml`, `launch.sh`.

## Companion skills

- `choosing-inference-engine`: Xinference vs vLLM vs SGLang vs llama.cpp. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-inference-engine`.
- `vllm` and `sglang`: engine-level flags that Xinference passes through. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `llama-cpp` and `mlx`: the GGUF and Apple Silicon engines. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `litellm` and `llm-gateway`: keys, routing, fallbacks. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llama-swap`: on-demand swapping alternative. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `multi-node-inference`, `prefix-aware-routing`, `disaggregated-serving`: technique-level guidance. Install: `npx skills add ScaleDockHQ/llm-skills --skill multi-node-inference`.
- `llm-observability`: traces and cost around the server. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
