# Sharing GPUs: time-slicing and MIG

> Verified against NVIDIA GPU Operator v26.7.1 (docs `gpu-sharing`, `gpu-operator-mig`), 2026-10-11

For LLMs: whole GPUs are the default and the safe choice for large models. Share only small models, embedding or
reranker servers and dev workloads.

## Time-slicing (no isolation)

Replicas of a GPU are handed out to different pods, which interleave on the device. There is no memory or fault
isolation, requesting several replicas does not give proportional compute, and every pod can start any number of
processes. A model that needs most of the GPU memory cannot share with another.

```yaml
# templates/time-slicing-config.yaml (ConfigMap in the operator namespace)
apiVersion: v1
kind: ConfigMap
metadata: { name: time-slicing-config, namespace: gpu-operator }
data:
  any: |-
    version: v1
    flags: { migStrategy: none }
    sharing:
      timeSlicing:
        renameByDefault: false
        failRequestsGreaterThanOne: true
        resources:
          - { name: nvidia.com/gpu, replicas: 4 }
```

```bash
kubectl apply -f templates/time-slicing-config.yaml
kubectl patch clusterpolicies.nvidia.com/cluster-policy -n gpu-operator --type merge \
  -p '{"spec":{"devicePlugin":{"config":{"name":"time-slicing-config"}}}}'
# a spec without devicePlugin.config.default does not apply to all nodes: label nodes (named configs):
kubectl label node <node> nvidia.com/device-plugin.config=any
kubectl get node <node> -o jsonpath='{.status.allocatable.nvidia\.com/gpu}{"\n"}'   # 4 per physical GPU
```

- Named keys in the ConfigMap allow node-specific configs (for example `tesla-t4`), selected by the node label
  `nvidia.com/device-plugin.config=<key>`.
- Labels after enabling: `nvidia.com/gpu.replicas=<n>` and product `<product>-SHARED` (with `renameByDefault: false`);
  with `renameByDefault: true` the resource is advertised as `nvidia.com/gpu.shared`.
- Only `nvidia.com/gpu` and MIG resources from the mixed strategy can be time-sliced. The operator does not watch the
  ConfigMap: restart the device plugin and GFD pods after editing.
- DCGM exporter cannot attribute metrics to containers with time-slicing enabled.
- Enabling it at install: `--set devicePlugin.config.name=time-slicing-config`.

## MIG (hardware isolation)

MIG Manager partitions supported GPUs (A100, A30, H100, H200, and later) into instances with isolated memory and compute.

```bash
helm upgrade gpu-operator ... --set mig.strategy=single      # or mixed; chosen at install/upgrade
kubectl patch clusterpolicy/cluster-policy --type='json' -p='[{"op":"replace","path":"/spec/mig/strategy","value":"single"}]'
kubectl label nodes <node> nvidia.com/mig.config=all-1g.10gb --overwrite   # apply a profile (drains GPU pods on the node)
kubectl get node <node> -o json | jq '.metadata.labels | with_entries(select(.key|startswith("nvidia.com/mig")))'
```

- Strategies: `single` (all GPUs on a node use one profile; resource stays `nvidia.com/gpu`), `mixed` (several
  profiles; resources like `nvidia.com/mig-1g.10gb`), `none`.
- Nodes carry `nvidia.com/mig.config` (default `all-disabled`) and `nvidia.com/mig.config.state` (`pending`, `success`, `failed`).
- Since v26.3.0 MIG Manager generates the config at runtime into a ConfigMap `<node-name>-mig-config` (all-disabled,
  all-enabled, per-profile, all-balanced). Older drivers (535 branch) fall back to a static ConfigMap; custom profiles use
  a custom MIG config.
- Some platforms need a reboot to enable MIG: `--set migManager.env[0].name=WITH_REBOOT --set-string migManager.env[0].value=true`.
- MIG is not supported on RTX PRO 6000 Blackwell with driver 575.57.08.
- vLLM on a MIG slice: the model must fit the slice memory; one process per instance. Time-slicing can be layered on MIG resources.

## Choosing

| Need                                        | Use                                      |
| ------------------------------------------- | ---------------------------------------- |
| One big model per GPU or tensor parallel    | whole GPUs, no sharing                   |
| Several small models, trusted tenants       | time-slicing                             |
| Isolation, predictable latency per tenant   | MIG                                      |
| Per-process CUDA memory caps (R615+ driver) | `NVIDIA_GPU_MEMORY_LIMIT` (MiB), v26.7.1 |
