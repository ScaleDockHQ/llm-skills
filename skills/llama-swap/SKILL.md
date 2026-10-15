---
name: llama-swap
description: Install, configure and operate llama-swap, the Go proxy that hot-swaps local models behind one OpenAI/Anthropic-compatible URL. Use for llama-swap config.yaml, model swapping, TTL unload, groups or matrix routing, setParamsByID aliases, Docker/Podman cmdStop, unified-cuda13 images, peers, API keys, preload hooks, or errors like 502 proxy error EOF, healthCheckTimeout, model won't load. Fronts llama.cpp, vLLM, SGLang, Ollama, ComfyUI, sd.cpp.
license: MIT
compatibility: Linux, macOS, Windows or FreeBSD; one static binary or a Docker/Podman image; bash, curl and jq for the discovery commands. Installing, restarting a service or exposing the port needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# llama-swap

Run many models behind one endpoint. llama-swap reads the `model` field of each request, starts the matching upstream server, and stops the one that was in the way.

**Scope:** llama-swap itself: install, `config.yaml`, routing, operation, update, troubleshooting. Engine flags belong to the engine skills (`vllm`, `llama-cpp`, `sglang`). Gateway features (keys per user, budgets) belong to `litellm`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print keys; `apiKeys` values stay out of output.

```bash
command -v llama-swap && llama-swap -version
docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -i llama-swap
systemctl status llama-swap --no-pager 2>/dev/null | head -5
# Running instance (adjust the port; add -H "Authorization: Bearer $(cat ~/.llama-swap.key)" if apiKeys is set)
curl -fsS 127.0.0.1:8080/health; curl -fsS 127.0.0.1:8080/running | jq .
curl -fsS 127.0.0.1:8080/v1/models | jq -r '.data[].id'
# Config location, from the unit or process arguments
ps -eo args | grep -E '[l]lama-swap.*-(config|listen)'
```

## Decision flow

1. No llama-swap yet and several models that do not all fit at once: install it (`references/install.md`), start from `templates/config.yaml`.
2. Models run in containers: use `cmd` with `docker run --name ${MODEL_ID}` plus `cmdStop: docker stop ${MODEL_ID}`, and raise `unloadTimeout` (`references/config-schema.md`).
3. Two large models must never coexist but small ones should: use groups (`references/routing.md`). Arbitrary allowed combinations (LLM + TTS + reranker): use `matrix`.
4. One model needs several parameter variants (reasoning effort, thinking off): use `filters.setParamsByID`, never a second copy of the model.
5. Clients need keys, CORS or remote peers: `apiKeys`, `security.cors`, `peers` (`references/config-schema.md`).
6. A model will not load, requests hang or return 502: `references/troubleshooting.md`.
7. Behind LiteLLM, Caddy, Cloudflare or nginx: `references/integrations.md`.
8. Upgrading: `references/updating.md`.

## Rules

- **Ask before changing the system.** Installs, systemd units, restarts (which unload every model) and exposure need approval and an undo path.
- **Bind loopback.** llama-swap starts processes on the host. `apiKeys` is not a substitute for a firewall; put LiteLLM or a reverse proxy in front of anything non-local.
- **Secrets stay out of the file.** Use `${env.VAR}` in `apiKeys` and `peers.*.apiKey`; the config fails to load if the variable is unset, which is intended.
- **`healthCheckTimeout` must exceed the real cold-load time**, otherwise llama-swap kills a model about to become ready.
- **Containers need `cmdStop`.** Without it SIGTERM reaches `docker run`, not the container, and engines leak.
- **Verify upstream.** Config keys and image tags change between releases; read `docs/config.example.yaml` at the installed version (`references/updating.md`).

## Workflows

- [ ] Install: pick binary, Homebrew, WinGet or the unified image -> `references/install.md`
- [ ] First config: copy `templates/config.yaml`, change `cmd`, run the command alone with a fixed port first -> `references/config-schema.md`
- [ ] Add a model or an alias variant -> `references/config-schema.md`
- [ ] Control residency (groups, matrix, TTL, preload) -> `references/routing.md`
- [ ] Run as a service -> `templates/llama-swap.service` or `templates/docker-compose.yml`
- [ ] Observe (logs, Activity, `/metrics`) -> `references/operations.md`
- [ ] Update -> `references/updating.md`
- [ ] Verify: `/health` returns `OK`, `/v1/models` lists the expected IDs, one request to each model loads it, `/running` shows it, and `POST /api/models/unload` clears it.

## Reference index

- `references/install.md`: binary with checksum, Homebrew, MacPorts, WinGet, unified and legacy Docker images, `LLAMA_SWAP_*` variables.
- `references/config-schema.md`: global and per-model keys, macros, filters, capabilities, apiKeys, security, peers.
- `references/routing.md`: groups, matrix DSL, profiles, selectors, TTL, preload, concurrency and queues.
- `references/api.md`: OpenAI, Anthropic, llama-server, sd.cpp and llama-swap endpoints, logs streaming, auth.
- `references/operations.md`: logs, Activity, metrics, Prometheus/Grafana, reverse proxy, security.
- `references/integrations.md`: engines, LiteLLM, Caddy/nginx, Kubernetes (kubeswap).
- `references/updating.md`: upgrade, rollback, checking config against a new release.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/litellm.md`: LiteLLM in front of llama-swap.
- `references/combos/comfyui-images.md`: ComfyUI behind llama-swap.
- `references/combos/dgx-spark.md`: one node or two, container engines through a wrapper.
- `templates/`: `config.yaml`, `llama-swap.service`, `docker-compose.yml`.

## Companion skills

- `llama-cpp`: the engine llama-swap was built around. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `vllm`: container engine behind `cmd`/`cmdStop`. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `litellm`: keys, budgets and routing in front. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `nvidia-dgx-spark`: the platform profile this stack was proven on. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`.
- `self-hosted-llms`: the full stack (gateway, exposure, catalog). Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `local-llms`: laptop setups that use llama-swap with llama.cpp. Install: `npx skills add ScaleDockHQ/llm-skills --skill local-llms`.
