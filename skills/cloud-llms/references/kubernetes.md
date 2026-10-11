# Kubernetes for LLM serving

> Verified against NVIDIA GPU Operator v26.7.1 getting-started docs, vLLM v0.31.0 docs (Using Kubernetes, LWS, production-stack, KServe, llm-d pages), vLLM production-stack vllm-stack-0.1.13, KServe v0.21.0 (website docs: text generation, KEDA autoscaling, quickstart showing v0.20.0 install scripts), llm-d v0.10.0, LeaderWorkerSet v0.11.1 installation docs, 2026-10-11

## What it is and when to choose it

Running inference engines as Kubernetes workloads on GPU nodes (managed clusters such as EKS, GKE, AKS, CoreWeave CKS, or your own). Choose it when you serve several models or many replicas, already operate Kubernetes, and want declarative rollouts and autoscaling. For one model on one GPU box, a VM is simpler (`gpu-vms.md`).

Options, from simplest to most capable:

| Option                                       | What it adds                                                                                              | Choose when                                                                                     |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Plain manifests (Deployment + Service + PVC) | Nothing beyond Kubernetes                                                                                 | One or a few models, you want full control. Template: `assets/k8s/vllm-deployment.yaml`         |
| vLLM production-stack (Helm)                 | Router with model-aware and prefix-aware routing, Grafana dashboards, KV offloading via LMCache           | Several vLLM models behind one router, quick start                                              |
| KServe `InferenceService`                    | Model CRD, storage initializer (`hf://`, S3, GCS), OpenAI routes under `/openai/v1`, autoscaling (KEDA)   | Platform teams standardizing model serving. Template: `assets/k8s/kserve-inferenceservice.yaml` |
| KServe `LLMInferenceService` / llm-d         | Prefix-cache-aware routing, prefill/decode disaggregation, wide expert parallelism, SLO-aware autoscaling | Large fleets where cache locality and tail latency matter                                       |
| LeaderWorkerSet (LWS)                        | Multi-node pod groups for one model replica                                                               | Models too large for one node                                                                   |

## Install / setup

**GPU nodes and drivers: NVIDIA GPU Operator** (installs drivers, container toolkit, device plugin, monitoring). Managed clouds sometimes preinstall parts of this; check your provider's docs before installing.

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
helm install --wait --generate-name -n gpu-operator --create-namespace \
  nvidia/gpu-operator --version=v26.7.1
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
```

**vLLM production-stack:**

```bash
helm repo add vllm https://vllm-project.github.io/production-stack
helm install vllm vllm/vllm-stack -f <your-values.yaml>
kubectl port-forward svc/vllm-router-service 30080:80   # then: curl http://localhost:30080/v1/models
```

Start from the repo's `tutorials/assets/values-01-minimal-example.yaml` and pin the chart version.

**KServe:** follow the quickstart (Standard mode for KEDA autoscaling). At verification time the docs' install scripts referenced v0.20.0 while the latest release was v0.21.0; use the release that matches the docs you follow.

**LeaderWorkerSet:**

```bash
VERSION=v0.11.1
kubectl apply --server-side -f "https://github.com/kubernetes-sigs/lws/releases/download/$VERSION/manifests.yaml"
```

**llm-d:** use its Quickstart, which deploys an "Optimized Baseline" (an intelligent router over a vLLM pool), then add well-lit-path guides as needed. It can also be deployed through KServe's `LLMInferenceService`.

## Minimal working config

`assets/k8s/vllm-deployment.yaml` follows vLLM's Kubernetes guide: a PVC for the Hugging Face cache, a Secret for the token, a Deployment running `vllm/vllm-openai` with a memory-backed `/dev/shm`, `/health` probes and one GPU, and a ClusterIP Service.

```bash
kubectl create secret generic hf-token-secret --from-file=token=<path-to-token-file>   # no token on the command line
kubectl apply -f assets/k8s/vllm-deployment.yaml
kubectl rollout status deploy/vllm-chat
kubectl port-forward svc/vllm-chat 8000:80 &
curl -s http://localhost:8000/v1/models | jq -r '.data[].id'
```

`assets/k8s/kserve-inferenceservice.yaml` follows KServe's text-generation guide: a Secret, a `ClusterStorageContainer` for `hf://` URIs and an `InferenceService` with the Hugging Face runtime (vLLM backend by default).

## How it plugs into the stack

- Endpoint: a ClusterIP Service (`http://vllm-chat.<namespace>.svc.cluster.local/v1`) for an in-cluster gateway, or an Ingress/Gateway with TLS for an external gateway. KServe serves OpenAI routes under `/openai/v1/...` on the InferenceService host.
- Health: vLLM `/health` (used by the probes); KServe `READY` condition on the InferenceService.
- Auth: run the gateway in the cluster and keep engine Services internal; add NetworkPolicies so only the gateway can reach them. vLLM's `--api-key` does not cover every route.
- API coverage: vLLM's OpenAI routes and Anthropic Messages API; KServe's Hugging Face runtime exposes OpenAI completions and chat completions.

## Operating

- **Model caching.** Put the Hugging Face cache on a PVC (`ReadWriteOnce` per replica, or `ReadWriteMany` shared storage) so pods do not re-download weights. KServe also has a LocalModel cache feature. Pre-pull large images onto GPU nodes.
- **Startup time.** Large models take minutes to load. Use a startup probe or generous `initialDelaySeconds`/`failureThreshold`; vLLM's docs note that a probe failing too early kills the container, with `KeyboardInterrupt: terminated` in logs.
- **Autoscaling on queue depth.** GPU utilization is a poor signal. Scale on vLLM metrics such as `vllm:num_requests_waiting` or `vllm:num_requests_running` (KServe + KEDA example: target value on `vllm:num_requests_running` from Prometheus). llm-d adds SLO-aware autoscaling. Set scale-up fast, scale-down slow.
- **Node pools.** Separate GPU node pools with taints; let the cluster autoscaler add GPU nodes (and request the GPU quota first).
- **Rollouts.** `maxSurge`/`maxUnavailable` with GPUs: a surge pod needs a free GPU. With no spare GPU, use `maxSurge: 0, maxUnavailable: 1` and accept reduced capacity, or keep a fallback in the gateway during rollout.

## Tuning knobs worth knowing

- vLLM args in the container command: `--max-model-len`, `--gpu-memory-utilization`, `--tensor-parallel-size` (match the GPU count requested), `--served-model-name`, `--max-num-seqs`.
- `/dev/shm` size for tensor parallelism (memory-backed `emptyDir`).
- Router choice: plain Service (round-robin) vs prefix-aware routing (production-stack router, llm-d), which matters as replicas grow.
- Multi-node: LWS group size, with `--tensor-parallel-size` per node and `--pipeline-parallel-size` across nodes (vLLM's LWS example).

## Known pitfalls

- Missing `nvidia.com/gpu` resource request: the pod schedules on a CPU node or never sees the GPU.
- `vllm/vllm-openai:latest` in production; pin the tag.
- HF token in a manifest committed to git; create the Secret from a file or a secret manager (External Secrets, CSI driver).
- `ReadWriteOnce` PVC shared by several replicas on different nodes: only one can mount it.
- Probes too aggressive for model load time.
- Scaling to zero on Kubernetes (Knative mode) with large models: cold starts measured in minutes.

## Official links

- NVIDIA GPU Operator: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html
- vLLM on Kubernetes: https://docs.vllm.ai/en/latest/deployment/k8s/
- vLLM with LWS: https://docs.vllm.ai/en/latest/deployment/frameworks/lws/
- vLLM production-stack: https://github.com/vllm-project/production-stack
- KServe generative inference overview: https://kserve.github.io/website/docs/model-serving/generative-inference/overview
- KServe quickstart: https://kserve.github.io/website/docs/getting-started/quickstart-guide
- KServe text generation: https://kserve.github.io/website/docs/model-serving/generative-inference/tasks/text-generation
- KServe KEDA autoscaling: https://kserve.github.io/website/docs/model-serving/generative-inference/autoscaling
- llm-d: https://llm-d.ai/docs/getting-started/quickstart
- LeaderWorkerSet install: https://lws.sigs.k8s.io/docs/installation/
