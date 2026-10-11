# Installing vllm-stack

> Verified against vllm-project/production-stack chart vllm-stack 0.1.13 (README, docs/source/getting_started, helm/Chart.yaml, Helm repo index, Docker Hub tags), 2026-10-11

The project is "vLLM's reference system for K8S-native cluster-wide deployment with community-driven performance
optimization": a serving-engine Deployment per model, a request router, and an observability stack, delivered as one Helm
chart (`vllm-stack`). Chart 0.1.13 was tagged 2026-09-29; the repository was active in October 2026.

## Prerequisites

- A Kubernetes cluster with NVIDIA GPU nodes: drivers, container toolkit, device plugin (skill `cloud-llms` and its
  Kubernetes note cover the NVIDIA GPU Operator). The chart sets `runtimeClassName: "nvidia"` by default, so the
  cluster needs a RuntimeClass of that name, or set `runtimeClassName: ""` (the upstream minimal examples do).
- helm 3 and kubectl. For a local GPU box the repo has `utils/install-minikube-cluster.sh` and
  `tutorials/00-install-kubernetes-env.md`.
- Hugging Face token for gated models, stored in a Secret.

```bash
nvidia-smi
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
kubectl get runtimeclass
```

## Install

```bash
helm repo add vllm https://vllm-project.github.io/production-stack
helm repo update
helm search repo vllm/vllm-stack --versions | head
helm install vllm vllm/vllm-stack --version 0.1.13 -f values.yaml      # release name sets service names
kubectl get pods -w
```

The release name `vllm` produces `vllm-router-service`, `vllm-deployment-router` and, per model,
`vllm-<modelSpec.name>-engine-service` plus an engine Deployment. The Helm index also lists 0.1.12 and older.
The chart depends on optional sub-charts: `kube-prometheus-stack` 82.4.3, `prometheus-adapter` 5.3.0 and `k8s-aibom`
1.5.1, each switched on with `<name>.enabled`.

Use the repo checkout when a tutorial values file is needed: `git clone https://github.com/vllm-project/production-stack`
(tutorial files live in `tutorials/assets`, for example `values-01-minimal-example.yaml`). Pin to the tag that matches
your chart (`vllm-stack-0.1.13`) so the values files match the chart.

## Image tags

Chart defaults are `lmcache/vllm-openai:latest` for engines (`servingEngineSpec.modelSpec[].repository/tag`) and
`lmcache/lmstack-router:latest` for the router, both pulled with `imagePullPolicy: Always`. Docker Hub had router tag
`v0.1.13` and `lmcache/vllm-openai` tags such as `v0.5.5` (plus release candidates) at verification time. Upstream
tutorials also use `vllm/vllm-openai`. Pin explicit tags and set `imagePullPolicy: IfNotPresent`.

## Verify

```bash
kubectl port-forward svc/vllm-router-service 30080:80 &
curl -s localhost:30080/v1/models | jq '.data[].id'
curl -s localhost:30080/health
curl -s localhost:30080/engines | jq        # backends the router discovered
```

## Operator alternative

`kubectl create -f operator/config/default.yaml` installs an operator in `production-stack-system` with four CRDs
(`CacheServer`, `LoraAdapter`, `VLLMRouter`, `VLLMRuntime`); the docs recommend it for production resource management.
The Helm chart is the path every tutorial uses; pick one method per cluster and do not mix them for the same models.

## Cloud clusters

`tutorials/cloud_deployments` covers AWS EKS, GCP (GKE), Lambda Labs and Azure. Managed clusters usually ship the GPU
operator pieces; check before installing your own.

## Uninstall

```bash
helm uninstall vllm
kubectl get pvc | grep vllm       # model-cache PVCs remain; delete them deliberately
```

## Sources

- <https://github.com/vllm-project/production-stack>
- <https://docs.vllm.ai/projects/production-stack>
- <https://vllm-project.github.io/production-stack/index.yaml>
