# Installing llm-d

> Verified against llm-d v0.10.0 (docs/getting-started/quickstart.md, guides/optimized-baseline, guides/env.sh, release notes), 2026-10-11

llm-d is a CNCF sandbox project (founded by Red Hat, Google Cloud, IBM Research, CoreWeave and NVIDIA). A deployment has
two halves: the **llm-d Router** (an Endpoint Picker, EPP, plus a proxy) and a **model-server pool** (vLLM, SGLang
or TensorRT-LLM Deployments or LeaderWorkerSets labeled for an `InferencePool`). Guides are kustomize overlays plus Helm
values in the `llm-d/llm-d` repository; check out the release branch that matches the version you want.

## Prerequisites

- kubectl, helm, git. Cluster with enough accelerators for the guide's table (optimized baseline default: 16 GPUs).
- Gateway API Inference Extension CRDs (`inference.networking.k8s.io` and related): installed from the
  `kubernetes-sigs/gateway-api-inference-extension` release manifests, version from `guides/env.sh` (`GAIE_VERSION`).
- For gateway mode: Gateway API CRDs (`GATEWAY_API_VERSION`) and a supporting implementation.
- A namespace and a Hugging Face token Secret named `llm-d-hf-token` with key `HF_TOKEN`.

```bash
git clone --depth 1 --branch release-0.10 https://github.com/llm-d/llm-d.git && cd llm-d
export REPO_ROOT=$(realpath .)
source "$REPO_ROOT/guides/env.sh"
env | grep -E '^(GAIE|GATEWAY_API|ROUTER)_' | sort        # the pins in effect
```

## Versions in v0.10.0 (from `guides/env.sh` and release notes)

| Item                     | Value                                                                                                                               |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| Router charts            | `oci://ghcr.io/llm-d/charts/llm-d-router-standalone` and `...llm-d-router-gateway`, tag `v0.11.0` (tags `v0.10.0`, `v0.11.0` exist) |
| EPP image                | `ghcr.io/llm-d/llm-d-router-endpoint-picker:v0.11.0`; sidecar `llm-d-router-disagg-sidecar:v0.11.0`                                 |
| Model server (NVIDIA)    | `docker.io/vllm/vllm-openai` `v0.30.0` via the `gpu-vllm/release` kustomize component                                               |
| Other accelerator images | `ghcr.io/llm-d/llm-d-rocm`, `-xpu`, `-cpu` at `v0.10.0`                                                                             |
| Deprecated               | `ghcr.io/llm-d/llm-d-cuda` and `llm-d-aws` builds (use vLLM's images)                                                               |

## Standalone mode (recommended start)

The router includes an Envoy sidecar and its own Service `${GUIDE_NAME}-epp`; no Gateway object is needed.

```bash
export GUIDE_NAME=quickstart NAMESPACE=llm-d-quickstart
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/${GAIE_URL}/v1-manifests.yaml
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic llm-d-hf-token -n $NAMESPACE --from-file=HF_TOKEN=/path/to/token-file

helm install $GUIDE_NAME $ROUTER_STANDALONE_CHART \
  -f guides/recipes/router/base.values.yaml \
  -f guides/optimized-baseline/router/optimized-baseline.values.yaml \
  -n $NAMESPACE --version $ROUTER_CHART_VERSION

kubectl apply -n $NAMESPACE -k guides/optimized-baseline/modelserver/gpu/vllm/base/
bash guides/scripts/wait-for-pods-ready.sh -l llm-d.ai/guide=optimized-baseline -n $NAMESPACE
```

Notes: the quickstart sets `GUIDE_NAME=quickstart` while the model-server overlay labels pods
`llm-d.ai/guide=optimized-baseline`; the router values match on that label. Model pods can take several minutes to load.
`base.values.yaml` runs the proxy as `envoy` (switch to `agentgateway` with `--set router.proxy.proxyType=agentgateway`
plus `features/agentgateway-proxy.values.yaml`), one EPP replica, `FailOpen` for the InferencePool.

Test from inside the cluster:

```bash
IP=$(kubectl get service ${GUIDE_NAME}-epp -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
kubectl run curl-debug --rm -it --image=cfmanteiga/alpine-bash-curl-jq -n $NAMESPACE --env="IP=$IP" -- \
  curl -s -X POST http://$IP/v1/completions -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen3-32B","prompt":"How are you today?","max_tokens":32}'
```

## Gateway mode

1. Deploy a Gateway named `llm-d-inference-gateway` from `docs/infrastructure/gateway` (GKE Gateway, Istio,
   agentgateway or Envoy AI Gateway; all need cluster admin rights).
2. Install the gateway chart with an HTTPRoute:

```bash
helm install $GUIDE_NAME $ROUTER_GATEWAY_CHART \
  -f guides/recipes/router/base.values.yaml \
  -f guides/optimized-baseline/router/optimized-baseline.values.yaml \
  --set provider.name=${PROVIDER_NAME} --set httpRoute.create=true \
  --set httpRoute.inferenceGatewayName=llm-d-inference-gateway \
  -n $NAMESPACE --version $ROUTER_CHART_VERSION
```

`PROVIDER_NAME` is `none`, `gke`, `agentgateway` or `istio`; on GKE `none` creates no `HealthCheckPolicy` and the
Gateway never turns healthy.

## Accelerators and variants (optimized baseline)

Directory under `guides/optimized-baseline/modelserver/`: `gpu` (NVIDIA; `INFRA_PROVIDER` base or gke, `MODEL_SERVER`
vllm, sglang or trtllm), `amd`, `xpu`, `tpu/v6`, `tpu/v7`, `npu`, `iluvatar`, `cpu` (x86 with AMX or AVX512-BF16,
64 cores and 64 GB RAM per replica; older CPUs crash). Other model example:
`kubectl apply -n $NAMESPACE -k guides/optimized-baseline/modelserver/gpu/vllm/gpt-oss/`.

## Without Kubernetes

`guides/no-kubernetes-deployment` runs the same EPP, Envoy and model servers as host processes or containers, with the
endpoint list from a YAML file. Out of scope there: InferenceObjective flow control, InferenceModelRewrite,
PodMonitor discovery.

## Cleanup

```bash
helm uninstall $GUIDE_NAME -n $NAMESPACE
kubectl delete namespace $NAMESPACE      # deletes the model servers and the Secret
```

The inference extension CRDs are cluster-wide; leave them unless nothing else uses them.

## Sources

- <https://llm-d.ai/docs/getting-started/quickstart>
- <https://github.com/llm-d/llm-d/tree/release-0.10/guides/optimized-baseline>
- <https://github.com/llm-d/llm-d/blob/v0.10.0/guides/env.sh>
