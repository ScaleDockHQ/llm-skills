---
name: vllm-production-stack
description: Deploy the vLLM production-stack Helm chart (vllm-stack) on Kubernetes, the vLLM project's router plus serving engines with LMCache KV offload and Grafana. Use for helm install vllm/vllm-stack, values.yaml (servingEngineSpec, routerSpec), routing logic (roundrobin, session, prefixaware, kvaware, disaggregated prefill), multi-model, LoRA, KEDA, upgrades. Fixes router 502 or no models, pods Pending, wrong routing. Not for KServe (kserve), llm-d (llm-d) or single-node vLLM (vllm).
license: MIT
compatibility: A Kubernetes cluster with NVIDIA GPU nodes (the NVIDIA runtime class), kubectl, Helm 3 and git, curl and jq. Cluster installs, Secrets, KEDA and exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# vLLM production-stack

Gets the vLLM project's reference Kubernetes stack running: serving-engine Deployments per model, a router that
spreads OpenAI-compatible requests, and optional LMCache offload, Prometheus, Grafana and KEDA. Verified against
production-stack chart `vllm-stack` 0.1.13 (2026-10-11).

**Scope:** this Helm chart (and its operator CRDs): install, configure, route, scale, upgrade, troubleshoot. Engine
flags belong to `vllm`; the heavier scheduler-based alternative is `llm-d`; the CRD platform is `kserve`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; never prints secrets.

```bash
kubectl config current-context
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
kubectl get runtimeclass 2>/dev/null
helm list -A 2>/dev/null | grep -i vllm-stack
kubectl get deploy,svc,pvc,servicemonitor,scaledobject 2>/dev/null | grep -i vllm
helm search repo vllm/vllm-stack --versions 2>/dev/null | head -5
curl -s -m 5 http://localhost:30080/v1/models | jq '.data[].id'     # after a port-forward to the router
```

## Decision flow

1. **New install** -> `references/install.md`: `helm repo add`, a values file, a pinned `--version`.
2. **Write the values** in `references/values.md`: one `modelSpec` entry per model; engine args under `vllmConfig`.
   Start from `templates/values-minimal.yaml`.
3. **Pick routing** in `references/routing.md`: `roundrobin` (default), `session` (sticky by header),
   `prefixaware`, `kvaware` (needs LMCache controller), `priority`, or disaggregated prefill.
4. **Add features** from `references/features.md`: LMCache CPU offload, several models, LoRA, tool calling,
   API key, sleep mode, pipeline parallel with Ray.
5. **Scale and observe**: `references/scaling-and-observability.md` (KEDA on queue depth, ServiceMonitor, dashboards).
6. **Upgrade or break**: `references/updating.md`, `references/troubleshooting.md`.
7. **Outgrown it?** Cache- and load-aware scheduling with a gateway standard -> `llm-d`; platform CRDs -> `kserve`.

## Rules

- **Ask before changing the cluster.** Installs create Deployments, PVCs and optionally a Prometheus stack. Show
  `helm template` output or `--dry-run` and the `helm uninstall` undo first.
- **Pin images and chart.** Chart defaults use `tag: "latest"` for engine and router images. Set explicit tags and
  `--version`.
- **Secrets by reference.** Use `hf_token: {secretName, secretKey}` and `vllmApiKey: {secretName, secretKey}`
  pointing at Secrets created from `0600` files. Several upstream examples put tokens in values files; do not
  commit those.
- **Match routing to the engine.** `kvaware` and LMCache features need an LMCache-enabled engine image; plain
  `vllm/vllm-openai` does not have them.
- **Request GPUs explicitly.** `requestGPU` must match `tensorParallelSize` per replica.
- **Keep the router internal** unless you add TLS and auth; set the engine API key.

## Quick start

```bash
helm repo add vllm https://vllm-project.github.io/production-stack && helm repo update
kubectl create secret generic hf-token --from-file=token=/path/to/token-file   # gated models only
helm install vllm vllm/vllm-stack --version 0.1.13 -f templates/values-minimal.yaml
kubectl get pods -w
kubectl port-forward svc/vllm-router-service 30080:80 &
curl -s localhost:30080/v1/models | jq
curl -s localhost:30080/v1/completions -H 'Content-Type: application/json' \
  -d '{"model":"facebook/opt-125m","prompt":"Hello","max_tokens":16}' | jq '.choices[0].text'
```

Uninstall with `helm uninstall vllm` (PVCs stay until deleted).

## Workflows

- [ ] Install -> `references/install.md`
- [ ] Configure -> `references/values.md`, `references/routing.md`
- [ ] Features -> `references/features.md`
- [ ] Scale and monitor -> `references/scaling-and-observability.md`
- [ ] Upgrade -> `references/updating.md`
- [ ] Diagnose -> `references/troubleshooting.md`
- [ ] Done when: engine pods Ready, `/v1/models` lists each model through the router, and one completion works.

## Reference index

- `references/install.md`: Helm repo, versions, prerequisites, operator alternative, cloud notes.
- `references/values.md`: `servingEngineSpec`, `modelSpec`, `vllmConfig`, `routerSpec`, storage and secrets.
- `references/routing.md`: routing logics, session keys, LMCache controller, priority, disaggregated prefill.
- `references/features.md`: LMCache offload, multi-model, LoRA, tools, API key, sleep mode, Ray, Gateway API.
- `references/scaling-and-observability.md`: KEDA, ServiceMonitor, Grafana, tracing.
- `references/updating.md`: chart upgrade, image bumps, rollback.
- `references/troubleshooting.md`: symptom to fix.
- `templates/`: minimal, prefix-aware with KEDA values.

## Companion skills

- `vllm`: engine flags, parsers and tuning for `vllmConfig.extraArgs`. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `llm-d`: scheduler-based alternative with precise prefix routing. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-d`.
- `kserve`: CRD-based platform. Install: `npx skills add ScaleDockHQ/llms-skills --skill kserve`.
- `keda`: event-driven autoscaling used by the chart. Install: `npx skills add ScaleDockHQ/llms-skills --skill keda`.
- `prefix-aware-routing`: why and when. Install: `npx skills add ScaleDockHQ/llms-skills --skill prefix-aware-routing`.
- `kv-cache-offloading`: LMCache and offload concepts. Install: `npx skills add ScaleDockHQ/llms-skills --skill kv-cache-offloading`.
