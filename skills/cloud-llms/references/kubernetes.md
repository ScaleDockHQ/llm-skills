# Kubernetes for LLM serving

> Verified against NVIDIA GPU Operator v26.7.1 getting-started docs, vLLM v0.31.0 docs (Using Kubernetes, LWS pages), KServe v0.21.0, llm-d v0.10.0, vLLM production-stack vllm-stack-0.1.13, AIBrix v0.7.0, LeaderWorkerSet v0.11.1 installation docs, 2026-10-11

## What it is and when to choose it

Running inference engines as Kubernetes workloads on GPU nodes (managed clusters such as EKS, GKE, AKS, CoreWeave CKS, or your own). Choose it when you serve several models or many replicas, already operate Kubernetes, and want declarative rollouts and autoscaling. For one model on one GPU box, a VM is simpler (`gpu-vms.md`).

Options, from simplest to most capable:

| Option                                       | What it adds                                                                 | Choose when                                                                                     |
| -------------------------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Plain manifests (Deployment + Service + PVC) | Nothing beyond Kubernetes                                                    | One or a few models, full control. Template: `assets/k8s/vllm-deployment.yaml`                  |
| vLLM production-stack (Helm)                 | Router with session and prefix-aware routing, LMCache offload, Grafana       | Several vLLM models behind one router, quick start                                              |
| KServe `InferenceService`                    | Model CRD, storage initializer (`hf://`, S3, GCS), OpenAI routes, KEDA       | Platform teams standardizing model serving. Template: `assets/k8s/kserve-inferenceservice.yaml` |
| KServe `LLMInferenceService` / llm-d         | Cache-aware routing, prefill/decode disaggregation, wide expert parallelism  | Large fleets where cache locality and tail latency matter                                       |
| AIBrix                                       | Envoy gateway with LLM-aware routing, PodAutoscaler, LoRA adapters, KV cache | vLLM fleets that want a gateway plus control plane in one project                               |
| LeaderWorkerSet (LWS)                        | Multi-node pod groups for one model replica                                  | Models too large for one node                                                                   |

## Install / setup

**GPU nodes and drivers: NVIDIA GPU Operator** (drivers, container toolkit, device plugin, monitoring). Managed clouds sometimes preinstall parts of this; check your provider first. Depth: skill `nvidia-gpu-operator`.

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
helm install --wait --generate-name -n gpu-operator --create-namespace \
  nvidia/gpu-operator --version=v26.7.1
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
```

**LeaderWorkerSet** (multi-node replicas):

```bash
VERSION=v0.11.1
kubectl apply --server-side -f "https://github.com/kubernetes-sigs/lws/releases/download/$VERSION/manifests.yaml"
```

Stack-specific install commands live in the skills listed under Depth. Do not copy install commands from memory: chart and release tags move, and the KServe docs, for example, lagged the latest release.

## Minimal working config

`assets/k8s/vllm-deployment.yaml` follows vLLM's Kubernetes guide: a PVC for the Hugging Face cache, a Secret for the token, a Deployment running `vllm/vllm-openai` with a memory-backed `/dev/shm`, `/health` probes and one GPU, and a ClusterIP Service.

```bash
kubectl create secret generic hf-token-secret --from-file=token=<path-to-token-file>   # no token on the command line
kubectl apply -f assets/k8s/vllm-deployment.yaml
kubectl rollout status deploy/vllm-chat
kubectl port-forward svc/vllm-chat 8000:80 &
curl -s http://localhost:8000/v1/models | jq -r '.data[].id'
```

`assets/k8s/kserve-inferenceservice.yaml` follows KServe's text-generation guide (Secret, `ClusterStorageContainer` for `hf://`, `InferenceService` with the Hugging Face runtime).

## How it plugs into the stack

- Endpoint: a ClusterIP Service (`http://vllm-chat.<namespace>.svc.cluster.local/v1`) for an in-cluster gateway, or an Ingress/Gateway with TLS for an external gateway. Each stack in Depth documents its own route shape.
- Health: vLLM `/health` (used by the probes); stack-specific readiness conditions otherwise.
- Auth: run the gateway in the cluster and keep engine Services internal; add NetworkPolicies so only the gateway can reach them. vLLM's `--api-key` does not cover every route.

## Operating

- **Model caching.** Put the Hugging Face cache on a PVC (`ReadWriteOnce` per replica, or `ReadWriteMany` shared storage) so pods do not re-download weights. Pre-pull large images onto GPU nodes.
- **Startup time.** Large models take minutes to load. Use a startup probe or generous `failureThreshold`; a probe failing too early kills the container.
- **Autoscaling on queue depth.** GPU utilization is a poor signal. Scale on vLLM metrics such as `vllm:num_requests_waiting`. Set scale-up fast, scale-down slow (skill `keda`).
- **Node pools.** Separate GPU node pools with taints; let the cluster autoscaler add GPU nodes (request the quota first).
- **Rollouts.** A surge pod needs a free GPU. With no spare GPU, use `maxSurge: 0, maxUnavailable: 1` or keep a fallback in the gateway.

## Known pitfalls

- Missing `nvidia.com/gpu` request: the pod lands on a CPU node or never sees the GPU.
- `vllm/vllm-openai:latest` in production; pin the tag.
- HF token in a manifest committed to git; create the Secret from a file or a secret manager.
- `ReadWriteOnce` PVC shared by replicas on different nodes: only one can mount it.
- Scale-to-zero with large models: cold starts measured in minutes.

## Depth

This note stays short on purpose. Install the skill for the stack you choose:

| Need                                                 | Skill                             | Install                                                                         |
| ---------------------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------- |
| Model-serving CRDs, `LLMInferenceService`            | `kserve`                          | `npx skills add ScaleDockHQ/llm-skills --skill kserve`                          |
| Cache-aware routing, P/D, wide expert parallelism    | `llm-d`                           | `npx skills add ScaleDockHQ/llm-skills --skill llm-d`                           |
| Helm router plus vLLM engines                        | `vllm-production-stack`           | `npx skills add ScaleDockHQ/llm-skills --skill vllm-production-stack`           |
| Gateway, control plane, LoRA and KV cache            | `aibrix`                          | `npx skills add ScaleDockHQ/llm-skills --skill aibrix`                          |
| Ray-based serving and multi-node                     | `ray-serve`                       | `npx skills add ScaleDockHQ/llm-skills --skill ray-serve`                       |
| Inference-aware gateway routing (EPP, InferencePool) | `gateway-api-inference-extension` | `npx skills add ScaleDockHQ/llm-skills --skill gateway-api-inference-extension` |
| GPU drivers, device plugin, MIG, monitoring          | `nvidia-gpu-operator`             | `npx skills add ScaleDockHQ/llm-skills --skill nvidia-gpu-operator`             |
| Event-driven autoscaling                             | `keda`                            | `npx skills add ScaleDockHQ/llm-skills --skill keda`                            |

## Official links

- NVIDIA GPU Operator: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html
- vLLM on Kubernetes: https://docs.vllm.ai/en/latest/deployment/k8s/
- vLLM with LWS: https://docs.vllm.ai/en/latest/deployment/frameworks/lws/
- vLLM production-stack: https://github.com/vllm-project/production-stack
- KServe: https://kserve.github.io/website/
- llm-d: https://llm-d.ai/docs/getting-started/quickstart
- AIBrix: https://aibrix.readthedocs.io/latest/
- LeaderWorkerSet install: https://lws.sigs.k8s.io/docs/installation/
