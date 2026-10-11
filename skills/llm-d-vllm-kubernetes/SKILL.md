---
name: llm-d-vllm-kubernetes
description: Deploys vLLM behind the llm-d router on Kubernetes with Gateway API Inference Extension, with cache-aware routing, optional prefill/decode split and KEDA autoscaling on router metrics. Use for llm-d, llm-d-router, EPP, InferencePool, optimized-baseline guide or helm llm-d-router-standalone. Not for plain vLLM, KServe or Dynamo.
license: MIT
compatibility: Needs kubectl, helm and git, and a Kubernetes cluster with NVIDIA GPU nodes (v1.33+ recommended for sidecar init containers). Optional jq. Installs, CRDs and GPU workloads need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# llm-d with vLLM on Kubernetes

Run vLLM model servers behind the llm-d router (an endpoint picker, EPP, plugged into Gateway API Inference Extension), so requests go to the replica that has the prefix cached and the least load. Ends with a verified endpoint, optional prefill/decode pools and KEDA scaling.

**Scope:** the llm-d guides' path with vLLM on NVIDIA GPUs. Engine flags live in `vllm`, routing theory in `prefix-aware-routing`, the split itself in `disaggregated-serving`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
kubectl version -o json | jq -r '.serverVersion.gitVersion'
kubectl get nodes -o json | jq -r '.items[] | [.metadata.name, (.status.allocatable["nvidia.com/gpu"] // "0")] | @tsv'
kubectl get crd | grep -E 'inference.networking|gateway.networking|monitoring.coreos|keda.sh'
kubectl get gatewayclass 2>/dev/null
helm list -A | grep -Ei 'llm-d|router|keda|prometheus'
kubectl get inferencepool,inferenceobjective -A 2>/dev/null
command -v helm git kubectl
```

## Decision flow

1. **No Gateway API Inference Extension CRDs** -> install them first: `references/install-baseline.md`.
2. **Starting fresh** -> deploy the optimized baseline (router plus single-host vLLM): `references/install-baseline.md`.
3. **Cluster has no Gateway controller** -> use router standalone mode (Envoy sidecar). Use gateway mode only when a Gateway (Istio, agentgateway, GKE, Envoy AI Gateway) already exists.
4. **Long prompts with TTFT or decode interference problems** -> consider prefill/decode split after the baseline is measured: `references/pd-disaggregation.md`.
5. **Load varies** -> KEDA with router (EPP) metrics: `references/autoscaling.md`.
6. **Uneven load, 503s, router errors, pods Pending** -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** CRDs, Helm releases, GPU workloads and gateways need approval and an undo path.
- **Secrets never touch output.** The HF token Secret is built from a `0600` file or env var, never printed or written to a manifest.
- **Pin everything.** Clone the llm-d repo at the tag `v0.10.0`, pin the chart version, and replace floating image tags (the P/D overlays use the router sidecar `main` tag) with release tags.
- **Do not trust defaults for your hardware.** The guide's replicas, GPUs per replica, model and `peakPrefillThroughput` are for the reference setup (Qwen3-32B on H100, TP=2). Adjust and calibrate.
- **Baseline before split.** Measure the optimized baseline, then split only if the numbers justify it. Keep the aggregated deployment until the split passes a `llm-evals` check.
- **One autoscaler per Deployment.** Never add an HPA next to a KEDA `ScaledObject`.
- **WVA is deprecated.** Do not start new deployments on it.

## Build the stack

- [ ] Clone llm-d at `v0.10.0`, install GAIE CRDs, create namespace and HF Secret -> `references/install-baseline.md`
- [ ] Install the router (standalone or gateway) with `helm` -> `references/install-baseline.md`
- [ ] Apply the vLLM model-server kustomize overlay, adjusted to the GPUs available -> `references/install-baseline.md`
- [ ] Verify with an in-cluster request and the router metrics -> `references/install-baseline.md`
- [ ] Optional: monitoring, then flow control and calibration -> `references/install-baseline.md`
- [ ] Optional: prefill/decode pools with NIXL -> `references/pd-disaggregation.md`
- [ ] Optional: KEDA scaling on EPP metrics -> `references/autoscaling.md`
- [ ] Verify: router pods Ready, the `InferencePool` has endpoints, a `/v1/completions` request returns, cache hit ratio and per-pod load are sane under a repeated-prefix load.

## Version pins to know (checked 2026-10-11)

| Component                            | Version                                                       |
| ------------------------------------ | ------------------------------------------------------------- |
| llm-d release                        | v0.10.0 (2026-09-29)                                          |
| llm-d router chart and EPP image     | v0.11.0                                                       |
| Gateway API CRDs                     | v1.5.1                                                        |
| Gateway API Inference Extension CRDs | v1.5.0                                                        |
| Default vLLM image in the guides     | `docker.io/vllm/vllm-openai:v0.30.0` (latest vLLM is v0.31.0) |
| WVA                                  | deprecated, v0.9.0 final                                      |

## Reference index

- `references/install-baseline.md`: prerequisites, CRDs, router chart, model server overlay, verification, cleanup.
- `references/pd-disaggregation.md`: the P/D guide, NIXL settings, router config, scale-down behaviour.
- `references/autoscaling.md`: KEDA plus EPP signals, overlays, what to calibrate, WVA status.
- `references/troubleshooting.md`: failure table, read-only diagnostics, verification gaps.

## Companion skills

- `vllm`: engine flags and metrics. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `gateway-api-inference-extension`: InferencePool, EPP and CRD depth. Install: `npx skills add ScaleDockHQ/llms-skills --skill gateway-api-inference-extension`.
- `prefix-aware-routing`: how cache-aware routing works. Install: `npx skills add ScaleDockHQ/llms-skills --skill prefix-aware-routing`.
- `disaggregated-serving`: when the split helps. Install: `npx skills add ScaleDockHQ/llms-skills --skill disaggregated-serving`.
- `keda`: scalers and auth. Install: `npx skills add ScaleDockHQ/llms-skills --skill keda`. If it is not yet published, install later: keda skill.
- `kserve`: llm-d inside KServe as `LLMInferenceService`. Install: `npx skills add ScaleDockHQ/llms-skills --skill kserve`.
- `nvidia-gpu-operator`: GPU drivers and device plugin. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-gpu-operator`.
- `nccl-rdma-networking`: RDMA for NIXL KV transfer. Install: `npx skills add ScaleDockHQ/llms-skills --skill nccl-rdma-networking`.
- `prometheus-grafana-llm`: dashboards for router and vLLM metrics. Install: `npx skills add ScaleDockHQ/llms-skills --skill prometheus-grafana-llm`.
- `llm-evals`: check quality after changing the setup. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- llm-d itself has no skill here yet; install later: llm-d skill.
