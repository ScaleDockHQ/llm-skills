# Install the Dynamo platform

> Verified against NVIDIA Dynamo v1.5.1 (chart dynamo-platform 1.5.1), Grove v0.1.0-alpha.13, KAI Scheduler v0.17.0, 2026-10-11

Dynamo is actively maintained (v1.5.1 chart and images, Apache-2.0 repo `ai-dynamo/dynamo`). Source: `docs/fern/pages/kubernetes/installation/` in the repo at tag v1.5.1.

## Prerequisites

- Kubernetes 1.30 or newer (chart `kubeVersion >=1.30.0-0`, because generated CRDs use validation ratcheting), `kubectl` 1.30+, Helm 3.
- GPU nodes with a driver that matches the runtime image. The TRT-LLM runtime listed in the docs matrix for 1.4.0 needs CUDA 13.1 and driver 580+; recheck the matrix for 1.5.1 in `docs/fern/pages/reference/general/compatibility.mdx`.
- NVIDIA GPU Operator unless your provider already manages drivers and the toolkit (the `nvidia-gpu-operator` skill).
- For multinode: Grove with KAI Scheduler, or LeaderWorkerSet with Volcano.
- For KV transfer in production: RDMA (`kv-transfer-and-networking.md`).
- Optional: kube-prometheus-stack for Planner `sla` mode and autoscaling.

## GPU Operator (skip if drivers and runtime exist)

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia --force-update
helm repo update nvidia
helm upgrade --install gpu-operator nvidia/gpu-operator --namespace gpu-operator --create-namespace --wait --timeout=10m
# provider-installed drivers: add --set driver.enabled=false
# provider also configures the container runtime: add --set toolkit.enabled=false
```

## Check for an existing operator first

Never run two cluster-wide Dynamo operators:

```bash
kubectl get clusterrolebinding -o json | jq -r '.items[] | select(.metadata.name | contains("dynamo-operator-manager")) | "Cluster-wide operator in namespace: \(.subjects[0].namespace)"'
kubectl get crd | grep -E 'dynamographdeployments|dynamocomponentdeployments|dynamographdeploymentrequests'
```

## Platform chart

The chart is served from NGC (`helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-<version>.tgz`; the URL answers with a redirect, so use `curl -L`). Version 1.5.1 downloads (HTTP 200 after redirect, 2026-10-11). The docs' install page still shows `RELEASE_VERSION=1.2.1` in an example; use 1.5.1.

```bash
export NAMESPACE=dynamo-system
export RELEASE_VERSION=1.5.1
helm fetch https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-${RELEASE_VERSION}.tgz
helm show values dynamo-platform-${RELEASE_VERSION}.tgz | less         # review before installing
helm install dynamo-platform dynamo-platform-${RELEASE_VERSION}.tgz \
  --namespace ${NAMESPACE} --create-namespace --wait --timeout=10m
kubectl get crd | grep dynamo
kubectl get pods -n ${NAMESPACE}        # dynamo-operator and nats pods Running
```

The chart bundles NATS (1.3.2) and etcd (12.0.18), and optional Grove, KAI Scheduler and Snapshot subcharts, all behind switches. Namespace-restricted mode (`namespaceRestriction.enabled=true`) is development only; set `dynamo-operator.upgradeCRD=false` if you use it. If Prometheus exists, add `--set "dynamo-operator.dynamo.metrics.prometheusEndpoint=http://<prometheus-service>.<ns>.svc.cluster.local:9090"` with your real address.

## Multinode orchestration

Dynamo returns a hard error for multinode deployments if neither Grove nor LWS is present.

**Option 1: Grove plus KAI Scheduler (default).**

- Managed by the chart (development and testing):

  ```bash
  helm upgrade --install dynamo-platform dynamo-platform-${RELEASE_VERSION}.tgz -n ${NAMESPACE} --create-namespace \
    --set "global.grove.install=true" --set "global.kai-scheduler.install=true" \
    --set-string "kai-scheduler.scheduler.args.default-staleness-grace-period=-1s"
  ```

- Already installed externally (production): `--set "global.grove.enabled=true" --set "global.kai-scheduler.enabled=true"`. Versions must satisfy the matrix: dynamo-platform 1.5.x needs KAI >= v0.17.0 and Grove >= v0.1.0-alpha.13.

**Option 2: LeaderWorkerSet plus Volcano** for gang scheduling:

```bash
helm repo add volcano-sh https://volcano-sh.github.io/helm-charts && helm repo update
helm install volcano volcano-sh/volcano -n volcano-system --create-namespace
helm install lws oci://registry.k8s.io/lws/charts/lws --version=0.8.0 -n lws-system --create-namespace \
  --set gangSchedulingManagement.schedulerProvider=volcano --wait --timeout 300s
```

LWS must be at least v0.7.0. Install both with the user's approval; they add cluster-scoped controllers.

## Model access Secret

The examples expect `hf-token-secret` with key `HF_TOKEN`. Public models can use an empty value; gated ones need a real token from a `0600` file:

```bash
umask 077
printf '%s' "$HF_TOKEN" > /tmp/hf-token
kubectl create secret generic hf-token-secret -n ${NAMESPACE} --from-file=HF_TOKEN=/tmp/hf-token --dry-run=client -o yaml | kubectl apply -f -
rm -f /tmp/hf-token
```

Deploy workloads in the same namespace as the Secret, or create it in the workload namespace.

## Model storage

Large models downloaded per pod take long and hit Hugging Face rate limits. Use shared storage or a pre-populated PVC (`docs/fern/pages/kubernetes/installation/model-storage` in the repo). Mount it through the pod template, never through host paths unless the user approves.

## Uninstall

```bash
kubectl delete dynamographdeployments --all -n <workload-namespace>        # first, with approval
helm uninstall dynamo-platform -n ${NAMESPACE}
kubectl delete namespace ${NAMESPACE}
```

CRDs may persist after `helm uninstall`; remove them only on a cluster you are retiring, after deleting every Dynamo resource.
