# Install the optimized baseline

> Verified against llm-d v0.10.0, llm-d-router v0.11.0, Gateway API Inference Extension v1.5.0, vLLM v0.30.0 (guide default), 2026-10-11

The optimized baseline is llm-d's recommended starting point: a router (EPP plus proxy) that is prefix-cache aware and token-load aware, in front of N single-host vLLM replicas. Source of truth: the llm-d repo at `guides/optimized-baseline/README.md`.

## Prerequisites

- Kubernetes 1.33+ recommended. On 1.28 or older, pods using sidecar init containers (`restartPolicy: Always`) can stick at `Init:0/1`.
- GPU nodes with drivers and the device plugin (see the `nvidia-gpu-operator` skill).
- `kubectl`, `helm`, `git`.
- Enough GPUs. The guide's default is 8 replicas times 2 GPUs (Qwen3-32B, TP=2), 16 in total. Reduce `replicas` and the model for a smaller cluster, and size with the `choosing-hardware` skill.

## Pull the guide at a pinned tag

```bash
git clone --depth 1 --branch v0.10.0 https://github.com/llm-d/llm-d.git
cd llm-d
export REPO_ROOT=$(realpath "$(git rev-parse --show-toplevel)")
export GUIDE_NAME=optimized-baseline
export NAMESPACE=llm-d-optimized-baseline
export MODEL_SERVER=vllm ACCELERATOR_TYPE=gpu INFRA_PROVIDER=base
export MONITORING_VALUES=
source ${REPO_ROOT}/guides/env.sh
echo "$GAIE_VERSION $ROUTER_CHART_VERSION $ROUTER_STANDALONE_CHART"
```

`env.sh` at `v0.10.0` sets `GAIE_VERSION=v1.5.0` and `ROUTER_CHART_VERSION=v0.11.0`. The README prose says it sets `v0` (a floating channel). Trust the file, and print the values as above before installing.

## CRDs, namespace, token

Show and approve before applying cluster-scoped CRDs:

```bash
# GAIE_URL is computed by env.sh from GAIE_VERSION
kubectl apply --dry-run=server -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/${GAIE_URL}/v1-manifests.yaml
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/${GAIE_URL}/v1-manifests.yaml

kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
```

Gateway mode also needs Gateway API CRDs (`GATEWAY_API_VERSION`, v1.5.1) and a Gateway controller. Standalone mode needs neither.

HF token (only for gated models; public models can drop the Secret reference or mark it optional). Read it from a file or an env var that is already set, never type it into a command line that logs history:

```bash
umask 077
printf '%s' "$HF_TOKEN" > /tmp/hf-token
kubectl create secret generic llm-d-hf-token --namespace "${NAMESPACE}" \
  --from-file=HF_TOKEN=/tmp/hf-token --dry-run=client -o yaml | kubectl apply -f -
rm -f /tmp/hf-token
```

An optional Secret does not bypass model authorization.

## Router

Standalone mode (an Envoy sidecar next to the EPP, no Gateway needed):

```bash
export ROUTER_BASE_VALUES=${REPO_ROOT}/guides/recipes/router/base.values.yaml
export ROUTER_VALUES=${REPO_ROOT}/guides/${GUIDE_NAME}/router/${GUIDE_NAME}.values.yaml

helm install ${GUIDE_NAME} ${ROUTER_STANDALONE_CHART} \
  -f ${ROUTER_BASE_VALUES} ${MONITORING_VALUES} -f ${ROUTER_VALUES} \
  -n ${NAMESPACE} --version ${ROUTER_CHART_VERSION}
```

Gateway mode (an existing Gateway named `llm-d-inference-gateway`; set `PROVIDER_NAME` to `none`, `gke`, `agentgateway` or `istio`):

```bash
helm install ${GUIDE_NAME} ${ROUTER_GATEWAY_CHART} \
  -f ${ROUTER_BASE_VALUES} ${MONITORING_VALUES} -f ${ROUTER_VALUES} \
  --set provider.name=${PROVIDER_NAME} --set httpRoute.create=true \
  --set httpRoute.inferenceGatewayName=llm-d-inference-gateway \
  -n ${NAMESPACE} --version ${ROUTER_CHART_VERSION}
```

TensorRT-LLM uses a separate values file (`optimized-baseline-trtllm.values.yaml`). For agentgateway as the sidecar, see `guides/recipes/router/README.md`.

The base values set the EPP to one replica, `failureMode: FailOpen`, and `proxyType: envoy`. Keep EPP at one replica when flow control or in-flight token accounting is on (the accounting is per EPP process).

## Model servers

Preview what will be applied, then apply:

```bash
kubectl kustomize ${REPO_ROOT}/guides/${GUIDE_NAME}/modelserver/${ACCELERATOR_TYPE}/${MODEL_SERVER}/${INFRA_PROVIDER}/ | grep -nE 'image:|REPLACE_|replicas:|nvidia.com/gpu|--tensor-parallel'
kubectl apply -n ${NAMESPACE} \
  -k ${REPO_ROOT}/guides/${GUIDE_NAME}/modelserver/${ACCELERATOR_TYPE}/${MODEL_SERVER}/${INFRA_PROVIDER}/
```

Defaults to adjust: model `Qwen/Qwen3-32B`, 8 replicas, TP=2, image `docker.io/vllm/vllm-openai:v0.30.0` (from the `gpu-vllm/release` image component). Edit the patch file `patch-vllm.yaml` in a copy of the overlay, or write a small kustomization that overlays yours, rather than editing the checked-out tree you want to keep clean. Another model overlay ships as `modelserver/gpu/vllm/gpt-oss/`. Image overrides: `guides/recipes/modelserver/components/images/README.md`.

Model loading, node-local caches and registries: `docs/operations/model-loading-and-startup.md` in the repo.

## Verify

```bash
kubectl -n ${NAMESPACE} get pods,svc,inferencepool
kubectl -n ${NAMESPACE} rollout status deploy/${GUIDE_NAME}-epp --timeout=300s
export IP=$(kubectl get service ${GUIDE_NAME}-epp -n ${NAMESPACE} -o jsonpath='{.spec.clusterIP}')   # standalone
# gateway mode:
# export IP=$(kubectl get gateway llm-d-inference-gateway -n ${NAMESPACE} -o jsonpath='{.status.addresses[0].value}')

export MODEL=Qwen/Qwen3-32B
kubectl run curl-test --rm -i --restart=Never --namespace "${NAMESPACE}" \
  --image=cfmanteiga/alpine-bash-curl-jq:latest --env="IP=${IP}" --env="MODEL=${MODEL}" \
  -- /bin/sh -c 'curl -sS -X POST "http://${IP}/v1/completions" -H "Content-Type: application/json" -d "{\"model\": \"${MODEL}\", \"prompt\": \"How are you today?\"}"'
```

The curl-test image is a community image the guide uses; substitute your own utility image if policy requires.

## Optional: monitoring

Install the monitoring stack first (`docs/operations/observability/setup.md`). Enabling `monitoring.values.yaml` before the Prometheus Operator CRDs exist fails Helm validation. Then:

```bash
helm upgrade ${GUIDE_NAME} ${ROUTER_STANDALONE_CHART} \
  -f ${ROUTER_BASE_VALUES} -f ${REPO_ROOT}/guides/recipes/router/features/monitoring.values.yaml \
  -f ${ROUTER_VALUES} -n ${NAMESPACE} --version ${ROUTER_CHART_VERSION}
kubectl apply -n ${NAMESPACE} -k ${REPO_ROOT}/guides/recipes/modelserver/components/monitoring
```

Key metrics: `llm_d_epp_request_total`, `vllm:num_requests_running`, `vllm:prefix_cache_hits_total` over `vllm:prefix_cache_queries_total`, `vllm:kv_cache_usage_perc`, `vllm:num_requests_waiting`, `llm_d_epp_plugin_duration_seconds`, TTFT and inter-token latency histograms.

## Adapting to other hardware

The router's saturation-aware override in `prefix-cache-affinity-filter` uses `peakPrefillThroughput`, which is hardware and model specific. The default (`15928`) matches the reference setup. For other GPUs or models, run the calibration recipe `guides/recipes/router/calibration/calibrate.sh` (a short Job that prints a value and changes nothing), then set the measured value in the values file. Without calibration, load can spread unevenly or affinity can be defeated.

## Optional: flow control

Flow control makes the EPP hold excess requests instead of pushing them to busy servers. Enable it through the `featureGates: [flowControl]` entry, a `concurrency-detector` plugin and a `flowControl` section in the `EndpointPickerConfig` of the values file (example in the guide). `maxConcurrency` is per endpoint, not per pool, and the sample value 8 is an example only.

## Cleanup

```bash
helm uninstall ${GUIDE_NAME} -n ${NAMESPACE}
kubectl delete -n ${NAMESPACE} -k ${REPO_ROOT}/guides/${GUIDE_NAME}/modelserver/${ACCELERATOR_TYPE}/${MODEL_SERVER}/${INFRA_PROVIDER}/
kubectl delete secret llm-d-hf-token -n ${NAMESPACE}
kubectl delete namespace ${NAMESPACE}
```

The GAIE CRDs are cluster-wide; remove them only when no other InferencePool user remains, and with approval. Scale down the GPU node pool afterwards.
