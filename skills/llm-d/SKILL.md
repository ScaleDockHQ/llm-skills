---
name: llm-d
description: Deploy llm-d on Kubernetes, the CNCF distributed LLM inference stack (llm-d Router, EPP, InferencePool) in front of vLLM or SGLang with prefix-cache and load-aware routing. Use for the optimized-baseline quickstart, precise prefix-cache routing, prefill/decode, wide expert parallelism, tiered KV offload, flow control, KEDA autoscaling, rollouts, release upgrades. Fixes uneven load, low cache hit rate, gateway or CRD errors. Not for KServe (kserve), vLLM Helm router (vllm-production-stack), Dynamo or single-node vLLM (vllm).
license: MIT
compatibility: A Kubernetes cluster with kubectl, helm and git, a Gateway API Inference Extension capable proxy (standalone Envoy mode needs none), NVIDIA, AMD, Intel or TPU nodes, curl and jq. Cluster-wide installs, CRDs and gateways need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# llm-d

Gets the llm-d serving stack running on a cluster: an intelligent router (EPP) in front of a pool of model-server
pods, with the right well-lit path for the workload. Verified against llm-d v0.10.0 (2026-10-11).

**Scope:** llm-d only: install, route, disaggregate, offload KV, autoscale, roll out, update, troubleshoot. Engine
flags belong to `vllm`, the KServe wrapper to `kserve`, the Helm router from the vLLM project to `vllm-production-stack`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; never prints secrets.

```bash
kubectl config current-context; kubectl version -o json | jq -r '.serverVersion.gitVersion'
kubectl get crd | grep -E 'inference.networking|gateway.networking|leaderworkerset|keda.sh|monitoring.coreos.com'
kubectl get inferencepool,httproute,gateway -A 2>/dev/null
helm list -A 2>/dev/null | grep -Ei 'llm-d|router'
kubectl get deploy,pods -A -l llm-d.ai/guide 2>/dev/null
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,AMD:.status.allocatable.amd\.com/gpu'
command -v helm kubectl git kustomize
```

## Decision flow

1. **Start here for almost everything:** the optimized baseline (prefix-cache-aware plus load-aware routing over
   a vLLM pool). `references/install.md`.
2. **Gateway or standalone?** Standalone mode runs the router with an Envoy sidecar and needs no Gateway
   (easiest). Gateway mode needs a Gateway API Inference Extension implementation: GKE Gateway, Istio, agentgateway
   or Envoy AI Gateway.
3. **Pick a path by workload** (`references/well-lit-paths.md`):
   multi-turn or agentic with shared prefixes -> baseline, then precise prefix-cache routing;
   long prompts on medium to large models -> prefill/decode disaggregation (RDMA helps);
   very large MoE (DeepSeek-R1, gpt-oss) -> wide expert parallelism; long context churn -> tiered KV offload;
   many tenants or priorities -> flow control; several base models behind one URL -> multi-model routing.
4. **Autoscale and roll out:** `references/scaling-and-rollouts.md` (KEDA on EPP metrics, blue-green, LoRA rollout).
5. **Observe:** `references/operations.md` (PodMonitors, PromQL signals, probes, drain).
6. **Update or break:** `references/updating.md`, `references/troubleshooting.md`.

## Rules

- **Ask before cluster changes.** Gateway API and inference-extension CRDs, gateways and namespaces are shared
  state. Show the command and the undo first.
- **Guides are the source of truth.** Check out the release branch (`release-0.10` for v0.10.0) and apply its
  kustomize overlays; do not mix a newer chart with older overlays.
- **Pin versions.** `guides/env.sh` sets defaults (`ROUTER_CHART_VERSION`, `GAIE_VERSION`, `GATEWAY_API_VERSION`;
  `v0.11.0`, `v1.5.0` and `v1.5.1` in the v0.10.0 tag). Print them after sourcing and export your own pins.
- **Secrets from files.** Create `llm-d-hf-token` from a `0600` file: `--from-file=HF_TOKEN=<file>`. Upstream guides
  show `--from-literal`; do not paste tokens into a shell.
- **Calibrate off the reference hardware.** `peakPrefillThroughput` defaults to the value measured for Qwen3-32B on
  H100 TP=2; measure your own for other models or accelerators.
- **Do not use `llm-d-cuda` for new installs.** v0.10.0 deprecated it for `docker.io/vllm/vllm-openai`.

## Quick start (standalone, optimized baseline, NVIDIA GPUs)

```bash
git clone --depth 1 --branch release-0.10 https://github.com/llm-d/llm-d.git && cd llm-d
export REPO_ROOT=$(realpath .) GUIDE_NAME=quickstart NAMESPACE=llm-d-quickstart
source "$REPO_ROOT/guides/env.sh"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/${GAIE_URL}/v1-manifests.yaml
kubectl create namespace $NAMESPACE
kubectl create secret generic llm-d-hf-token -n $NAMESPACE --from-file=HF_TOKEN=/path/to/token-file
helm install $GUIDE_NAME $ROUTER_STANDALONE_CHART \
  -f guides/recipes/router/base.values.yaml -f guides/optimized-baseline/router/optimized-baseline.values.yaml \
  -n $NAMESPACE --version $ROUTER_CHART_VERSION
kubectl apply -n $NAMESPACE -k guides/optimized-baseline/modelserver/gpu/vllm/base/
```

The default deploys 8 replicas of Qwen/Qwen3-32B at TP=2, so 16 GPUs; reduce `replicas` and tensor parallel size
for a smaller cluster. Test from inside the cluster against `svc/${GUIDE_NAME}-epp`. Details in `references/install.md`.

## Workflows

- [ ] Install -> `references/install.md`
- [ ] Choose and deploy a path -> `references/well-lit-paths.md`
- [ ] Scale and roll out -> `references/scaling-and-rollouts.md`
- [ ] Monitor and operate -> `references/operations.md`
- [ ] Upgrade -> `references/updating.md`
- [ ] Diagnose -> `references/troubleshooting.md`
- [ ] Done when: pods Ready, a completion returns through the router, and EPP metrics show requests spread across pods.

## Reference index

- `references/install.md`: prerequisites, versions, standalone and gateway mode, accelerators, cleanup.
- `references/well-lit-paths.md`: every path, what it needs, and the directory to apply.
- `references/scaling-and-rollouts.md`: KEDA autoscaling signals, WVA status, blue-green, adapter rollout.
- `references/operations.md`: monitoring, metrics, probes, graceful shutdown, router HA, startup.
- `references/updating.md`: release themes, deprecations and migrations.
- `references/troubleshooting.md`: symptom to fix table.
- `templates/`: router values override and a model-server probe patch.

## Companion skills

- `vllm`: the engine under the pool; flags, parsers, tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `kserve`: `LLMInferenceService` wraps llm-d's router for KServe users. Install: `npx skills add ScaleDockHQ/llms-skills --skill kserve`.
- `vllm-production-stack`: the Helm-based alternative. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm-production-stack`.
- `gateway-api-inference-extension`: the InferencePool and EPP standard llm-d builds on. Install: `npx skills add ScaleDockHQ/llms-skills --skill gateway-api-inference-extension`.
- `keda`: event-driven autoscaling for the EPP path. Install: `npx skills add ScaleDockHQ/llms-skills --skill keda`.
- `disaggregated-serving`, `prefix-aware-routing`, `kv-cache-offloading`: technique skills behind the paths. Install: `npx skills add ScaleDockHQ/llms-skills --skill disaggregated-serving`.
