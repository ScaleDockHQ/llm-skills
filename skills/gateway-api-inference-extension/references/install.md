# Install: CRDs, gateway, router charts

> Verified against Gateway API Inference Extension v1.6.2 and llm-d router v0.11.0 (repo docs, chart README, llm-d `docs/api-reference/artifacts.md`), 2026-10-11

## Layers

1. **Gateway API CRDs** (`gateway.networking.k8s.io`), from kubernetes-sigs/gateway-api. The llm-d router deploy
   manifests pin `v1.5.1`.
2. **Inference Extension CRDs** (`InferencePool`, `InferencePoolImport`), from the GAIE release manifest.
3. **A gateway implementation** that supports InferencePool as a backend (or standalone mode).
4. **The router** (EPP plus an `InferencePool`): Helm chart from llm-d-router.
5. **Model servers** labelled to match the pool (`references/inferencepool-and-routes.md`).

## CRDs

```bash
# read-only: what is installed
kubectl get crd | grep -E 'inference.networking|gateway.networking'

# after approval (cluster-wide):
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.6.2/v1-manifests.yaml
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
```

The GAIE release assets include `v1-manifests.yaml` (the llm-d deploy kustomization points at
`.../releases/download/v1.5.0/v1-manifests.yaml`). Check the Gateway API release page for the exact asset name and
the version your gateway supports before applying. The router charts also expect `InferenceObjective` and
`InferenceModelRewrite` CRDs from llm-d-router when you use them (see the router `deploy/components` and its docs).

## Gateway implementations

At v1.6.2 the docs list: **Istio** (inference support tracked in an upstream issue), **Agentgateway**
(standalone binary, Docker or Kubernetes, also used inside llm-d), **NGINX Gateway Fabric**. The project README also
names Envoy Gateway, kgateway and GKE Gateway as gateways that can become inference gateways. Conformance listings expire without a
fresh report, so confirm support in the implementation's own docs and release notes. The llm-d chart exposes
`provider.name` with `none`, `gke` or `istio` to render provider-specific resources (health checks,
DestinationRule).

```bash
kubectl get gatewayclass                     # which implementations are installed
kubectl get gateway -A -o wide               # addresses and conditions
```

## Router charts (OCI, chart version `v0`)

| Mode       | Chart                                                | Use                                                                    |
| ---------- | ---------------------------------------------------- | ---------------------------------------------------------------------- |
| Gateway    | `oci://ghcr.io/llm-d/charts/llm-d-router-gateway`    | EPP + InferencePool behind an existing Gateway (production)            |
| Standalone | `oci://ghcr.io/llm-d/charts/llm-d-router-standalone` | EPP with a self-managed Envoy (default, sidecar) or agentgateway proxy |

```bash
helm show chart oci://ghcr.io/llm-d/charts/llm-d-router-gateway --version v0   # read-only
helm install <pool-name> oci://ghcr.io/llm-d/charts/llm-d-router-gateway --version v0 \
  --set router.modelServers.matchLabels.app=<pod-label-value> \
  --set router.epp.image.tag=v0.11.0
```

Images: `ghcr.io/llm-d/llm-d-router-endpoint-picker` (EPP) and `ghcr.io/llm-d/llm-d-router-disagg-sidecar`. The chart
default tag is `main` with `pullPolicy: Always`: pin an explicit release tag. The EPP image was renamed from
`llm-d-inference-scheduler` in llm-d v0.8.0 (the old package is removed). The docs state the charts are still
published from the GAIE project and will move to llm-d later, so confirm the coordinates against
`docs/api-reference/artifacts.md` in the llm-d repo when installing.

Useful values (all under `router.`): `modelServers.matchLabels`, `modelServers.type` (`vllm`, `sglang`,
`triton-tensorrt-llm`, `trtllm-serve`, `triton`), `modelServers.protocol` (`http`/`grpc`), `modelServers.targetPorts`,
`inferencePool.create` and `.failureMode` (`FailOpen` default in the chart), `epp.replicas`, `epp.flags`,
`epp.pluginsConfig`/`pluginsConfigFile`, `epp.resources`, `monitoring.prometheus.enabled`, `tracing.enabled`,
`inferenceObjectives`. Gateway chart extras: `provider.name`, `httpRoute.create`, `httpRoute.inferenceGatewayName`,
`httpRoute.requestTimeout` (300s). Read `values.yaml` of the chart version you install.

## Standalone mode

```bash
helm install my-router oci://ghcr.io/llm-d/charts/llm-d-router-standalone --version v0 \
  --set router.modelServers.matchLabels.app=my-vllm
# separate, scalable proxy Deployment that fails open if the EPP is unreachable:
#   --set router.inferencePool.create=false --set router.proxy.mode=service --set router.proxy.replicas=3
# agentgateway instead of Envoy:
#   --set router.inferencePool.create=false --set router.proxy.proxyType=agentgateway
```

Sidecar mode (default) suits tests; use `router.proxy.mode=service` to scale the proxy independently.

## Uninstall

`helm uninstall <pool-name>`; delete the `HTTPRoute`. Leave CRDs unless nothing uses them (deleting a CRD deletes every
resource of that kind).
