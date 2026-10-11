---
name: kserve
description: Deploy and operate KServe on Kubernetes for LLMs and ML models (InferenceService, LLMInferenceService, ServingRuntime, LocalModelCache). Use for installing KServe or its llmisvc controller, hf:// model serving with vLLM, llm-d scheduler routing, prefill/decode, multi-node, WVA/KEDA autoscaling, canary rollouts, model caching, upgrades. Fixes InferenceService not Ready, Gateway or HTTPRoute missing, storage-initializer errors. Not for plain Deployments (vllm), llm-d alone (llm-d) or vLLM Helm (vllm-production-stack).
license: MIT
compatibility: A Kubernetes 1.32+ cluster with kubectl and Helm 3.8+, NVIDIA GPU nodes for GPU models (CPU works for demos), curl and jq. Installs, CRD changes, gateways and exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# KServe

Gets KServe installed on a cluster and serving an LLM behind an OpenAI-compatible endpoint, with routing,
scaling and rollouts that match the model size. Verified against KServe v0.21.0 (2026-10-11).

**Scope:** KServe only: install, serve, scale, roll out, update, troubleshoot. Engine flags belong to `vllm`,
the router and well-lit paths to `llm-d`, the Helm-only vLLM router to `vllm-production-stack`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Everything here is read-only and never prints secrets.

```bash
kubectl config current-context; kubectl version -o json | jq -r '.serverVersion.gitVersion'
kubectl get crd | grep -E 'serving.kserve.io|gateway.networking|inference.networking|leaderworkerset|keda.sh'
kubectl get pods -n kserve 2>/dev/null
kubectl get deploy -n kserve -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{"\n"}{end}' 2>/dev/null
kubectl get inferenceservice,llminferenceservice -A 2>/dev/null
kubectl get clusterservingruntime,llminferenceserviceconfig -A 2>/dev/null
kubectl get configmap inferenceservice-config -n kserve -o jsonpath='{.data.deploy}' 2>/dev/null; echo
kubectl get gatewayclass,gateway -A 2>/dev/null
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
helm list -A 2>/dev/null | grep -i kserve
```

## Decision flow

1. **Which resource?** LLMs on GPUs, scheduler routing, prefill/decode, multi-node or WVA autoscaling ->
   `LLMInferenceService` (CRD `serving.kserve.io`, storage version `v1alpha2`, `v1alpha1` still served).
   A simple single-node LLM, or classic ML (sklearn, XGBoost, Triton) -> `InferenceService` (`v1beta1`).
   Nothing needs a platform? Plain manifests are simpler: skill `vllm`.
2. **Which install?** Follow `references/install.md`: LLMs only -> llmisvc install (Gateway API, Envoy Gateway,
   Envoy AI Gateway, LeaderWorkerSet, cert-manager). Mixed -> KServe plus llmisvc. Add LocalModel only for
   cold-start caching of `InferenceService` models.
3. **Deploy** from `templates/llmisvc-gpu.yaml` or `templates/inferenceservice-hf.yaml`; field guide in
   `references/llminferenceservice.md` and `references/inferenceservice-huggingface.md`.
4. **Verify** `READY=True`, then one `/v1/chat/completions` through the gateway or port-forward.
5. **Scale and roll out**: `references/scaling-and-rollout.md` (WVA, KEDA, canary groups, LocalModel).
6. **Connect clients**: `references/integrations.md` (LiteLLM, Envoy AI Gateway, metrics, tracing).
7. **Upgrade or break**: `references/updating.md`, `references/troubleshooting.md`.

## Rules

- **Ask before changing the cluster.** CRDs, controllers, gateways and namespaces are cluster-wide. Show the
  command and the undo (`helm uninstall`, `kubectl delete -k`) first.
- **Pin versions.** Use the release you verified; docs pages may still show an older install script version.
- **Secrets stay out of manifests.** `kubectl create secret generic hf-secret --from-file=HF_TOKEN=<file>`
  (a `0600` file), never `--from-literal` in shell history or a committed Secret.
- **Never rely on `latest`.** Pin runtime images in templates; the sample images upstream use `latest`.
- **Check the status conditions, not just the pods.** `Ready` rolls up `WorkloadsReady` and `RouterReady`.
- **One engine flag source.** KServe passes extra vLLM flags through `args` or `VLLM_ADDITIONAL_ARGS`; look the
  flag up with the `vllm` skill.

## Quick start (LLMInferenceService on a GPU cluster)

```bash
# After the install in references/install.md
kubectl create namespace llm-demo
kubectl apply -n llm-demo -f templates/llmisvc-gpu.yaml
kubectl get llminferenceservice -n llm-demo -w
kubectl get llminferenceservice qwen-single -n llm-demo -o jsonpath='{.status.url}{"\n"}'
```

The request path is `<gateway>/<namespace>/<name>/v1/chat/completions` (verified in the upstream quickstart).
For a quick test, port-forward the Envoy Gateway service labeled `serving.kserve.io/gateway=kserve-ingress-gateway`.

## Workflows

- [ ] Install -> `references/install.md`
- [ ] Deploy an LLM -> `references/llminferenceservice.md` or `references/inferenceservice-huggingface.md`
- [ ] Autoscale, canary, cache models -> `references/scaling-and-rollout.md`
- [ ] Gateway, LiteLLM, metrics -> `references/integrations.md`
- [ ] Upgrade -> `references/updating.md`
- [ ] Diagnose -> `references/troubleshooting.md`
- [ ] Done when: `kubectl get llminferenceservice` shows `READY=True` and a completion returns through the gateway.

## Reference index

- `references/install.md`: install matrix (Helm OCI charts, kustomize, quick-install scripts), dependencies.
- `references/llminferenceservice.md`: spec fields, config composition, scheduler, parallelism, prefill/decode.
- `references/inferenceservice-huggingface.md`: Hugging Face runtime, storage containers, multi-node, KEDA.
- `references/scaling-and-rollout.md`: WVA, canary groups, LocalModelCache, KV cache offloading, LoRA.
- `references/integrations.md`: LiteLLM, Envoy AI Gateway, observability, security.
- `references/updating.md`: chart restructure notes, upgrade order, rollback.
- `references/troubleshooting.md`: symptom to fix table.
- `templates/`: `llmisvc-gpu.yaml`, `inferenceservice-hf.yaml`.

## Companion skills

- `llm-d`: the router and well-lit-path architecture KServe's LLMInferenceService is built on. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-d`.
- `vllm`: engine flags, parsers and tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `vllm-production-stack`: Helm-based alternative with its own router. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm-production-stack`.
- `litellm`: gateway with keys and budgets in front of the endpoint. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `cloud-llms`: where Kubernetes fits among hosting options. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
