---
name: localai
description: Installs, runs and operates LocalAI (local-ai), the self-hosted OpenAI, Anthropic and Ollama compatible server with a backend gallery for LLMs, embeddings, images, speech and agents. Use for LocalAI, local-ai run, localai/localai image, model gallery, backends install, LOCALAI_API_KEY, model YAML, watchdog, distributed mode, could not load model. Other engines go to choosing-inference-engine.
license: MIT
compatibility: Linux, macOS (launcher DMG) or containers with Docker or Podman; CPU, NVIDIA CUDA 12 or 13, AMD ROCm, Intel, Vulkan or Jetson. Installs, large model downloads, services and exposing a port need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LocalAI

Run LocalAI as a drop-in API server (OpenAI, Anthropic Messages, Open Responses and Ollama style endpoints) that downloads gRPC backends (llama.cpp, vLLM, whisper, diffusers and more) from a gallery and loads models on demand.

**Scope:** this one product: install, serve, configure models, tune, scale out, update, troubleshoot. Cross-engine choices belong to `choosing-inference-engine`. LocalAI embeds other engines as backends; for engine-level tuning use that engine's own skill.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
uname -sm; command -v local-ai docker podman 2>/dev/null
local-ai --version 2>&1 | head -1
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null | grep -i -E 'localai|local-ai'
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>&1 | head -5
ls /dev/kfd /dev/dri 2>&1 | head -3
env | grep -E '^(LOCALAI_|MODELS_PATH|DEBUG)' | sed -E 's/(KEY|SECRET|TOKEN|PASSWORD)=.*/\1=<redacted>/'
ss -ltnp 2>/dev/null | grep -E ':8080\b'
curl -s -m 3 http://127.0.0.1:8080/readyz -o /dev/null -w 'readyz=%{http_code}\n'
curl -s -m 3 http://127.0.0.1:8080/v1/models | jq -r '.data[].id' 2>/dev/null | head   # add the key header if auth is on
```

## Decision flow

1. **Is LocalAI the right tool?** Choose it for one self-hosted gateway that mixes LLM, embeddings, reranking, image, speech and agents with on-demand loading and a web UI. For raw LLM throughput on GPUs use `vllm` or `sglang`; for the plain GGUF server use `llama-cpp`; for a minimal model runner use `ollama`.
2. **Which install?** Container for servers (recommended upstream), the Linux binary for bare metal, the DMG launcher on macOS, Helm or manifests on Kubernetes (`references/install.md`). Pick the GPU image tag that matches the hardware.
3. **Which model?** `local-ai models install <name>` from the gallery, a `huggingface://` or `oci://` URI, or a GGUF file plus a model YAML (`references/models-and-formats.md`).
4. **Serve** with persistent `/models`, `/backends`, `/configuration` and `/data`, an API key, and loopback or reverse-proxy exposure (`references/serve-config.md`).
5. **Several models or limited VRAM?** Set `--max-active-backends` and the watchdogs (`references/performance-tuning.md`).
6. **Many nodes?** Distributed mode needs PostgreSQL and NATS (`references/parallelism-multinode.md`).
7. **Features** like tools, MCP, embeddings, rerank, failover, speech and images: `references/features.md`.
8. **Broken?** `references/troubleshooting.md`; read the server log with `DEBUG=true`.

## Rules

- **Ask before changing the system.** Installs, image pulls, multi-GB model downloads, backend installs, services and exposure need approval.
- **Secrets never touch output.** `LOCALAI_API_KEY`, `HF_TOKEN`, OAuth and NATS secrets go in `0600` env files, never inline or echoed. Redact `env` output.
- **Auth is off by default.** The server refuses a public bind with no auth unless `--allow-insecure-public-bind`; never pass that flag to dodge the check. Set `LOCALAI_API_KEY` (or `LOCALAI_AUTH=true`) and front it with TLS (`references/serve-config.md`).
- **Persist all four paths.** Files outside `/models`, `/backends`, `/configuration` and `/data` vanish on image upgrade.
- **Backends are separate downloads.** A model fails with `all backends returned error` when its backend is not installed; install it, do not retry blindly.
- **Pin versions.** Use a versioned image tag in production, not `latest` or `master`.
- **Verify upstream.** Flags move quickly; confirm with `local-ai run --help`. Verified against LocalAI v4.11.0 on 2026-10-11.

## Workflows

- [ ] Install container, binary or Helm -> `references/install.md`
- [ ] Choose and install a model and backend -> `references/models-and-formats.md`
- [ ] Configure flags, env vars, auth, TLS -> `references/serve-config.md`
- [ ] Smoke test endpoints -> `references/api.md`
- [ ] Multi-model memory and speed -> `references/performance-tuning.md`
- [ ] Scale out with distributed mode -> `references/parallelism-multinode.md`
- [ ] Tools, MCP, embeddings, rerank, failover -> `references/features.md`
- [ ] Wire LiteLLM, clients, systemd, Kubernetes -> `references/integrations.md`, `templates/`
- [ ] Metrics, traces, logs -> `references/observability.md`
- [ ] Update or roll back -> `references/updating.md`
- [ ] Verify: `/readyz` is 200, `/v1/models` lists the model, a chat completion returns text, and `nvidia-smi` shows the expected memory after the first request.

## Quick smoke test

```bash
docker run -d --name local-ai -p 127.0.0.1:8080:8080 --gpus all \
  -v localai-models:/models -v localai-backends:/backends \
  -v localai-config:/configuration -v localai-data:/data \
  localai/localai:latest-gpu-nvidia-cuda-12      # upstream quick start image tag; pin a version for production
docker exec local-ai local-ai models install qwen3-4b     # gallery name from upstream docs; check `models list`
curl -s http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' \
  | jq -r '.choices[0].message.content'
```

## Reference index

- `references/install.md`: container tags per GPU, Linux binary, macOS, Helm, volumes.
- `references/serve-config.md`: `local-ai run` flags and env vars, auth, TLS proxy, bind safety.
- `references/models-and-formats.md`: gallery, URIs, model YAML, backends, GGUF.
- `references/parallelism-multinode.md`: multi-GPU split, RPC workers, distributed mode.
- `references/features.md`: tools, MCP, grammars, embeddings, rerank, failover, speech, images.
- `references/api.md`: endpoints, auth headers, error codes.
- `references/performance-tuning.md`: LRU, watchdog, concurrency, llama.cpp options.
- `references/integrations.md`: LiteLLM, OpenAI SDK, systemd, Kubernetes.
- `references/observability.md`: `/metrics`, traces, health probes, debug logs.
- `references/updating.md`: images, binary, backends, rollback.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/ik-llama-cpp-backend.md`: use the `ik-llama-cpp` backend inside LocalAI.
- `templates/`: `docker-compose.yml`, `local-ai.service`, `litellm-localai.yaml`, `model.yaml`.

## Companion skills

- `choosing-inference-engine`: compare engines. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-inference-engine`.
- `ik-llama-cpp`: the CPU and hybrid fork LocalAI can run as a backend. Install: `npx skills add ScaleDockHQ/llm-skills --skill ik-llama-cpp`.
- `llama-cpp`: the default GGUF backend. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `litellm`: gateway and keys. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `self-hosted-llms`: the end-to-end stack. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
