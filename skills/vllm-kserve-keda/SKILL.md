---
name: vllm-kserve-keda
description: Deploys and autoscales vLLM on Kubernetes with KServe and KEDA, using InferenceService or LLMInferenceService, the vLLM runtime and Prometheus scaling on queue depth. Use for kserve plus keda plus vllm, autoscalerClass keda, ScaledObject, scale vLLM replicas or ScalingReady false. Not for plain vLLM, llm-d routing or Dynamo.
license: MIT
compatibility: Needs kubectl access to a Kubernetes 1.32+ cluster with NVIDIA GPU nodes, plus helm. Optional jq. Installs, CRDs, GPU workloads and cluster-wide scaling need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# vLLM on KServe with KEDA

Serve a vLLM model through KServe in Standard (raw Deployment) mode and scale its replicas with KEDA from vLLM's own Prometheus metrics. Ends with a Ready service, a generated `ScaledObject` and a load test that proves scale-out and scale-in.

**Scope:** this combination only. Engine flags live in the `vllm` skill, KServe internals in `kserve`, KEDA internals in `keda`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
kubectl version -o json | jq -r '.serverVersion.gitVersion'      # KServe v0.21 needs 1.32+
kubectl get crd | grep -E 'serving.kserve.io|keda.sh|gateway.networking'
kubectl get deploy -A | grep -Ei 'kserve|keda|cert-manager|prometheus'
kubectl get clusterservingruntimes.serving.kserve.io 2>/dev/null
kubectl get cm inferenceservice-config -n kserve -o json 2>/dev/null \
  | jq -r '.data.deploy'                                           # defaultDeploymentMode
kubectl get nodes -o json | jq -r '.items[] | [.metadata.name, (.status.allocatable["nvidia.com/gpu"] // "0")] | @tsv'
helm list -A | grep -Ei 'kserve|keda'
```

## Decision flow

1. **No KServe or KEDA** -> install both, in Standard mode: `references/install.md`.
2. **Pre-existing KServe in Knative (Serverless) mode** -> KEDA needs Standard mode. Set the `serving.kserve.io/deploymentMode: "Standard"` annotation per service, or ask before changing the cluster default.
3. **One model, one replica group, no prefix-aware routing** -> `InferenceService` with the vLLM runtime and a KEDA external trigger: `references/inferenceservice-keda.md`.
4. **Need cache-aware routing or prefill/decode split** -> `LLMInferenceService` (llm-d based), with `spec.scaling.keda`: `references/llminferenceservice-keda.md`. For the router itself use the `llm-d-vllm-kubernetes` skill.
5. **Scaling misbehaves, `ScalingReady` is False, flapping or no scale-to-zero** -> `references/tuning-and-troubleshooting.md`.
6. **Tearing down** -> `references/tuning-and-troubleshooting.md` (teardown section).

## Rules

- **Ask before changing the system.** Installs, CRDs, runtimes, GPU workloads and cluster-wide defaults need approval and an undo path.
- **Secrets never touch output.** HF tokens and Prometheus credentials live in Kubernetes Secrets created from `0600` files or env vars. Never echo them or put them in manifests.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date. The KServe website lags the code, so check the CRD with `kubectl explain` first.
- **Standard mode only for KEDA.** `autoscalerClass: keda` does not work in Knative mode.
- **One autoscaler per component.** Do not add your own HPA or `ScaledObject` for a component KServe already scales. Check with `kubectl get hpa,scaledobject`.
- **Do not hard-code a GPU count.** Size from the model and the GPU in `choosing-hardware`, then verify with the load test.
- **Pin the vLLM image.** The bundled runtimes use floating or older tags (see the install reference). Create a pinned runtime and reference it by name.
- **Metric thresholds are measured, not copied.** Calibrate the trigger value with a load test on this model and GPU.

## Build the stack

- [ ] Prerequisites and versions, then install KEDA and KServe -> `references/install.md`
- [ ] Create the HF token Secret and a pinned vLLM `ClusterServingRuntime` -> `references/install.md`
- [ ] Deploy the model with an `InferenceService` -> `references/inferenceservice-keda.md`
- [ ] Wire Prometheus scraping of vLLM `:8080/metrics` and the KEDA trigger -> `references/inferenceservice-keda.md`
- [ ] Optional: move to `LLMInferenceService` for routing or P/D -> `references/llminferenceservice-keda.md`
- [ ] Load test, watch scale-out and scale-in, then tune -> `references/tuning-and-troubleshooting.md`
- [ ] Verify: `kubectl get isvc` shows READY True, `kubectl get scaledobject` shows READY True and ACTIVE flips under load, replicas return to `minReplicas` after the cooldown, and a `/v1/chat/completions` request through the service URL succeeds.

## Version pins to know (checked 2026-10-11)

| Component  | Version        | Note                                                                                          |
| ---------- | -------------- | --------------------------------------------------------------------------------------------- |
| KServe     | v0.21.0        | `LLMInferenceService` is `v1alpha2`; `InferenceService` is `v1beta1`.                         |
| KEDA       | 2.21.0 latest  | KServe's install scripts pin 2.20.2. Both work; read the 2.21 breaking changes before moving. |
| vLLM       | v0.31.0 latest | KServe's `kserve-huggingfaceserver` image bundles vLLM 0.24.0.                                |
| Kubernetes | 1.32+          | Required by KServe.                                                                           |

Full details and the reasons are in `references/install.md`.

## Reference index

- `references/install.md`: versions, prerequisites, KEDA and KServe install paths, token Secret, pinned vLLM runtime. Load first.
- `references/inferenceservice-keda.md`: `InferenceService` manifest, Prometheus trigger, auth, the generated `ScaledObject`, request test.
- `references/llminferenceservice-keda.md`: `LLMInferenceService` with direct KEDA, prefill scaling, WVA deprecation, what is unverified.
- `references/tuning-and-troubleshooting.md`: metric choice, thresholds, cooldowns, scale-to-zero, failure table, teardown.

## Companion skills

- `kserve`: KServe depth, runtimes, storage, transformers. Install: `npx skills add ScaleDockHQ/llms-skills --skill kserve`.
- `keda`: KEDA scalers and authentication depth. Install: `npx skills add ScaleDockHQ/llms-skills --skill keda`.
- `vllm`: engine flags, quantization, metrics. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `llm-d-vllm-kubernetes`: the llm-d router with vLLM outside KServe. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-d-vllm-kubernetes`.
- `prometheus-grafana-llm`: Prometheus scraping and dashboards for vLLM. Install: `npx skills add ScaleDockHQ/llms-skills --skill prometheus-grafana-llm`.
- `nvidia-gpu-operator`: GPU drivers and device plugin on the cluster. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-gpu-operator`.
- `llm-evals`: check quality after changing the runtime or quantization. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `self-hosted-llms`: pick between hosting options. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
