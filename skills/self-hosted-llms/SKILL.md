---
name: self-hosted-llms
description: Plan, set up, operate, update, benchmark, optimize and clean up a self-hosted LLM and generative-AI serving stack on your own Linux servers with NVIDIA GPUs, with NVIDIA DGX Spark (GB10, single or dual node over ConnectX-7) as the first-class profile. Builds one public, authenticated, OpenAI-compatible endpoint (plus Anthropic Messages and Responses bridging) from a LiteLLM gateway, llama-swap model swapping and engine containers such as vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, ExLlamaV3/TabbyAPI, TensorFold and stable-diffusion.cpp, exposed through Cloudflare Tunnel or Tailscale. Use when serving models on a GPU server or DGX Spark, adding or swapping a model, adding an engine or image server, updating inference recipes from upstream, benchmarking tok/s, tuning throughput, fixing OOM freezes, 502/524/530 errors or slow cold swaps, enriching /v1/models for clients, or connecting Cursor, Claude Code, Open WebUI or LobeHub to the endpoint.
license: MIT
metadata:
  author: ScaleDockHQ
  version: "1.2.0"
compatibility: Linux hosts with NVIDIA GPUs (DGX Spark first-class); Docker, NVIDIA Container Toolkit, systemd, bash, curl, jq; shell/SSH access to the nodes.
---

# Self-Hosted LLMs

Run your own inference servers as one stable, authenticated, OpenAI-compatible endpoint. The reference
stack is: client -> Cloudflare Tunnel or Tailscale -> LiteLLM gateway -> llama-swap -> engine containers
on node-a (plus node-b as a worker over ConnectX-7), with `/v1/models` served from an enriched static
catalog. Every layer is optional; `references/architecture.md` explains when to drop one.

In scope: hardware profiles, host prep, memory safety, weights, engines, swapping, gateway minimum,
exposure, catalog, reasoning-effort mapping, benchmarking, optimization, updates, cleanup, troubleshooting.
Out of scope (use the companion skill): deciding whether to self-host, laptops, rented cloud, deep
gateway features, per-client setup, evals, producing quants, fine-tuning, observability stacks.

## Discover first

Inspect the live system before proposing anything. All commands are read-only and print no secrets.
Run them on node-a, and on node-b through `ssh node-b '<cmd>'` when a second node exists.

```bash
uname -m; nvidia-smi --query-gpu=name,driver_version --format=csv,noheader; nvidia-smi -L
free -h; swapon --show; df -h / ~/.cache/huggingface 2>/dev/null
systemctl list-units --type=service --no-pager | grep -Ei 'llama-swap|litellm|caddy|catalog|cloudflared|tailscale|earlyoom|ollama|docker'
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
ss -ltnp 2>/dev/null | awk 'NR==1 || /127.0.0.1|0.0.0.0|\[::\]/'
curl -s http://127.0.0.1:8080/running | jq .          # llama-swap: what is loaded now
curl -s http://127.0.0.1:4000/health/liveliness; echo # LiteLLM liveness (no auth)
docker image ls --format '{{.Repository}}:{{.Tag}}\t{{.ID}}' | sort
ls ~/.cache/huggingface/hub 2>/dev/null | head -50
```

The full snapshot (configs filtered for keys, recipe repo HEAD vs upstream, image IDs on both nodes)
is in `references/status.md`. Ports above are the reference port map; use `ss` output when they differ.

Ask the user only what cannot be discovered: the public hostname and exposure method (Cloudflare,
Tailscale, none), which models they want and for which clients, whether downtime is acceptable now
and for how long, and whether a second node is planned but not yet cabled.

## Decision flow

1. **Is self-hosting right?** If the user is still deciding between local, self-hosted, cloud or hybrid,
   stop and use `choosing-llm-hosting`. A laptop or desktop -> `local-llms`. Rented GPUs, serverless or
   Kubernetes in a cloud -> `cloud-llms`.
2. **What hardware?** DGX Spark (unified memory, arm64) -> `references/hardware-dgx-spark.md`. Other
   NVIDIA Linux hosts (discrete VRAM, x86 or arm64, multi-GPU) -> `references/hardware-generic.md`.
3. **How many nodes?** One node unless a model does not fit or needs tensor parallel across two Sparks.
   Two nodes means matching images, weights and configs on both (Rule 5).
4. **Does the model fit?** Budget weights + KV cache + activation/runtime overhead + OS headroom, per node
   -> `references/hardware-dgx-spark.md` (memory budgeting) and `references/models-and-weights.md`.
5. **Co-resident or exclusive?** Several small models that fit together -> a non-exclusive llama-swap
   group. Large models -> one exclusive group; swapping costs a cold start -> `references/llama-swap.md`.
6. **Which engine?** Pick per model by format and features -> engine references (index below).
7. **Which layers?** Engine only, llama-swap only, LiteLLM only, or both -> `references/architecture.md`.
8. **Public or tailnet-only?** Public with API keys -> `references/exposure-cloudflare.md`. Private to your
   devices -> `references/exposure-tailscale.md`.

## Rules

- **One endpoint, many models.** Clients see stable model names; the gateway routes, the swapper manages lifecycle.
- **Measure before and after.** No update or optimization without a baseline and the same protocol afterwards.
- **Download while serving, rebuild while stopped.** On unified memory, compiles and unbounded downloads can kill a serving node.
- **Cap every background job.** Downloads, rsyncs and builds run in memory-limited scopes.
- **Both nodes, always.** Images, weights and configs must match on every node; verify image IDs, not tags.
- **Downtime is a decision.** Announce expected duration and get confirmation before stopping a public endpoint.
- **Secrets never touch output.** Read keys in subshells; never echo, log, commit or tee them.
- **Numerics-changing options need a quality gate.** Quantization, KV-cache dtype, speculative decoding or a new engine pass a task eval (`llm-evals`), not only a speed benchmark.
- **Clean up only after verification**, and ask before deleting weights or rollback paths.
- **Services, not nohup.** Anything that must survive a reboot or outage is a systemd unit.

Rationale and the incidents behind each rule: `references/memory-safety.md` (rules 3-4),
`references/updating.md` (rules 2, 5), `references/security.md` (rule 7), `references/optimization.md`
(rule 8), `references/cleanup.md` (rule 9), `references/exposure-cloudflare.md` (rule 10).

## Workflows

### Status

- [ ] Run the discovery block above on every node; then the full checklist -> `references/status.md`
- [ ] Report: loaded model(s), containers per node, memory/swap, disk, services, upstream drift
- [ ] If anything is unhealthy, continue with Troubleshoot

### First-time setup (single node)

- [ ] Confirm the hardware profile -> `references/hardware-dgx-spark.md` or `references/hardware-generic.md`
- [ ] Prepare the OS, Docker, NVIDIA Container Toolkit, disk layout -> `references/host-setup.md`
- [ ] Install earlyoom and the capped-job pattern before any large download -> `references/memory-safety.md`
- [ ] Download the first model with a pinned revision -> `references/models-and-weights.md`
- [ ] Get one engine serving on loopback and smoke it locally -> the engine reference
- [ ] Put it under llama-swap with `assets/llama-swap.yaml` + `assets/start-model.sh` -> `references/llama-swap.md`
- [ ] Add LiteLLM with `assets/litellm-config.yaml` and a master key -> `references/litellm.md`
- [ ] Install the units from `assets/systemd/` -> `references/host-setup.md`
- [ ] Build the catalog and Caddy front -> `references/model-catalog.md`
- [ ] Expose -> `references/exposure-cloudflare.md` or `references/exposure-tailscale.md`
- [ ] Smoke test through the public URL -> `references/smoke-test.md`
- [ ] Record a baseline -> `references/benchmarking.md`

### First-time setup (dual node)

- [ ] Everything in single node on node-a first, then:
- [ ] Cable and address the ConnectX-7 link; passwordless SSH both ways -> `references/hardware-dgx-spark.md`, `references/host-setup.md`
- [ ] Same user, same paths, same images (compare IDs) and same weights on node-b -> `references/models-and-weights.md`
- [ ] Use an engine recipe that supports multi-node (vLLM, SGLang, TensorRT-LLM) -> engine reference
- [ ] Wrapper starts the worker on node-b before the head on node-a and stops both -> `references/adding-a-server.md`

### Add a model

- [ ] Check fit and co-residence against the memory plan -> `references/hardware-dgx-spark.md` / `references/hardware-generic.md`
- [ ] Download in a capped scope while serving continues; copy to every node -> `references/models-and-weights.md`
- [ ] Add the llama-swap entry (group, ttl, checkEndpoint, capabilities) -> `references/llama-swap.md`
- [ ] Add the LiteLLM entry with `model_info` -> `references/litellm.md`
- [ ] Add catalog metadata and rebuild -> `references/model-catalog.md`
- [ ] Map reasoning effort if the model reasons -> `references/reasoning-effort.md`
- [ ] Smoke test and benchmark -> `references/smoke-test.md`, `references/benchmarking.md`

### Add a server/engine

- [ ] Check the backend contract and follow the steps -> `references/adding-a-server.md`
- [ ] Engine specifics -> the engine reference; image servers -> `references/engine-sdcpp.md`

### Update from upstream

- [ ] Baseline first -> `references/benchmarking.md`
- [ ] Run the update-check checklist (fetch, log, diff of defaults, image drift) -> `references/updating.md`
- [ ] Download new weights while serving; announce downtime; rebuild while stopped -> `references/updating.md`
- [ ] Same protocol after; keep the rollback image and revision until verified -> `references/updating.md`

### Benchmark

- [ ] Fixed protocol with `scripts/bench.sh` against llama-swap, then through the public URL -> `references/benchmarking.md`

### Optimize

- [ ] One change at a time, baseline vs candidate, quality gate when numerics change -> `references/optimization.md`

### Swap/switch

- [ ] See what is loaded, unload or preload, change groups -> `references/llama-swap.md`
- [ ] Cold swaps longer than the proxy timeout -> `references/exposure-cloudflare.md`

### Expose

- [ ] Cloudflare Tunnel as a systemd service, path-based ingress, Access only on dashboards -> `references/exposure-cloudflare.md`
- [ ] Tailscale Serve for tailnet-only -> `references/exposure-tailscale.md`
- [ ] Re-run the smoke test through the new URL -> `references/smoke-test.md`

### Connect a client

- [ ] Base URL, key, model names, capability flags -> `references/clients.md` (per-client depth -> `llm-clients`)

### Clean up

- [ ] Verify the replacement first, then follow the safe order on both nodes -> `references/cleanup.md`

### Troubleshoot

- [ ] Match the symptom -> `references/troubleshooting.md`; take a status snapshot -> `references/status.md`

## Reference index

| Reference                            | Purpose                                                                    |
| ------------------------------------ | -------------------------------------------------------------------------- |
| `references/architecture.md`         | Reference stack, request path, port map, layering options                  |
| `references/hardware-dgx-spark.md`   | GB10 unified memory, single vs dual node, ConnectX-7, memory budgeting     |
| `references/hardware-generic.md`     | Other NVIDIA Linux hosts, multi-GPU, VRAM vs UMA, rented GPU VMs           |
| `references/host-setup.md`           | OS prep, Docker, NVIDIA Container Toolkit, SSH between nodes, disks, units |
| `references/memory-safety.md`        | earlyoom, capped scopes, container memory limits                           |
| `references/models-and-weights.md`   | Formats and quants, HF CLI, cache layout, revisions, syncing nodes         |
| `references/status.md`               | Read-only status snapshot checklist                                        |
| `references/smoke-test.md`           | curl + jq checks through the public URL                                    |
| `references/engine-vllm.md`          | vLLM wrapper and stack entries; depth in `vllm`                            |
| `references/engine-tensorfold.md`    | TensorFold and DGX Spark recipes                                           |
| `references/engine-exllama.md`       | ExLlamaV3 / EXL3 via TabbyAPI or an OpenAI server                          |
| `references/engine-sglang.md`        | SGLang                                                                     |
| `references/engine-trtllm.md`        | TensorRT-LLM (`trtllm-serve`)                                              |
| `references/engine-llamacpp.md`      | llama.cpp `llama-server` + GGUF                                            |
| `references/engine-ollama.md`        | Ollama as a backend                                                        |
| `references/engine-sdcpp.md`         | stable-diffusion.cpp `sd-server`; ComfyUI alternative                      |
| `references/adding-a-server.md`      | Backend contract and step-by-step with worked examples                     |
| `references/llama-swap.md`           | Swapping, groups, timeouts, filters, hooks, API                            |
| `references/litellm.md`              | Stack-specific LiteLLM minimum                                             |
| `references/model-catalog.md`        | Enriched static `/v1/models` behind Caddy forward_auth                     |
| `references/reasoning-effort.md`     | Per-model effort values and config-only mapping                            |
| `references/exposure-cloudflare.md`  | Tunnel as a service, ingress, Access, timeouts                             |
| `references/exposure-tailscale.md`   | Tailscale Serve, certificates, key expiry                                  |
| `references/monitoring-sparkdash.md` | sparkDash install, probes, allow-list, shutdown helper                     |
| `references/benchmarking.md`         | Fixed protocol with `scripts/bench.sh`                                     |
| `references/optimization.md`         | Evaluating opt-ins: gain, cost, numerics, A/B, gates                       |
| `references/updating.md`             | Upstream update workflow, image drift, rollback                            |
| `references/cleanup.md`              | Safe cleanup order, HF orphans, root-owned files                           |
| `references/clients.md`              | Stack-specific client notes and short snippets                             |
| `references/security.md`             | Secrets, sudo scope, least exposure                                        |
| `references/troubleshooting.md`      | Symptom -> cause -> fix                                                    |
| `references/example.md`              | Anonymized worked example: 2x DGX Spark, 4 models, one endpoint            |

Templates (copy, then edit; all hosts, ports and paths come from env vars or flags):
`assets/llama-swap.yaml`, `assets/litellm-config.yaml`, `assets/build-catalog.sh`,
`assets/catalog.example.json`, `assets/Caddyfile`, `assets/cloudflared-config.yml`,
`assets/start-model.sh`, `assets/common.sh`, `assets/models.d/example-vllm.sh`,
`assets/systemd/*.service`. Script: `scripts/bench.sh` (`--help` for usage).

## Companion skills

Install any of these with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `choosing-llm-hosting` - decide local vs self-hosted vs cloud vs hybrid before building anything.
- `local-llms` - laptops and desktops (Ollama, LM Studio, llama.cpp, MLX).
- `cloud-llms` - frontier and open-model APIs, GPU VMs, serverless GPU, managed endpoints.
- `self-hosted-genmedia` - image, video and speech servers in depth (ComfyUI, sd.cpp, Whisper, TTS).
- `llm-gateway` - LiteLLM and alternatives: keys, budgets, routing, fallbacks, API bridging.
- `llm-clients` - per-client configuration for IDEs, CLIs, chat UIs and SDKs.
- `llm-evals` - quality gates and task evals for model or option changes.
- `stable-diffusion-cpp` - sd-server depth (the engine-sdcpp reference is now a stack note).
- `model-quantization` - producing EXL3, NVFP4, FP8 and GGUF quants.
- `fine-tuning-llms` - training adapters or full fine-tunes to serve here.
- `llm-observability` - metrics, logs and tracing beyond the built-in endpoints.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `exllamav3`, `tensorfold` - engine depth: install, flags, tuning, operating.
- `llama-swap` - router depth: config schema, routing, API, operations.
- `nvidia-dgx-spark` - DGX Spark platform depth: OS, memory, networking, dual node.
- `litellm` - gateway depth beyond the stack minimum.
- `cloudflare-tunnel`, `tailscale` - exposure depth.
