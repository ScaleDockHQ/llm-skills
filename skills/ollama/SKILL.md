---
name: ollama
description: Install, run and tune the Ollama local LLM server (ollama pull, run, serve, create, ps) on macOS, Linux, Windows and Docker, with Modelfiles, OLLAMA_* env vars, context length, keep-alive, parallelism, GPUs, OpenAI/Anthropic APIs, tools, embeddings, cloud models and updating. Use for ollama.service, port 11434, OLLAMA_HOST, num_ctx, hf.co GGUF import, "LoRA adapters are no longer supported", 403 behind a proxy, CPU instead of GPU or truncated prompts.
license: MIT
compatibility: macOS 14+, Linux (amd64/arm64, NVIDIA, AMD ROCm, Vulkan, Jetson), Windows 10 22H2+, Docker. Needs a shell with curl and jq. Installs, services, env changes and network exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Ollama

Get Ollama installed, serving the right models with the right context, parallelism and memory limits, reachable only by whoever should reach it, and kept up to date.

**Scope:** Ollama only (`ollama` CLI and server, Modelfiles, its REST, OpenAI and Anthropic APIs, its cloud models). Choosing between engines is a different job (`choosing-inference-engine`), as is the gateway in front (`llm-gateway`, `litellm`).

Work through the steps in order. Load a reference only when a step names it. Verified against Ollama v0.40.3 (2026-10-11).

## Discover first

Read-only. Never print keys.

```bash
command -v ollama && ollama -v                      # client and server versions
curl -s http://127.0.0.1:11434/api/version | jq .   # is a server answering, and which version
curl -s http://127.0.0.1:11434/api/ps | jq '.models[]|{name,size,size_vram,context_length,expires_at}'
ollama ls                                           # local models
ollama ps                                           # PROCESSOR must say "100% GPU"
systemctl status ollama --no-pager 2>/dev/null | head -5   # Linux service
docker ps --filter ancestor=ollama/ollama --format '{{.Names}} {{.Image}} {{.Ports}}' 2>/dev/null
env | grep -E '^OLLAMA_' ; systemctl show ollama -p Environment 2>/dev/null
nvidia-smi -L 2>/dev/null; ls /dev/kfd 2>/dev/null   # NVIDIA / AMD present?
```

Note how it runs: desktop app (macOS/Windows), systemd service, container, or a foreground `ollama serve`. Environment variables are set differently for each (`references/serve-config.md`).

## Decision flow

1. No Ollama and the user wants it: pick the platform section in `references/install.md`. Show the command and ask before running an install script.
2. Server runs but answers are cut off or agents "forget": the default context is 4k below 24 GiB VRAM. Set `OLLAMA_CONTEXT_LENGTH` (at least 64000 for agents and coding tools) and check `ollama ps` stays `100% GPU`.
3. `ollama ps` shows a CPU share: model plus context plus parallel slots do not fit. Lower context, `OLLAMA_NUM_PARALLEL`, KV cache type, or pick a smaller quant (`references/performance-tuning.md`).
4. GPU not used: `references/troubleshooting.md` (driver, `nvidia-smi`, container toolkit, ROCm 7, Vulkan).
5. A model is only on Hugging Face as GGUF: `ollama run hf.co/<user>/<repo>:<quant>` or a Modelfile `FROM ./file.gguf` (`references/models-and-formats.md`).
6. Other machines or tools must reach it: bind deliberately, add auth in front, never expose 11434 raw (`references/serve-config.md`, `references/combos/lan-and-tunnels.md`).
7. Behind llama-swap or LiteLLM: one scheduler per memory pool (`references/combos/llama-swap.md`, `references/integrations.md`).
8. Need cloud-hosted models or web search: `ollama signin` or an API key; `OLLAMA_NO_CLOUD=1` turns it all off (`references/features.md`).
9. Need continuous batching at scale, LoRA serving or tensor parallelism: Ollama is the wrong tool (`references/parallelism-multinode.md`).

## Rules

- **Ask before changing the system.** Install scripts, systemd units, `OLLAMA_HOST` changes, firewall rules and Docker runs need approval and an undo path (`references/install.md` has uninstall).
- **No auth on the local API.** Anyone who can reach port 11434 can run, pull and delete models. Keep loopback; put a reverse proxy, VPN or tunnel with auth in front for anything else.
- **Secrets never touch output.** `OLLAMA_API_KEY` and `~/.ollama/id_ed25519*` stay in env vars or `0600` files; never echo them.
- **Set context explicitly.** The default depends on detected VRAM and on unified-memory machines the heuristic can mislead. Over `/v1` the context cannot be set per request; use the env var or a Modelfile `PARAMETER num_ctx`.
- **One scheduler per memory pool.** Ollama keeps up to 3 models per GPU loaded for 5 minutes by default; combine that with llama-swap or another engine only with fixed limits.
- **LoRA adapters are rejected.** `ADAPTER` fails with "LoRA adapters are no longer supported"; merge into the base and import the merged weights.
- **Verify upstream.** Variables, defaults and API support change quickly (the project ships weekly); check `ollama serve --help` and the docs for the installed version.

## Workflows

- [ ] **Install** -> `references/install.md` (macOS app/script/brew, Linux script/manual/ROCm/ARM, Windows, Docker NVIDIA/ROCm/Vulkan/Jetson). Verify: `ollama -v` and `/api/version` agree.
- [ ] **Serve and configure** -> `references/serve-config.md`, `templates/` (systemd drop-in, docker-compose, Kubernetes). Verify: effective env shown by the discovery block.
- [ ] **Pull, import, customize models** -> `references/models-and-formats.md` (library, `hf.co`, GGUF, safetensors, Modelfile). Verify: `ollama show <model>` and a one-line `ollama run`.
- [ ] **Tune** -> `references/performance-tuning.md` (context, KV cache, flash attention, keep-alive, parallelism, offload). Verify: `ollama ps` = `100% GPU` at the intended context.
- [ ] **Use features** -> `references/features.md` (tools, thinking, structured outputs, vision, embeddings, cloud, web search) and `references/api.md`.
- [ ] **Connect clients and gateways** -> `references/integrations.md`, `references/combos/`.
- [ ] **Observe** -> `references/observability.md` (logs, `/api/ps`, debug flags).
- [ ] **Scale out** -> `references/parallelism-multinode.md` (multi-GPU, several instances, when to switch engine).
- [ ] **Update** -> `references/updating.md`. Verify: new `/api/version`, every model still answers.
- [ ] **Troubleshoot** -> `references/troubleshooting.md`.

## Smoke test

```bash
ollama pull qwen3:8b            # any tag from https://ollama.com/library
curl -s http://127.0.0.1:11434/api/chat -d '{"model":"qwen3:8b","messages":[{"role":"user","content":"Say hi"}],"stream":false}' | jq -r '.message.content'
curl -s http://127.0.0.1:11434/v1/models | jq -r '.data[].id'
```

## Reference index

- `references/install.md`: every platform, version pinning, uninstall.
- `references/serve-config.md`: all `OLLAMA_*` variables, where to set them per platform, binding and CORS, models directory.
- `references/models-and-formats.md`: library tags, `hf.co` GGUF, safetensors, Modelfile, `ollama` CLI.
- `references/parallelism-multinode.md`: scheduler, multi-GPU, instances, limits.
- `references/features.md`: tools, thinking, structured outputs, vision, embeddings, cloud, web search.
- `references/api.md`: native, OpenAI and Anthropic endpoints and what they do not support.
- `references/performance-tuning.md`: context, KV cache, flash attention, keep-alive, offload.
- `references/integrations.md`: clients, `ollama launch`, llama-swap, LiteLLM, Open WebUI, Kubernetes.
- `references/observability.md`: logs, status endpoints, debug.
- `references/updating.md`: upgrade and rollback per platform.
- `references/troubleshooting.md`: symptom to cause to fix.
- `references/combos/hugging-face-gguf.md`, `llama-swap.md`, `lan-and-tunnels.md`: verified combinations.
- `templates/`: `ollama.service.d/override.conf`, `docker-compose.yml`, `kubernetes.yaml`, `Modelfile`.

## Companion skills

- `llama-cpp`: exact engine flags, new architectures first. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `llama-swap`: model swapping in front of several engines. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `litellm`: keys, routing and budgets in front of Ollama. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llm-clients`: pointing coding agents and chat UIs at Ollama. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-clients`.
- `local-llms`: choosing a runtime on a laptop. Install: `npx skills add ScaleDockHQ/llm-skills --skill local-llms`.
- `self-hosted-llms`: the full self-hosted stack. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `tailscale`, `cloudflare-tunnel`: private or tunnelled access. Install: `npx skills add ScaleDockHQ/llm-skills --skill tailscale`.
- `nvidia-dgx-spark`: unified-memory specifics. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`.
- `hugging-face`: finding and downloading GGUFs. Install: `npx skills add ScaleDockHQ/llm-skills --skill hugging-face`.
