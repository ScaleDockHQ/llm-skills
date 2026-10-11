---
name: nvidia-dynamo
description: Deploy and operate NVIDIA Dynamo, the datacenter-scale LLM serving layer above vLLM, SGLang and TensorRT-LLM (python3 -m dynamo.frontend, dynamo.vllm, DynamoGraphDeployment). Use for disaggregated prefill/decode, KV-aware routing, NIXL, KVBM, Planner, DGDR, Helm/Kubernetes install, ai-dynamo wheels, nvcr.io/nvidia/ai-dynamo images, etcd/NATS discovery, upgrades, HTTP 529 or worker-not-found errors. Not for one GPU (vllm, sglang), NIM (nvidia-nim) or Triton.
license: MIT
compatibility: Linux x86_64 or arm64 with NVIDIA GPUs (Ampere or newer), Docker with the NVIDIA Container Toolkit or Kubernetes 1.30+ with Helm 3, bash, curl and jq. Installs, cluster changes and exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA Dynamo

Gets a Dynamo deployment running: an OpenAI-compatible frontend plus engine workers (vLLM, SGLang or
TensorRT-LLM), optionally with disaggregated prefill/decode, KV-aware routing and autoscaling. Verified
against Dynamo v1.5.1 (2026-10-11).

**Scope:** Dynamo only. It orchestrates engines, it does not replace them: a single model on a single GPU
needs the engine alone (`vllm`, `sglang`, `tensorrt-llm` skills). Picking an engine or topology across
products belongs to `choosing-inference-engine` and `disaggregated-serving`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
# Local install
python3 -c 'import importlib.metadata as m; print(m.version("ai-dynamo"))' 2>/dev/null
python3 -m dynamo.frontend --help 2>&1 | head -5
docker images --format '{{.Repository}}:{{.Tag}}' | grep -i 'ai-dynamo' || true
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' | grep -i dynamo || true

# Hardware and driver (need 575.51.03+ for CUDA 12, 580.00.03+ for CUDA 13)
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv 2>/dev/null
docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -o nvidia

# Running frontend
curl -s -m 3 -o /dev/null -w 'health %{http_code}\n' http://127.0.0.1:8000/health
curl -s -m 3 http://127.0.0.1:8000/v1/models | jq '.data[].id'
curl -s -m 3 http://127.0.0.1:8000/metrics | grep -E '^dynamo_frontend_(requests|worker)' | head

# Kubernetes
kubectl get crd 2>/dev/null | grep -i dynamo
kubectl get pods -A 2>/dev/null | grep -Ei 'dynamo|grove|kai|nats'
kubectl get dynamographdeployments,dynamographdeploymentrequests -A 2>/dev/null
helm list -A 2>/dev/null | grep -i dynamo
```

## Decision flow

1. **Is Dynamo warranted?** Several GPUs or nodes, shared prefixes (agents, RAG, chat), or separate
   prefill/decode scaling: yes. One model, one GPU: use the engine alone.
2. **Pick the backend** (`vllm`, `sglang`, `trtllm`): all three support disaggregation, KV routing and the
   Planner; KVBM is not yet on SGLang. See `references/features.md`.
3. **Pick the path**: one machine -> `references/install.md` (container or wheel, `--discovery-backend file`);
   a cluster -> Kubernetes platform install plus a `DynamoGraphDeployment` (`references/parallelism-multinode.md`).
4. **Start aggregated first** (frontend plus one worker), verify, then add `--router-mode kv`, then
   disaggregation. Change one thing at a time.
5. **Disaggregation needs a fast KV transfer path** (NIXL over RDMA). Without RDMA on Kubernetes it falls
   back to TCP with a severe TTFT penalty; do not benchmark that.
6. **Expose and observe**: `references/api.md`, `references/observability.md`.
7. **Tune** with AIPerf and one knob at a time (`references/performance-tuning.md`).
8. **Upgrade or debug**: `references/updating.md`, `references/troubleshooting.md`.

## Quick start (one machine, one GPU)

```bash
docker run --gpus all --network host --rm -it -e HF_TOKEN nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.1
# inside the container
python3 -m dynamo.frontend --http-port 8000 --discovery-backend file > /tmp/frontend.log 2>&1 &
python3 -m dynamo.vllm --model Qwen/Qwen3-0.6B --discovery-backend file \
  --kv-events-config '{"enable_kv_cache_events": false}' &
curl -s localhost:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen3-0.6B","messages":[{"role":"user","content":"Hello"}],"max_tokens":32}' | jq .
```

`--network host` binds the frontend on every interface (`--http-host` defaults to `0.0.0.0`): on a shared
host add `--http-host 127.0.0.1`. The README quick start omits the `--kv-events-config` line; the install
docs say vLLM needs it in file-discovery mode. `-e HF_TOKEN` forwards the variable without printing it.

## Rules

- **Ask before changing the system.** Installs, Helm releases, CRDs, services and exposure need approval and an
  undo path (`helm uninstall`, `kubectl delete`).
- **Secrets never touch output.** `HF_TOKEN` comes from the environment or a Kubernetes Secret
  (`hf-token-secret` with `envFrom`); never inline it in a command or manifest.
- **Pin versions.** One Dynamo release for images, wheel and Helm chart. Never `latest`. Mixed versions are
  supported only inside an N-2 window between frontend and workers, not for prefill-to-decode links.
- **The frontend has no auth.** Keep it on loopback or a private network or put a gateway in front
  (`llm-gateway`, `litellm`). `/metrics` is on the same port.
- **Verify upstream.** Flags move between minors. Run `python3 -m dynamo.frontend --help` and
  `python3 -m dynamo.<backend> --help` on the installed version.
- **Local file discovery is single-machine only** and disables KV events, routing and the Planner. Use etcd
  (`ETCD_ENDPOINTS`) or Kubernetes discovery for anything else.
- **Never treat the Helm doc example version as current.** Take the version from the releases page.
- **Measure before and after** every tuning change with the version recorded.

## Facts that surprise people (v1.5.1)

- Dynamo wraps engines. Backend flags are the engine's own flags plus Dynamo extras (`--disaggregation-mode`,
  `--headless`). Prefill workers must pass `--kv-transfer-config` or they fail at startup.
- `--router-mode` defaults to `round-robin` on the frontend; `kv` is opt-in. Setting `kv` does not make vLLM
  workers publish KV events; enable `--kv-events-config` and `--enable-prefix-caching` per worker, or use
  `--no-router-kv-events` / `--load-aware`.
- vLLM KV routing needs `PYTHONHASHSEED=0` on every vLLM process.
- Worker metrics appear only when `DYN_SYSTEM_PORT` is set; the frontend serves `/metrics` on `DYN_HTTP_PORT`.
- Kubernetes needs no etcd or NATS: discovery is native and the request plane is TCP.
- On Kubernetes, multinode needs Grove or LeaderWorkerSet or the operator returns a hard error.
- The `nvidia.com/v1beta1` CRDs have no `ingress` field; write an Ingress or Service yourself.
- v1.5.1 moved media fetching to bounded, address-pinned clients: new env vars `DYN_MM_*` (`references/updating.md`).

## Workflows

### Local single node

- [ ] Discovery; confirm driver and Container Toolkit; pick image and tag (`references/install.md`).
- [ ] Start frontend plus worker with file discovery; smoke test `/health`, `/v1/models`, one completion.
- [ ] Optional: `templates/docker-compose.yml`.

### Kubernetes (aggregated -> routed -> disaggregated)

- [ ] GPU Operator, then `dynamo-platform` Helm chart at the chosen release; CRDs and operator pods Running.
- [ ] Create `hf-token-secret`; apply `templates/dgd-agg.yaml`; port-forward and smoke test.
- [ ] Add `DYN_ROUTER_MODE=kv` on the Frontend; then `templates/dgd-disagg-router.yaml` (needs RDMA).
- [ ] Or let `templates/dgdr-rapid.yaml` generate a DGD from model, backend and SLA.

### KV-aware routing on a laptop-sized rig

- [ ] `launch/agg_router.sh` from `examples/backends/<backend>` (2 GPUs), then add a worker and watch routing.

### Upgrade

- [ ] `references/updating.md`: read release notes, bump images, wheel and chart together, smoke test.

### Debug

- [ ] Capture the exact error and frontend plus worker logs, then `references/troubleshooting.md`.

## Reference index

- `references/install.md`: system requirements, containers, wheels, source build, Kubernetes platform, discovery modes.
- `references/serve-config.md`: frontend flags, worker flags, router flags, env vars.
- `references/models-and-formats.md`: which engines and model families, quantization and fit.
- `references/parallelism-multinode.md`: disaggregation, DGD, Grove/LWS, RDMA, multinode.
- `references/features.md`: backend support matrix, KV routing, KVBM, Planner, LoRA, multimodal, tools.
- `references/api.md`: endpoints, Anthropic API, KServe gRPC, request extensions.
- `references/performance-tuning.md`: AIPerf, AIConfigurator, DGDR, KV block size, router knobs.
- `references/integrations.md`: LiteLLM, Open WebUI, Gateway API (GAIE), agents, Kubernetes ecosystem.
- `references/observability.md`: metrics families, ports, tracing, logs.
- `references/updating.md`: upgrade procedure and v1.5.x changes.
- `references/troubleshooting.md`: error to cause to fix.
- `templates/`: `docker-compose.yml`, `dgd-agg.yaml`, `dgd-disagg-router.yaml`, `dgdr-rapid.yaml`.

## Companion skills

- `vllm`, `sglang`, `tensorrt-llm`: the engines Dynamo drives. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `disaggregated-serving`: technique-level guidance and gates. Install: `npx skills add ScaleDockHQ/llms-skills --skill disaggregated-serving`.
- `multi-node-inference`: parallelism across nodes. Install: `npx skills add ScaleDockHQ/llms-skills --skill multi-node-inference`.
- `choosing-inference-engine`: engine selection. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `litellm` and `llm-gateway`: auth, keys, routing in front of the frontend. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `llm-observability`: traces and cost. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
