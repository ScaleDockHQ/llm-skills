---
name: dynamo-trtllm-disaggregated
description: Deploys TensorRT-LLM with NVIDIA Dynamo on Kubernetes as separate prefill and decode workers using DynamoGraphDeployment, NIXL KV transfer and the KV-aware router. Use for Dynamo plus TRT-LLM disagg, dynamo.trtllm, DynamoGraphDeployment, cache_transceiver_config or Grove. Not for plain TensorRT-LLM, vLLM or llm-d.
license: MIT
compatibility: Needs kubectl and helm 3 on a Kubernetes 1.30+ cluster with NVIDIA GPU nodes (driver 580+ for current CUDA 13 images), ideally RDMA. Installs, CRDs, operators and GPU workloads need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Dynamo with TensorRT-LLM, disaggregated

Run TensorRT-LLM prefill and decode as separate Dynamo workers on Kubernetes, behind the Dynamo frontend, with KV cache moving by NIXL over RDMA where available. Ends with a Ready `DynamoGraphDeployment`, a verified request path and a measured comparison with aggregated serving.

**Scope:** this combination only. Engine tuning lives in `tensorrt-llm`, platform depth in `nvidia-dynamo`, the split concept in `disaggregated-serving`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
kubectl version -o json | jq -r '.serverVersion.gitVersion'            # Dynamo chart needs 1.30+
kubectl get nodes -o json | jq -r '.items[] | [.metadata.name, (.status.allocatable["nvidia.com/gpu"] // "0"), (.status.allocatable["rdma/ib"] // "no-rdma")] | @tsv'
kubectl get crd | grep -E 'nvidia.com|grove|kai|leaderworkerset|volcano'
kubectl get clusterrolebinding -o json | jq -r '.items[] | select(.metadata.name | contains("dynamo-operator-manager")) | .subjects[0].namespace'
helm list -A | grep -Ei 'dynamo|gpu-operator|grove|kai'
kubectl get dynamographdeployments -A 2>/dev/null
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null
```

## Decision flow

1. **No Dynamo operator** -> install the platform: `references/install-platform.md`. If a cluster-wide operator already exists, do not install a second one.
2. **Is a split justified?** Measure aggregated first (`agg.yaml`). Long prompts, tight TTFT and ITL targets, enough GPUs for both pools and a fast fabric justify it. Otherwise stay aggregated. See `disaggregated-serving`.
3. **Single-node workers (one GPU or one node per worker)** -> `references/deploy-disagg.md`.
4. **Workers span nodes (large TP or EP)** -> multinode needs Grove with KAI Scheduler, or LeaderWorkerSet with Volcano: `references/install-platform.md`, then the multinode section of `references/deploy-disagg.md`.
5. **Production KV transfer** -> RDMA first: `references/kv-transfer-and-networking.md`. Without it Dynamo falls back to TCP with severe TTFT degradation.
6. **Repeated prefixes or many replicas** -> KV-aware routing, then Planner for autoscaling: `references/routing-scaling-ops.md`.
7. **Hangs, KV exhaustion, image or driver errors** -> `references/routing-scaling-ops.md` (failure table).

## Rules

- **Ask before changing the system.** CRDs, operators, Helm releases, GPU pods and privileged containers need approval and an undo path.
- **Secrets never touch output.** The `hf-token-secret` is built from a `0600` file or env var, never echoed or committed.
- **Pin versions.** Dynamo 1.5.1 ships TRT-LLM `1.3.0rc25`, a release candidate. Tell the user, and pin the image tag. Do not assume it matches the `tensorrt-llm` skill's engine version.
- **Use the v1beta1 API.** Older docs still show `v1alpha1`. Check `kubectl explain` against the installed CRD.
- **Size `max_tokens_in_buffer`.** It must exceed the longest input, or workers can deadlock under load.
- **Do not copy example GPU or parallelism numbers.** The shipped Qwen3-0.6B example uses one GPU per role; real models need TP and pool sizes derived from `choosing-hardware`.
- **Keep the aggregated deployment** until the split beats it on your workload and passes a `llm-evals` check.
- **RDMA and privileged modes are cluster decisions.** Never add `privileged: true`, host paths or extra capabilities without asking.

## Build the stack

- [ ] Check GPU driver, CUDA and RDMA readiness -> `references/kv-transfer-and-networking.md`
- [ ] Install the Dynamo platform (and Grove or LWS if multinode) -> `references/install-platform.md`
- [ ] Create the HF token Secret -> `references/install-platform.md`
- [ ] Baseline: deploy aggregated and measure -> `references/deploy-disagg.md`
- [ ] Deploy the disaggregated `DynamoGraphDeployment` with engine YAMLs -> `references/deploy-disagg.md`
- [ ] Configure `cache_transceiver_config` and the fabric -> `references/kv-transfer-and-networking.md`
- [ ] Optional: KV router, then Planner or autoscaling -> `references/routing-scaling-ops.md`
- [ ] Verify: the DGD is Successful, frontend `/v1/models` lists the model, a chat request returns, worker logs show NIXL initialised with the expected backend, and TTFT and ITL beat the aggregated run under the target load.

## Version pins to know (checked 2026-10-11)

| Component                         | Version                                      |
| --------------------------------- | -------------------------------------------- |
| Dynamo platform chart and images  | 1.5.1                                        |
| Kubernetes                        | 1.30+                                        |
| TRT-LLM inside Dynamo 1.5.1       | `1.3.0rc25` (release candidate)              |
| `tensorrt-llm` skill in this repo | v1.2.1 stable engine docs                    |
| Grove and KAI Scheduler for 1.5.x | Grove >= `v0.1.0-alpha.13`, KAI >= `v0.17.0` |
| LWS for the alternative           | >= v0.7.0                                    |

## Reference index

- `references/install-platform.md`: GPU operator, Dynamo chart, multinode orchestrators, verification, uninstall.
- `references/deploy-disagg.md`: aggregated baseline, disaggregated DGD, engine YAMLs, multinode, request test.
- `references/kv-transfer-and-networking.md`: `cache_transceiver_config`, NIXL backends, RDMA, EFA, GB200 notes.
- `references/routing-scaling-ops.md`: KV router, Planner, failure table, upgrades, teardown, verification gaps.

## Companion skills

- `nvidia-dynamo`: Dynamo platform depth. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dynamo`. If it is not yet listed in the install picker, install later: nvidia-dynamo skill.
- `tensorrt-llm`: engine build and config. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`.
- `disaggregated-serving`: when the split helps and the numerics gate. Install: `npx skills add ScaleDockHQ/llm-skills --skill disaggregated-serving`.
- `multi-node-inference`: multinode TP and EP concepts. Install: `npx skills add ScaleDockHQ/llm-skills --skill multi-node-inference`.
- `prefix-aware-routing`: KV-aware routing background. Install: `npx skills add ScaleDockHQ/llm-skills --skill prefix-aware-routing`.
- `nccl-rdma-networking`: RDMA, GPUDirect and fabric checks. Install: `npx skills add ScaleDockHQ/llm-skills --skill nccl-rdma-networking`.
- `nvidia-gpu-operator`: drivers and device plugin. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-gpu-operator`.
- `llm-evals`: quality gate after enabling the split. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `choosing-hardware`: size GPUs and nodes. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
