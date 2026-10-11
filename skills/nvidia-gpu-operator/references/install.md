# Install and verify

> Verified against NVIDIA GPU Operator v26.7.1 (docs `getting-started`, `platform-support`, `release-notes`, `troubleshooting`), 2026-10-11

## Platform fit (v26.7.x)

- Versioning is calendar based (YY.MM.PP). Status as read: 26.7.x supported, 26.3.x deprecated (critical fixes only),
  25.10.x and lower end of support. Upgrades: within a major release or to the next major.
- Kubernetes 1.33 to 1.37 on Ubuntu 22.04, 24.04, 26.04, RHEL 8/9/10 and Rocky (RKE2, K3s, k0s, MicroK8s, VKS and
  others in the support table); OpenShift 4.18 to 4.22 on RHCOS. Container runtimes: containerd 2.0 to 2.3, CRI-O
  (RHCOS is CRI-O only; Ubuntu 26.04 containerd only).
- GPUs: data center and workstation GPUs from Pascal to Blackwell (H100, H200, L4, L40S, A100, A10, T4, RTX PRO 6000
  Blackwell Server Edition, DGX B200/B300, GB200/GB300 NVL72, DGX Spark and DGX Station among them). Only **discrete**
  GPUs: Jetson and other integrated-GPU products are not supported (IGX Orin with its discrete GPU is).
  GH200 needs `driver.useOpenKernelModules=true`. RTX PRO 6000 Blackwell needs driver 575.57.08 or later and MIG is not
  supported on 575.57.08; HGX B200 needs a driver container 570.133.20 or later.
- All GPU nodes need the same OS version when the driver comes from ClusterPolicy; mixed OS needs the `NVIDIADriver` CRD.
- Driver component matrix v26.7.1: driver 595.91.07 (recommended and default), 580.173.02, 610.57.04, 615.71.09; Container
  Toolkit 1.20.1; Device Plugin 0.20.1; DCGM Exporter v4.6.1-4.8.4; MIG Manager 0.15.1; NFD v0.19.0;
  DRA Driver for NVIDIA GPUs v0.5.0. Read the matrix for your patch release.
- Network restricted environments are not supported on RHEL with the default driver container; there is an air-gapped guide.

## Prerequisites

```bash
kubectl create ns gpu-operator
kubectl label --overwrite ns gpu-operator pod-security.kubernetes.io/enforce=privileged
# Is NFD already deployed? If true, install with --set nfd.enabled=false
kubectl get nodes -o json | jq '.items[].metadata.labels | keys | any(startswith("feature.node.kubernetes.io"))'
```

Nodes need containerd or CRI-O. Disable automatic kernel upgrades (for example unattended-upgrades) on GPU nodes so
the driver container keeps matching the kernel.

## Install (pinned)

```bash
# OCI chart. Verify the signature first (needs cosign):
cosign verify --key https://api.ngc.nvidia.com/v2/catalog/containers/public-key --insecure-ignore-tlog \
  nvcr.io/nvidia/cloud-native-charts/gpu-operator:v26.7.1
helm install --wait gpu-operator -n gpu-operator --create-namespace \
  oci://nvcr.io/nvidia/cloud-native-charts/gpu-operator --version=v26.7.1

# Or the classic repo:
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
helm install --wait --generate-name -n gpu-operator --create-namespace nvidia/gpu-operator --version=v26.7.1
helm show values nvidia/gpu-operator --version=v26.7.1 | less        # every option
```

## Variants

| Situation                                          | Flags                                                                                                            |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Driver preinstalled on nodes                       | `--set driver.enabled=false`                                                                                     |
| Driver and Container Toolkit preinstalled (DGX OS) | `--set driver.enabled=false --set toolkit.enabled=false`; default runtime must be `nvidia`                       |
| Toolkit preinstalled, operator provides driver     | `--set toolkit.enabled=false`; set `root` in `/etc/nvidia-container-runtime/config.toml` to `/run/nvidia/driver` |
| NFD already running                                | `--set nfd.enabled=false`                                                                                        |
| Open kernel modules                                | `--set driver.useOpenKernelModules=true` (or `driver.kernelModuleType=open`; default `auto`)                     |
| Skip the driver on some nodes                      | `kubectl label node $NODE nvidia.com/gpu.deploy.driver=false`                                                    |
| MIG                                                | `--set mig.strategy=single` or `mixed` (`references/sharing-mig.md`)                                             |
| Time-slicing at install                            | `--set devicePlugin.config.name=<configmap>` (`references/sharing-mig.md`)                                       |
| Custom containerd paths (MicroK8s, others)         | `toolkit.env`: `CONTAINERD_CONFIG`, `CONTAINERD_SOCKET`, `RUNTIME_CONFIG_SOURCE`                                 |
| Pod-label dimensions on GPU metrics                | `--set dcgmExporter.enablePodLabels=true` (adds a ClusterRole; limit with `podLabelAllowlistRegex`)              |
| Let CRDs be removed on uninstall                   | `--set operator.cleanupCRD=true`                                                                                 |

Other values worth knowing: `cdi.enabled` (true), `cdi.nriPluginEnabled` (false, not GA), `dcgmExporter.enabled` (true),
`dcgmExporter.hostNetwork` (false), `clusterPolicy.deployCR` (true), `ccManager.enabled` (false),
`operator.leaderElection.renewDeadline` (v26.7.1). RHEL 8 with SELinux needs containerd `enable_selinux=true`.
For RKE2 and OpenShift follow their dedicated guides.

## Verify

```bash
kubectl get pods -n gpu-operator            # Running or Completed; nvidia-cuda-validator and operator-validator complete
kubectl get clusterpolicy                   # ready
kubectl get nodes -o json | jq '.items[] | select(.status.allocatable["nvidia.com/gpu"]!=null) | {name:.metadata.name,gpus:.status.allocatable["nvidia.com/gpu"]}'
kubectl apply -f templates/cuda-vectoradd.yaml && kubectl logs pod/cuda-vectoradd && kubectl delete -f templates/cuda-vectoradd.yaml
kubectl get node <gpu-node> --show-labels | tr ',' '\n' | grep nvidia.com | head -20
```

Expected pods per GPU node: `nvidia-driver-daemonset`, `nvidia-container-toolkit-daemonset`,
`nvidia-device-plugin-daemonset`, `nvidia-dcgm-exporter`, `gpu-feature-discovery`, `nvidia-operator-validator`, plus
cluster-wide `gpu-operator` and NFD pods. For model servers see `references/combos/vllm-on-gpu-operator.md`.

## NVIDIADriver CRD (per-pool drivers)

Use `NVIDIADriver` resources (`nvidia.com/v1alpha1`) to run different driver versions or settings per node pool
(`templates/nvidiadriver.yaml`); then ClusterPolicy no longer needs to own the driver pods for those nodes.

## Sources

https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/26.7/getting-started.html, https://github.com/NVIDIA/gpu-operator
