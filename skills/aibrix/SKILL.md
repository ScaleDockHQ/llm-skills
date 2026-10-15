---
name: aibrix
description: Install and operate AIBrix v0.7.0 on Kubernetes, the vLLM project's control plane for LLM serving, with an Envoy gateway and LLM-aware routing, PodAutoscaler, LoRA ModelAdapter, StormService prefill/decode and multi-node, and KVCache offload. Use for model.aibrix.ai labels, routing-strategy header, aibrix-system pods, APA/KPA autoscaling, Redis state sync, upgrades and fixes for 404, no ready pods or HTTPRoute not accepted. Not for the vllm-stack Helm chart (vllm-production-stack) or llm-d (llm-d).
license: MIT
compatibility: A Kubernetes cluster with NVIDIA GPU nodes, kubectl, curl and jq, and permission to install CRDs and Envoy Gateway. Helm is optional. Cluster-wide installs and gateway exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# AIBrix

AIBrix is a Kubernetes-native control plane for vLLM (and SGLang) serving: an Envoy Gateway-based gateway that
routes by model and by LLM-aware strategy, a controller manager (autoscaling, LoRA, orchestration, KV cache), and an
AI runtime sidecar. Verified against AIBrix v0.7.0 (released 2026-06-18, repo active 2026-10-11).

**Scope:** install, deploy a model, route, scale, LoRA, P/D disaggregation, KV offload, upgrade, troubleshoot. Engine
flags belong to `vllm`.

## Discover first

Read-only.

```bash
kubectl config current-context
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
kubectl get pods -n aibrix-system; kubectl get pods -n envoy-gateway-system
kubectl get crd | grep aibrix.ai
kubectl get httproute -A
kubectl get podautoscaler,modeladapter,stormservice -A 2>/dev/null
kubectl get svc -n envoy-gateway-system
```

## Decision flow

1. **Install** -> `references/install.md` (release manifests or Helm; Envoy Gateway is required).
2. **Deploy a model** -> `references/model-deployment.md`: a Deployment plus Service with `model.aibrix.ai/name` and
   `model.aibrix.ai/port`, and `--served-model-name` equal to the label. Start from `templates/model.yaml`.
3. **Route** -> `references/gateway-and-routing.md`: `routing-strategy` header or `ROUTING_ALGORITHM`, rate limits,
   auth, Redis for several gateway replicas.
4. **Scale** -> `references/autoscaling.md`: `PodAutoscaler` with HPA, KPA or APA.
5. **Advanced** -> `references/features.md`: LoRA `ModelAdapter`, `StormService` P/D and multi-node, KV cache offload,
   Ray fleets, runtime sidecar.
6. **Upgrade or fix** -> `references/updating.md`, `references/troubleshooting.md`.

## Rules

- **Ask before cluster-wide changes.** The dependency manifest installs Envoy Gateway and other cluster-wide dependencies;
  CRDs are separate so uninstalling the operator keeps your custom resources. Show the manifest URLs first.
- **Names must match.** Service name, `model.aibrix.ai/name` label, `--served-model-name` and the request `model`
  field are one string. A mismatch causes 404s and "no ready pods".
- **Pin the release.** Use `v0.7.0` URLs, not `nightly` or `main`.
- **`PodAutoscaler.scaleTargetRef.name` equals the Deployment name.**
- **Protect the endpoint.** The gateway is public if you expose it: set the engine `--api-key` (read from a Secret
  env var, not inline) and, for several gateway replicas, enable Redis and state sync.
- **Check image provenance.** KV cache and P/D samples use AIBrix-built engine images (some from a Volcano Engine
  registry); prefer images from `docker.io/aibrix` and confirm tags before applying.
- **Never print secrets.** Read keys from `0600` files or Secrets.

## Quick start

```bash
V=v0.7.0
kubectl apply -f https://github.com/vllm-project/aibrix/releases/download/$V/aibrix-dependency-$V.yaml --server-side
kubectl apply -f https://github.com/vllm-project/aibrix/releases/download/$V/aibrix-core-crds-$V.yaml --server-side
kubectl apply -f https://github.com/vllm-project/aibrix/releases/download/$V/aibrix-core-$V.yaml
kubectl get pods -n aibrix-system -w
kubectl apply -f templates/model.yaml
kubectl -n envoy-gateway-system port-forward svc/$(kubectl get svc -n envoy-gateway-system -o name | grep envoy-aibrix | cut -d/ -f2) 8888:80 &
curl -s localhost:8888/v1/models | jq '.data[].id'
curl -s localhost:8888/v1/chat/completions -H 'Content-Type: application/json' -H 'routing-strategy: least-request' \
  -d '{"model":"deepseek-r1-distill-llama-8b","messages":[{"role":"user","content":"Say hi"}]}' | jq -r '.choices[0].message.content'
```

## Workflows

- [ ] Install -> `references/install.md`
- [ ] Deploy and route -> `references/model-deployment.md`, `references/gateway-and-routing.md`
- [ ] Autoscale -> `references/autoscaling.md`
- [ ] LoRA, P/D, KV offload -> `references/features.md`
- [ ] Upgrade and diagnose -> `references/updating.md`, `references/troubleshooting.md`
- [ ] Done when: control-plane pods Ready, the model's HTTPRoute is Accepted, and a completion works through the gateway.

## Reference index

- `references/install.md`: manifests, Helm, components, controllers flag, uninstall.
- `references/model-deployment.md`: labels, Service, runtime sidecar, custom paths.
- `references/gateway-and-routing.md`: strategies, headers, rate limiting, auth, Redis.
- `references/autoscaling.md`: PodAutoscaler strategies, metrics, annotations.
- `references/features.md`: LoRA, StormService, KVCache, Ray fleets.
- `references/updating.md`, `references/troubleshooting.md`.
- `templates/`: model and autoscaler manifests (`model.yaml`, `podautoscaler-apa.yaml`).

## Companion skills

- `vllm`: engine flags. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `vllm-production-stack`: the Helm-based alternative. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm-production-stack`.
- `llm-d`: scheduler-based alternative. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-d`.
- `kv-cache-offloading`: offload concepts. Install: `npx skills add ScaleDockHQ/llm-skills --skill kv-cache-offloading`.
- `disaggregated-serving`: when P/D pays off. Install: `npx skills add ScaleDockHQ/llm-skills --skill disaggregated-serving`.
