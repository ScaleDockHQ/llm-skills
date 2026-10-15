---
name: gateway-api-inference-extension
description: Route LLM traffic to vLLM or SGLang pods on Kubernetes with the Gateway API Inference Extension (InferencePool, Endpoint Picker, inference gateway, HTTPRoute backendRef) and the llm-d router charts. Use for model-aware, KV-cache and queue-aware load balancing, prefix routing, LoRA affinity, priority and flow control, Istio, agentgateway or NGINX Gateway Fabric as the proxy. Fixes missing CRDs, EPP not serving, 503 or FailClose. Not for llm-d full stacks (llm-d-vllm-kubernetes), KServe, or LiteLLM.
license: MIT
compatibility: Kubernetes cluster with a Gateway API implementation that supports the inference extension (or Envoy standalone), kubectl, helm, curl and jq. CRD installs, Helm releases and gateway exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Gateway API Inference Extension

Puts an inference-aware load balancer in front of a pool of model-server pods: the gateway asks an Endpoint
Picker (EPP) which pod should take each request, using queue depth, KV-cache use, prefix-cache hits and LoRA
state. Verified against Gateway API Inference Extension v1.6.2 and llm-d router v0.11.0 (2026-10-11).

**Scope:** the `InferencePool` API, wiring a Gateway or standalone Envoy to it, and running the EPP. Important
upstream change: the production EPP and the `InferenceObjective` / `InferenceModelRewrite` APIs now live in
`llm-d/llm-d-router`. The `kubernetes-sigs` repo keeps the `InferencePool` API (v1, GA), a lightweight EPP (LWEPP)
for conformance only, and the conformance tests. Full llm-d serving stacks, KServe and gateways like LiteLLM are
sibling skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
kubectl version
kubectl get crd | grep -E 'inference.networking|gateway.networking'
kubectl get gatewayclass; kubectl get gateway,httproute -A
kubectl get inferencepool -A -o wide 2>/dev/null
kubectl get pods -A -l 'app.kubernetes.io/name' --no-headers 2>/dev/null | grep -i -E 'epp|endpoint-picker|istio|envoy|agentgateway|nginx-gateway' | head
helm list -A | grep -i -E 'router|inference|gateway'
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
# Are model servers exposing the metrics the EPP needs?
kubectl get pods -l app=<model-server-label> -o wide
kubectl exec <pod> -- curl -s localhost:8000/metrics | grep -E '^vllm:(num_requests_waiting|num_requests_running|kv_cache_usage_perc)'
```

## Decision flow

1. **One model server pod, or round robin is fine?** Skip this; use a Service. The EPP pays off with several
   replicas, shared prefixes, LoRA adapters or mixed priorities.
2. **No CRDs yet** -> `references/install.md`: Gateway API CRDs, then the Inference Extension CRDs, then a
   gateway implementation.
3. **Pick the mode** (`references/install.md`): _Gateway mode_ (production: `Gateway` + `HTTPRoute` ->
   `InferencePool` -> EPP) or _Standalone mode_ (the chart runs Envoy or agentgateway next to the EPP, no Gateway
   API infrastructure).
4. **Model servers ready?** Same labels, one base model per pool, metrics endpoint, prefix caching on:
   `references/inferencepool-and-routes.md`.
5. **Deploy the router**: Helm chart `llm-d-router-gateway` (or `-standalone`) with the pool selector, pinned
   image tag: `templates/values-gateway.yaml`. Then `HTTPRoute`: `templates/httproute.yaml`.
6. **Tune routing**: plugin config, priorities, flow control, HA, sizing: `references/epp-and-routing.md`.
7. **Observe**: `references/observability.md`. **Upgrade or migrate** (charts renamed, EPP moved):
   `references/updating.md`. **Broken**: `references/troubleshooting.md`.

## Quick start (gateway mode)

```bash
# After approval. Pin versions from the references; these are the verified ones.
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.6.2/v1-manifests.yaml
# (Gateway API CRDs and a Gateway implementation must already exist: references/install.md)

helm install vllm-qwen3-32b oci://ghcr.io/llm-d/charts/llm-d-router-gateway --version v0 \
  --set router.modelServers.matchLabels.app=vllm-qwen3-32b \
  --set router.epp.image.tag=v0.11.0
kubectl apply -f templates/httproute.yaml        # parentRef: your Gateway; backendRef: the InferencePool
kubectl get inferencepool vllm-qwen3-32b -o jsonpath='{.status.parents}' | jq
```

Check the image tag exists before using it; the chart default is `main` with `pullPolicy: Always`, which is
not reproducible. Send a request through the Gateway address with the model name the pods serve.

## Rules

- **Ask before changing the system.** CRDs are cluster-wide; Helm releases, Gateways and routes change live
  traffic. Say what you will apply and how to undo it (`helm uninstall`, `kubectl delete -f`).
- **Secrets never touch output.** Gateway TLS keys, `HF_TOKEN` and API keys live in Secrets created from `0600`
  files; do not echo them.
- **Pin versions.** CRD manifest tag, chart `--version`, and `router.epp.image.tag`. Never `main` or `latest`
  in production.
- **One EPP per pool, one base model per pool.** An EPP serves a single InferencePool; every pod in the pool
  shares compute class, accelerator type, base model and model server.
- **Pool selector must match pod labels exactly,** in the same namespace as the pool.
- **Mind failure mode.** The API default is `FailClose` (drop requests when the EPP is down); the llm-d chart
  sets `FailOpen` (the gateway picks any pod). Choose deliberately.
- **Envoy ext_proc body mode** must be `FULL_DUPLEX_STREAMED` if you configure Envoy yourself.
- **EPP is CPU hungry.** Chart defaults request 8 CPU and 8Gi; see sizing in `references/epp-and-routing.md`.
- **No auth here.** The router does not authenticate clients; put auth in the Gateway or in front (LiteLLM).

## Facts that surprise people (v1.6.2 / router v0.11.0)

- `endpointPickerRef` was required until v1.5.0 and is optional now, but most implementations still need it.
- InferencePool `targetPorts` allows 1 to 8 ports; each `podIP:port` is a separate endpoint to the EPP.
- The old `InferenceModel` is gone from this repo's docs; per-request priority is `InferenceObjective` and model
  renames/canaries are `InferenceModelRewrite`, both owned by llm-d-router (group differs from `inference.networking.k8s.io`).
- Helm values were restructured: legacy `inferenceExtension.*` and `inferencePool.*` keys now fail the install
  with a validation error; use `router.*` (`references/updating.md`).
- With `router.epp.replicas > 1` the default is active-passive leader election: only the leader is Ready, so
  `helm --wait` fails unless you adjust the strategy or skip waiting.
- Model servers are scraped on `/metrics`; the required signals are queue length, running requests and KV-cache
  use (vLLM: `vllm:num_requests_waiting`, `vllm:num_requests_running`, `vllm:kv_cache_usage_perc`).
- The conformant gateway listing (Istio, agentgateway, NGINX Gateway Fabric) ages out without fresh reports;
  check the implementation's own docs for inference support.

## Workflows

### Add smart routing to existing vLLM replicas

- [ ] Discovery; confirm replicas share a label and expose `/metrics` and `/v1`.
- [ ] Install CRDs and a gateway (`references/install.md`) with approval.
- [ ] Install the router chart for the pool; check the EPP Pod is Ready (the leader is).
- [ ] Apply the `HTTPRoute`; verify `InferencePool` status shows the parent Gateway `Accepted` and `ResolvedRefs`.
- [ ] Send requests with a shared prefix; compare TTFT and `vllm:prefix_cache_hits` before and after.

### Prioritize traffic or canary a model

- [ ] `InferenceObjective` for priority; `InferenceModelRewrite` for splits (`references/epp-and-routing.md`).
- [ ] Verify with the EPP request metrics labeled by model and priority.

### Debug a failure

- [ ] `kubectl describe inferencepool`, EPP logs, Gateway and HTTPRoute conditions; match
      `references/troubleshooting.md`.

## Reference index

- `references/install.md`: CRDs, Gateway API, gateway implementations, router charts, standalone mode.
- `references/inferencepool-and-routes.md`: InferencePool fields, HTTPRoute, model-server requirements, multi-pool.
- `references/epp-and-routing.md`: llm-d router config, plugins, flow control, HA, disaggregation, sizing.
- `references/observability.md`: EPP and model-server metrics, logs, status conditions.
- `references/updating.md`: upgrades, chart and API migration.
- `references/troubleshooting.md`: symptom to cause to fix.
- `references/combos/vllm-pods.md`: vLLM Deployment settings that make the EPP effective.
- `references/combos/litellm-in-front.md`: LiteLLM or another AI gateway ahead of the inference gateway.
- `templates/`: `inferencepool.yaml`, `httproute.yaml`, `values-gateway.yaml`, `vllm-deployment.yaml`.

## Companion skills

- `llm-d-vllm-kubernetes`: the full llm-d stack (router, P/D, wide EP) on vLLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-d-vllm-kubernetes`.
- `vllm`: the model server flags and metrics. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `prefix-aware-routing`: technique-level routing guidance across stacks. Install: `npx skills add ScaleDockHQ/llm-skills --skill prefix-aware-routing`.
- `nvidia-gpu-operator`: GPU nodes for the pool. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-gpu-operator`.
- `keda`: scale the model-server Deployment on queue and GPU metrics. Install: `npx skills add ScaleDockHQ/llm-skills --skill keda`.
- `ray-serve`: Ray-native routing instead of pod routing. Install: `npx skills add ScaleDockHQ/llm-skills --skill ray-serve`.
- `kserve`: CRD-driven serving with its own inference-gateway integration. Install: `npx skills add ScaleDockHQ/llm-skills --skill kserve`.
- `litellm`: keys, budgets, fallbacks in front. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
