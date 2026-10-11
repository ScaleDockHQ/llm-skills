# Installing AIBrix

> Verified against AIBrix v0.7.0 (docs, samples, chart, release assets), 2026-10-11

AIBrix (vllm-project/aibrix) v0.7.0 was published 2026-06-18; the repository was active in October 2026 and not
archived. It runs on vanilla Kubernetes and requires **Envoy Gateway** for routing. KubeRay is optional: only
needed for Ray fleets (`RayClusterFleet`); `StormService` covers single- and multi-node without it.

## Release manifests (recommended)

```bash
V=v0.7.0
BASE=https://github.com/vllm-project/aibrix/releases/download/$V
kubectl apply -f $BASE/aibrix-dependency-$V.yaml --server-side     # Envoy Gateway and other dependencies; list its contents with `kubectl apply --dry-run=server` first
kubectl apply -f $BASE/aibrix-core-crds-$V.yaml --server-side      # CRDs kept separate from the operator
kubectl apply -f $BASE/aibrix-core-$V.yaml
kubectl get pods -n aibrix-system -w
```

Release assets are exactly these three files. Expected pods in `aibrix-system`: `aibrix-controller-manager`,
`aibrix-gateway-plugins`, `aibrix-gpu-optimizer`, `aibrix-metadata-service`, `aibrix-redis-master` (and a KubeRay
operator when included). Envoy runs in `envoy-gateway-system`.

## Helm (from a repo checkout)

```bash
git clone --branch v0.7.0 --depth 1 https://github.com/vllm-project/aibrix && cd aibrix
# prerequisite: Envoy Gateway with EnvoyPatchPolicy enabled (extensionApis.enableEnvoyPatchPolicy: true)
kubectl apply -f dist/chart/crds/
helm install aibrix dist/chart -f dist/chart/stable.yaml -n aibrix-system --create-namespace
```

The docs install Envoy Gateway with `helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.2.8 -n
envoy-gateway-system --create-namespace` and patch the `envoy-gateway-config` ConfigMap to enable
`EnvoyPatchPolicy` ("super important"). The release dependency manifest is the documented path; use Helm only when you
manage Envoy Gateway yourself. `dist/chart/stable.yaml` pins controller and gateway images to `v0.7.0`.

## Controllers

The controller manager runs: `pod-autoscaler-controller`, `distributed-inference-controller` (needs KubeRay,
skipped otherwise), `model-adapter-controller`, `kv-cache-controller`, `stormservice-controller`. Select with
`--controllers=*,-distributed-inference-controller`. Individual components: `kubectl apply -k config/standalone/<name>/`
from a checkout (for example `autoscaler-controller`, `model-adapter-controller`, `kv-cache-controller`).

## Custom resource groups

`autoscaling.aibrix.ai` (`PodAutoscaler`), `model.aibrix.ai` (`ModelAdapter`), `orchestration.aibrix.ai`
(`StormService`, `RoleSet`, `PodSet`, `KVCache`, `RayClusterFleet`, `RayClusterReplicaSet`).

## Platform notes

Guides in the repo: AWS, GCP, Lambda, local mode, Mac desktop, Volcano Engine (VKE). Some samples carry
registry-specific annotations (for example VKE RDMA pod networks); strip them on other clouds.

## Verify and uninstall

```bash
kubectl get pods -n aibrix-system
kubectl get svc -n envoy-gateway-system
kubectl get gateway,httproute -A
```

Uninstall in reverse: delete your models and custom resources first, then the `aibrix-core` manifest, then the CRDs
(deleting CRDs deletes every custom resource), then the dependency manifest. For Helm: `helm uninstall aibrix -n aibrix-system`.

## Sources

- <https://github.com/vllm-project/aibrix/releases/tag/v0.7.0>
- <https://aibrix.readthedocs.io/latest/getting_started/installation/installation.html>
