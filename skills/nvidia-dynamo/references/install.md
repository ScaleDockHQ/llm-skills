# NVIDIA Dynamo install

> Verified against Dynamo v1.5.1 (PyPI ai-dynamo 1.5.1), 2026-10-11

Sources: README, local installation and Kubernetes installation guides, release v1.5.1.

## Requirements

| Item          | Supported                                                                         |
| ------------- | --------------------------------------------------------------------------------- |
| GPU           | NVIDIA Ampere, Ada Lovelace, Hopper, Blackwell (Intel GPUs on Kubernetes via DRA) |
| OS            | Ubuntu 22.04 or 24.04 (arm64 needs 24.04)                                         |
| Arch          | x86_64, arm64                                                                     |
| CUDA / driver | 12.9+ with driver 575.51.03+, or 13.0+ with 580.00.03+ (B300/GB300 need CUDA 13)  |
| Python        | 3.10 or 3.12 (TensorRT-LLM does not support 3.11); the PyPI wheel needs >=3.10    |

The prebuilt container bundles CUDA and engine dependencies; the host needs only the driver, Docker and the
NVIDIA Container Toolkit. The wheel path also needs the CUDA toolkit.

## Containers (recommended)

| Backend       | Image (v1.5.1)                                                                     |
| ------------- | ---------------------------------------------------------------------------------- |
| vLLM          | `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.1`                                      |
| SGLang        | `nvcr.io/nvidia/ai-dynamo/sglang-runtime:1.5.1`                                    |
| TensorRT-LLM  | `nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1`                               |
| Frontend only | `nvcr.io/nvidia/ai-dynamo/dynamo-frontend:<release>` (listed in Release Artifacts) |

Engine versions bundled in 1.5.1: SGLang 0.5.18, TensorRT-LLM 1.3.0rc25, vLLM 0.28.0, NIXL 1.3.x/1.4.0, UCX 1.21.0.
CUDA: SGLang 13.0, TensorRT-LLM 13.1, vLLM 13.0. The Release Artifacts page lags releases (it listed 1.4.2 on the
v1.5.1 tag): confirm tags on the NGC catalog before pulling.

```bash
docker run --gpus all --network host --rm -it -e HF_TOKEN nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.1
```

Run frontend and worker inside the container (`docker exec -it <id> bash` for more shells). Without `--gpus all`
the container starts but sees no GPU.

## Wheels

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # review before running
uv venv venv && source venv/bin/activate && uv pip install pip
sudo apt install python3-dev libxcb1                 # vLLM
uv pip install --prerelease=allow "ai-dynamo[vllm]"
uv pip install --prerelease=allow "ai-dynamo[sglang]"
```

TensorRT-LLM has no selector wheel path: use the container, or `pip` with `--extra-index-url https://pypi.nvidia.com`
per the install guide. For CUDA 13 hosts prefer the container. Verify: `python3 -m dynamo.frontend --help`; from a
repo checkout `python3 dev/sanity_check.py`.

## Discovery modes

|                             | `--discovery-backend file` | etcd + NATS                                                    |
| --------------------------- | -------------------------- | -------------------------------------------------------------- |
| Services                    | none                       | `docker compose -f dev/docker-compose.yml up -d` from the repo |
| Scope                       | one machine                | one machine or multi-node                                      |
| KV events, routing, Planner | not available              | available                                                      |
| Crash cleanup               | none                       | lease TTL (default 10 s)                                       |

`--discovery-backend` choices: `kubernetes`, `etcd` (default), `file`, `mem`. etcd mode reads `ETCD_ENDPOINTS`.
`--request-plane` is `tcp` (default) or `nats`; `--event-plane` is `nats` or `zmq`. With file discovery and vLLM, also pass
`--kv-events-config '{"enable_kv_cache_events": false}'`. KV-aware routing does not require NATS: use
`--no-router-kv-events` for prediction-based routing.

## Kubernetes

Needs Kubernetes 1.30+, kubectl 1.30+, Helm 3. Optional pieces: Grove + KAI Scheduler (multinode and
disaggregated), Network Operator / RDMA (production disaggregation), kube-prometheus-stack (Planner `sla` mode,
autoscaling), shared model storage (models over 70B or many replicas).

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
helm install gpu-operator nvidia/gpu-operator --namespace gpu-operator --create-namespace
# add --set driver.enabled=false when nodes already have drivers (AKS, EKS, GKE guides)

export NAMESPACE=dynamo-system
export RELEASE_VERSION=1.5.1   # the guide's example says 1.2.1; use a current release
helm fetch https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-$RELEASE_VERSION.tgz
helm install dynamo-platform dynamo-platform-$RELEASE_VERSION.tgz --namespace $NAMESPACE --create-namespace
kubectl get crd | grep dynamo
kubectl get pods -n $NAMESPACE   # dynamo-operator-* and nats-* Running
```

Optional values (add before first install, or `helm upgrade --reuse-values`):
`global.grove.install=true` and `global.kai-scheduler.install=true` (bundled, dev/test), or `global.grove.enabled=true` /
`global.kai-scheduler.enabled=true` (already installed, production); Prometheus endpoint with
`dynamo-operator.dynamo.metrics.prometheusEndpoint=<url>`.

Do not install a second operator in a shared cluster: check for an existing cluster-wide one with
`kubectl get clusterrolebinding | grep dynamo-operator-manager`. `namespaceRestriction.enabled=true` is dev/test only
(set `dynamo-operator.upgradeCRD=false` with it). Intel GPU clusters need Kubernetes 1.34+ with DRA and the Intel
resource drivers (not installed by the chart).

## Build from source

Contributors only: Rust toolchain, `maturin develop --uv` in `lib/bindings/python`, then `uv pip install -e .`. See the
building-from-source guide.

## Uninstall

`helm uninstall dynamo-platform -n $NAMESPACE`; CRDs may remain (`kubectl get crd | grep dynamo`); delete them only
after removing every DGD. Local: stop the processes, `docker compose -f dev/docker-compose.yml down`.
