---
name: nvidia-gpu-operator
description: Install and run the NVIDIA GPU Operator (Helm, ClusterPolicy, NVIDIADriver) so Kubernetes nodes expose nvidia.com/gpu for LLM pods, covering the driver, container toolkit, device plugin, DCGM exporter, MIG Manager, GPU Feature Discovery, time-slicing, CDI, driver upgrades, uninstall. Use for GPU nodes not schedulable, pods stuck in Init, no runtime for nvidia, missing GPUs, Xid errors, sharing a GPU between vLLM pods. Not for DCGM metrics only (dcgm-exporter), the workloads (vllm, ray-serve), or autoscaling (keda).
license: MIT
compatibility: Kubernetes with containerd 2.x or CRI-O on NVIDIA data center GPUs (x86 and ARM), kubectl, helm, bash, jq. Installing it modifies nodes (drivers, runtime config) and cluster CRDs, so it needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA GPU Operator

Gets Kubernetes GPU nodes ready for LLM serving: the operator deploys the driver, container toolkit, device plugin,
GPU Feature Discovery and DCGM exporter as DaemonSets so pods can request `nvidia.com/gpu`. Verified against GPU
Operator v26.7.1 (2026-10-11).

**Scope:** the operator and its operands on a Kubernetes cluster, plus the settings that matter for LLM workloads
(sharing, MIG, metrics, upgrades). The workloads (`vllm`, `ray-serve`), GPU metrics queries (`dcgm-exporter`),
routing (`gateway-api-inference-extension`) and pod autoscaling (`keda`) are sibling skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print secrets.

```bash
kubectl get nodes -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu,PRODUCT:.metadata.labels.nvidia\\.com/gpu\\.product
kubectl get pods -n gpu-operator 2>/dev/null; kubectl get clusterpolicy 2>/dev/null
helm list -A | grep -i gpu-operator
kubectl get nodes -o json | jq '.items[].metadata.labels | keys | any(startswith("feature.node.kubernetes.io"))'   # is NFD already running?
kubectl get runtimeclass; kubectl get ns gpu-operator --show-labels 2>/dev/null
# On a node (SSH): driver, runtime
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv 2>/dev/null
containerd --version 2>/dev/null; crio --version 2>/dev/null; ls /etc/nvidia-container-runtime 2>/dev/null
lsmod | grep -E '^(nvidia|nouveau)' ; uname -r; cat /etc/os-release | head -3
```

## Decision flow

1. **Already have working GPU scheduling?** (`nvidia.com/gpu` allocatable on nodes, pods run `nvidia-smi`.) Do not
   install the operator; use it only for features you need. If another stack manages the driver (cloud image,
   DGX OS, Talos, Bottlerocket), install with `driver.enabled=false` (and `toolkit.enabled=false` where the
   toolkit is preinstalled): `references/install.md`.
2. **Check platform fit** (supported GPUs, OS, Kubernetes, runtimes): `references/install.md`.
3. **Pick driver ownership**: operator-managed driver container (default, all GPU nodes must share an OS version
   with ClusterPolicy; per-pool versions need the `NVIDIADriver` CRD), or host-installed driver.
4. **Install** pinned to a chart version, in namespace `gpu-operator` labelled for Pod Security `privileged`;
   disable NFD if the cluster already runs it.
5. **Verify**: all pods Running or Completed, ClusterPolicy `ready`, `nvidia.com/gpu` allocatable, a CUDA test
   pod; then a vLLM pod (`references/install.md`).
6. **Share or partition GPUs?** Time-slicing (no isolation) or MIG (hardware isolation):
   `references/sharing-mig.md`.
7. **Metrics**: DCGM exporter is on by default; scrape and use it: `references/observability.md`.
8. **Upgrade** (CRDs first, driver rollout policy): `references/upgrading.md`. **Uninstall**: same file.
9. **Broken**: `references/troubleshooting.md`.

## Quick start

```bash
# After approval. Verified for v26.7.1 (OCI chart; verify the signature with cosign first, see references/install.md).
kubectl create ns gpu-operator
kubectl label --overwrite ns gpu-operator pod-security.kubernetes.io/enforce=privileged
helm install --wait gpu-operator -n gpu-operator \
  oci://nvcr.io/nvidia/cloud-native-charts/gpu-operator --version=v26.7.1
kubectl get pods -n gpu-operator
kubectl get clusterpolicy
kubectl get nodes -o json | jq '.items[] | select(.status.allocatable["nvidia.com/gpu"]!=null) | {name:.metadata.name,gpus:.status.allocatable["nvidia.com/gpu"]}'
kubectl apply -f templates/cuda-vectoradd.yaml && kubectl logs pod/cuda-vectoradd   # expects "Test PASSED"
```

## Rules

- **Ask before changing the system.** The operator installs kernel drivers, edits container runtime config and
  restarts runtimes on GPU nodes. Say which nodes, and the undo path (`references/upgrading.md`, uninstall).
- **Secrets never touch output.** NGC and registry pull secrets, vGPU license tokens and cosign keys live in
  Secrets or files with mode `0600`.
- **Pin the chart version** (`--version=v26.7.1`); never install unpinned. Upgrades are supported only within a
  major release or to the next major.
- **CRDs are not upgraded by Helm automatically.** Follow `references/upgrading.md`.
- **Same OS on GPU nodes** when the operator manages the driver through ClusterPolicy; mixed OS needs `NVIDIADriver`.
- **One GPU manager per node.** Do not run a host-installed device plugin or a second operator alongside it.
- **Namespace must be `privileged`** under Pod Security Admission.
- **Time-slicing has no memory or fault isolation.** Do not use it to run untrusted tenants; use MIG.

## Facts that surprise people (v26.7.1)

- A default install deploys the driver, container toolkit, device plugin, DCGM exporter and MIG Manager on every GPU
  node, plus NFD and GPU Feature Discovery. `driver.enabled=false` for preinstalled drivers.
- CDI is on by default (`cdi.enabled=true`): GPUs are injected through native CDI in containerd or CRI-O and the
  `nvidia` runtime class is no longer the default handler. The NRI plugin (`cdi.nriPluginEnabled`) is not GA.
- Operand pods start only after the driver daemonset and toolkit are healthy: "stuck in Init" almost always means
  the driver pod.
- Time-slicing requests do not scale: asking for 2 replicas does not give 2x compute. Set
  `failRequestsGreaterThanOne: true` to make that explicit.
- The operator does not watch the time-slicing ConfigMap; restart the device plugin after editing it.
- DCGM exporter cannot attribute metrics to containers when time-slicing is enabled.
- v26.7.1 added soft and hard per-GPU CUDA memory limits through `NVIDIA_GPU_MEMORY_REQUEST` and
  `NVIDIA_GPU_MEMORY_LIMIT` (MiB; needs an R615 or later driver).
- Release support status as read: 26.7.x supported, 26.3.x deprecated (patches only), 25.10.x and lower end of support.
- The driver default for v26.7.1 is 595.91.07 (recommended), with 580.173.02, 610.57.04 and 615.71.09 also listed.

## Workflows

### Prepare a cluster for LLM serving

- [ ] Discovery; decide driver ownership; check node OS and runtime (`references/install.md`).
- [ ] Install the chart pinned, with the options for your platform.
- [ ] Verify pods, ClusterPolicy, allocatable GPUs, a CUDA sample.
- [ ] Deploy a model server with `resources.limits."nvidia.com/gpu"` (skills `vllm`, `ray-serve`).
- [ ] Scrape DCGM metrics (`references/observability.md`).

### Share one GPU between small models

- [ ] Choose time-slicing (replicas) or MIG (profiles): `references/sharing-mig.md`.
- [ ] Apply the ConfigMap or label, restart the plugin, check the new allocatable count and labels.

### Upgrade the operator or drivers

- [ ] `references/upgrading.md`: CRDs, `helm upgrade`, driver rollout policy (`maxUnavailable`, drain).

### Debug a failure

- [ ] `kubectl get pods -n gpu-operator`, driver pod logs, `dmesg | grep -i -E 'NVRM|Xid'`, then
      `references/troubleshooting.md`. For a bug report run upstream's `hack/must-gather.sh`.

## Reference index

- `references/install.md`: platform fit, install variants (OCI, repo, preinstalled driver/toolkit), values, verification.
- `references/sharing-mig.md`: time-slicing ConfigMaps, MIG strategies and profiles, node labels.
- `references/observability.md`: DCGM exporter metrics, ServiceMonitor, LLM-relevant queries, `nvidia.com/gpu` capacity.
- `references/upgrading.md`: operator and driver upgrades, rollback, uninstall.
- `references/troubleshooting.md`: symptom to cause to fix.
- `references/combos/vllm-on-gpu-operator.md`: scheduling vLLM on operator-managed nodes.
- `references/combos/keda-dcgm.md`: DCGM metrics as KEDA triggers.
- `templates/`: `cuda-vectoradd.yaml`, `time-slicing-config.yaml`, `values-llm.yaml`, `nvidiadriver.yaml`.

## Companion skills

- `vllm`: the workload. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `ray-serve`: Ray Serve LLM and KubeRay on GPU nodes. Install: `npx skills add ScaleDockHQ/llm-skills --skill ray-serve`.
- `dcgm-exporter`: GPU metrics in depth. Install: `npx skills add ScaleDockHQ/llm-skills --skill dcgm-exporter`.
- `keda`: scale model pods on queue and GPU metrics. Install: `npx skills add ScaleDockHQ/llm-skills --skill keda`.
- `gateway-api-inference-extension`: route to the pods. Install: `npx skills add ScaleDockHQ/llm-skills --skill gateway-api-inference-extension`.
- `choosing-hardware`: pick GPUs and sizing. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
- `nvidia-dgx-spark`: single-node DGX Spark setup (not Kubernetes). Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`.
