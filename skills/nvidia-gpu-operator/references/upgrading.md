# Upgrading, rolling back, uninstalling

> Verified against NVIDIA GPU Operator v26.7.1 (docs `upgrade`, `gpu-driver-upgrades`, `uninstall`), 2026-10-11

## Operator upgrade (Helm)

Helm does not upgrade existing CRDs, so either apply them first (option 1) or use the chart's pre-upgrade hook (option 2,
enabled by default since v24.9.0).

```bash
export RELEASE_TAG=v26.7.1        # target version
kubectl label --overwrite ns gpu-operator pod-security.kubernetes.io/enforce=privileged
# Option 1: apply CRDs manually (after approval)
B=https://raw.githubusercontent.com/NVIDIA/gpu-operator/refs/tags/$RELEASE_TAG/deployments/gpu-operator
kubectl apply -f $B/crds/nvidia.com_clusterpolicies.yaml -f $B/crds/nvidia.com_nvidiadrivers.yaml -f $B/crds/nvidia.com_gpuclusters.yaml
kubectl apply -f $B/charts/node-feature-discovery/crds/nfd-api-crds.yaml
# if you use the DRA driver (ComputeDomain), apply both, even when currently disabled:
kubectl apply -f $B/crds/resource.nvidia.com_computedomains.yaml -f $B/crds/resource.nvidia.com_computedomaincliques.yaml
helm repo update nvidia
helm show values nvidia/gpu-operator --version=$RELEASE_TAG > values-$RELEASE_TAG.yaml     # merge your changes
helm upgrade gpu-operator nvidia/gpu-operator -n gpu-operator -f values-$RELEASE_TAG.yaml --version $RELEASE_TAG
# Option 2: hook handles CRDs (needs --disable-openapi-validation); GPUCluster installs must still apply the ComputeDomain CRDs by hand
```

Upgrades are supported within a major release or to the next major only; skip no majors. ClusterPolicy can also be edited
live (`kubectl edit clusterpolicy`). If the operator image cannot be pulled, hooks fail; delete the chart with `--no-hooks`.
Rollback: `helm rollback gpu-operator <revision> -n gpu-operator`; CRDs stay at the new version.

## Driver rollout

The driver DaemonSet is special: nodes drain and reload the kernel module. Policy lives in `spec.upgradePolicy` of each
`NVIDIADriver` resource, or `spec.driver.upgradePolicy` in ClusterPolicy:

```yaml
upgradePolicy:
  autoUpgrade: true # default when omitted
  maxParallelUpgrades: 1
  maxUnavailable: 25%
  waitForCompletion: { timeoutSeconds: 0, podSelector: "" }
  podDeletion: { force: false, timeoutSeconds: 300, deleteEmptyDir: false }
  drain:
    {
      enable: false,
      force: false,
      podSelector: "",
      timeoutSeconds: 300,
      deleteEmptyDir: false,
    }
```

Per-node state label: `nvidia.com/gpu-driver-upgrade-state`.

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.nvidia\.com/gpu-driver-upgrade-state}{"\n"}{end}'
```

For LLM serving: the rollout evicts GPU pods on each node. Use `maxParallelUpgrades: 1`, enable `drain` so replicas move, and
keep at least two serving replicas per model (with a PodDisruptionBudget) so traffic continues.

## Uninstall

```bash
kubectl get gpucluster gpu-cluster 2>/dev/null; kubectl get resourceclaim -A       # GPUCluster/DRA users: delete workloads first
kubectl get nvidiadrivers; kubectl delete nvidiadriver <name>                       # optional, user-created ones
helm delete -n gpu-operator gpu-operator                                            # your release name
kubectl get pods -n gpu-operator
```

CRDs remain after `helm delete`. Install with `--set operator.cleanupCRD=true` to have a pre-delete hook remove them (it
removes `gpuclusters.nvidia.com` but not the two ComputeDomain CRDs). Deleting a CRD deletes all its resources: verify
nothing needs them. GPU workloads lose scheduling while the operands are gone, and drivers loaded by the driver container
unload with it.
