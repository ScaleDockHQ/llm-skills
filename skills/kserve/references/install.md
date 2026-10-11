# Installing KServe and LLMInferenceService

> Verified against KServe v0.21.0 (website install, dependencies and quickstart docs; release assets; ghcr chart tags), 2026-10-11

Kubernetes 1.32 or newer is required by the quickstart. Helm 3.8+ is required since v0.17.0.

## What to install

| Goal                                      | Components                                           |
| ----------------------------------------- | ---------------------------------------------------- |
| Predictive models only                    | `kserve` (Standard or Knative mode)                  |
| LLMs and generative AI (most users)       | `kserve` plus `llmisvc`, or `llmisvc` alone          |
| Faster cold starts for `InferenceService` | add `localmodel` (not yet for `LLMInferenceService`) |

Controllers: `kserve-controller-manager`, `llmisvc-controller-manager`, `kserve-localmodel-controller` (plus the
`kserve-localmodelnode-agent` DaemonSet). Shared: cert-manager webhook certificates, the `inferenceservice-config`
ConfigMap, `ClusterStorageContainer` objects.

## Dependencies by mode

| Mode                      | Needs                                                                                                                                                                                                |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Standard (raw Deployment) | cert-manager (v1.17.0+ per docs); the repo pins v1.17.0                                                                                                                                              |
| Knative (serverless)      | cert-manager, Istio, Knative Operator and Serving                                                                                                                                                    |
| LLMInferenceService       | cert-manager, Gateway API CRDs plus Inference Extension CRDs, Envoy Gateway, Envoy AI Gateway, a `GatewayClass` and `Gateway`, LeaderWorkerSet operator, an external load balancer on local clusters |
| KEDA autoscaling          | KEDA (Standard mode only for `InferenceService`), optional OpenTelemetry operator and the KEDA OTEL add-on                                                                                           |

Versions pinned by the v0.21.0 repo (`kserve-deps.env`): Envoy Gateway v1.8.1, Envoy AI Gateway v1.1.0,
cert-manager v1.17.0, Istio 1.27.1, Knative Serving 1.21.1. Do not install different majors without checking
the compatibility notes.

## Chart tags (check before you copy a command)

At verification time the OCI charts under `oci://ghcr.io/kserve/charts/` had tags `v0.20.0`, `v0.21.0-rc0` and
`v0.21.0-rc1`, with no plain `v0.21.0` chart tag, while images `kserve/llmisvc-controller:v0.21.0` and
`kserve/kserve-controller:v0.21.0` exist and the docs still show `v0.20.0` in commands. Check the live tags
before pinning:

```bash
T=$(curl -s "https://ghcr.io/token?scope=repository:kserve/charts/kserve-llmisvc-resources:pull" | jq -r .token)
curl -s -H "Authorization: Bearer $T" https://ghcr.io/v2/kserve/charts/kserve-llmisvc-resources/tags/list | jq -c .tags
```

Choose one: a chart tag that exists (pin it and read what image tag it deploys, `kserve.version` in its values),
or the release's own scripts and manifests (the release `v0.21.0` publishes `*-install-with-manifests.sh`,
`kserve.yaml` and `kserve-crds.yaml` assets).

## Method 1: quick-install script (LLMs, fastest)

```bash
# Review the script before piping it to bash; it installs cluster-wide dependencies.
curl -fsSL https://github.com/kserve/kserve/releases/download/v0.21.0/llmisvc-full-install-with-manifests.sh -o llmisvc-install.sh
less llmisvc-install.sh
bash llmisvc-install.sh
```

Release assets for v0.21.0 include `llmisvc-dependency-install.sh`, `llmisvc-full-install-with-manifests.sh`,
`kserve-standard-mode-full-install-with-manifests.sh`, `kserve-knative-mode-full-install-with-manifests.sh`,
`localmodel-full-install-with-manifests.sh`, `keda-dependency-install.sh` and
`llmisvc-autoscaling-{hpa,keda}-dependency-install.sh`. Uninstall with the same script's uninstall path or the
Helm/kustomize commands below.

## Method 2: Helm (per component, CRDs first)

```bash
V=<chart tag that exists, from the check above>
helm install kserve-llmisvc-crd oci://ghcr.io/kserve/charts/kserve-llmisvc-crd \
  --version "$V" -n kserve --create-namespace
helm install kserve-llmisvc-resources oci://ghcr.io/kserve/charts/kserve-llmisvc-resources \
  --version "$V" -n kserve --create-namespace --wait
# Config templates (LLMInferenceServiceConfig presets)
helm install kserve-runtime-configs oci://ghcr.io/kserve/charts/kserve-runtime-configs \
  --version "$V" -n kserve --set kserve.llmisvcConfigs.enabled=true
```

Adding llmisvc to an existing KServe install: set `--set kserve.createSharedResources=false` on
`kserve-llmisvc-resources`. Predictive stack: `kserve-crd` then `kserve-resources` (`kserve-crd-minimal` is a
smaller CRD variant without full validation). `kserve-localmodel-crd` and `kserve-localmodel-resources` add the cache.

## Method 3: kustomize from a clone

```bash
git clone --depth 1 --branch v0.21.0 https://github.com/kserve/kserve.git && cd kserve
kubectl apply --server-side -k config/overlays/standalone/llmisvc   # llmisvc with shared base
kubectl apply --server-side -k config/overlays/addons/llmisvc       # llmisvc when KServe is installed
kubectl apply -k config/llmisvcconfig                               # preset configs
```

`overlays/all` installs base plus kserve, llmisvc and localmodel. `hack/kserve-install.sh` wraps both modes:
`./hack/kserve-install.sh --kserve-version <v> --type kserve,llmisvc,localmodel --standard`
(`--kustomize` for the manifest path, `--knative` for serverless).

## Deployment mode for InferenceService

The `deploy` key in the `inferenceservice-config` ConfigMap sets the default (`Standard` or `Knative`); override
per object with the annotation `serving.kserve.io/deploymentMode: Standard`. Multi-node and KEDA need Standard.

## Verify

```bash
kubectl get pods -n kserve
kubectl get crd | grep -E 'llminferenceservice|inferenceservice'
kubectl get llminferenceserviceconfig -n kserve
kubectl get gatewayclass,gateway -A
kubectl get inferencepool -A 2>/dev/null
```

Wait for `llmisvc-controller-manager` and `kserve-controller-manager` (when installed) to be `Running`.

## Uninstall

```bash
helm uninstall kserve-runtime-configs kserve-llmisvc-resources kserve-llmisvc-crd -n kserve
# Removing CRDs deletes every LLMInferenceService in the cluster; confirm first.
```

## Sources

- <https://kserve.github.io/website/docs/install/overview>, `.../install/dependencies`, `.../install/llmisvc-install`
- <https://kserve.github.io/website/docs/getting-started/quickstart-guide>
- <https://github.com/kserve/kserve/releases/tag/v0.21.0>
