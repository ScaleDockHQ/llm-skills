# CoreWeave: CKS clusters, Node Pools and SUNK

> Verified against CoreWeave docs: Introduction to CKS, Create a CKS cluster, Create a Node Pool, Manage Node Pools, Spot Node Pools, Deploy an open source LLM on CKS, Delete a CKS cluster, About SUNK, 2026-10-11

CKS runs Kubernetes directly on bare-metal GPU nodes (no hypervisor), each cluster in its own VPC, with stateless nodes that load a clean OS image at boot. CoreWeave manages the control plane, CSI, CNI and the NVIDIA GPU Operator.

**Do not install the NVIDIA GPU Operator on CKS.** It conflicts with the platform-managed one.

## Create a cluster (billable; Node Pools carry the GPU cost)

Console: Compute, Clusters, Create a Cluster. Choose a name, Kubernetes version, whether to expose the API over the internet, a region where you have GPU quota, and a default VPC. Authentication options are optional. Terraform (`coreweave/coreweave` provider, `COREWEAVE_API_TOKEN`) is also supported. The cluster is usable when its status is `Healthy`.

## Node Pool

A Node Pool is a custom resource that defines how many nodes of which instance type the cluster gets.

```yaml
apiVersion: compute.coreweave.com/v1alpha1
kind: NodePool
metadata:
  name: llm-pool
spec:
  computeClass: default # or spot
  autoscaling: false
  instanceType: <instance-type-from-docs-or-console>
  targetNodes: 1
```

```bash
kubectl apply -f nodepool.yaml
kubectl get nodepool llm-pool        # watch CURRENT, VALIDATED, CAPACITY, QUOTA columns
kubectl describe nodepool llm-pool   # events such as CWOverQuota
```

- A new node can take up to 15 minutes to boot. Pool status becomes `Healthy` when ready.
- Quota is checked on every `targetNodes` change; if over quota the pool fills only up to the limit and `kubectl describe nodepool` shows `CWOverQuota` (`QUOTA` column `Over`). Rack-based types (GB200, GB300) use `targetRacks` (18 nodes per rack) and do not support autoscaling.
- Autoscaling: `autoscaling: true` with `minNodes` and `maxNodes`.
- Labels and taints use your own namespaces; `coreweave.cloud` and `coreweave.com` label keys are dropped (`CWNodePoolMetadataSanitized`).
- Instance type names and prices: read the Instances page in the docs and the console; do not hardcode.

## Spot Node Pools

`computeClass: spot` gives preemptible pay-as-you-go capacity. CoreWeave may reclaim nodes with up to a seven-minute graceful window. If all nodes are preempted the pool stays and your pods wait in Pending. Use for batch or replicas with fallbacks, not as the only replica.

## Serve a model on CKS

The official tutorial deploys Llama 3.1 8B with vLLM and Open WebUI. Core steps:

```bash
kubectl create secret generic hf-token-secret --from-literal=api_token="$HF_TOKEN"   # from env, never typed on the command line history
kubectl apply -f https://raw.githubusercontent.com/coreweave/doc-examples/refs/heads/main/cks/llm-on-cks.yaml
kubectl get pods
kubectl logs <llama-pod>     # look for "Application startup complete."
```

Read the manifest before applying: it requests `nvidia.com/gpu: 1`, mounts a 2Gi `/dev/shm`, uses CoreWeave's `vllm-tensorizer` image and exposes `ClusterIP` services only. Set `MODEL` to change the model; raise `TENSOR_PARALLEL_SIZE` and the GPU request together for larger models. The sample sets `WEBUI_AUTH=false`: do not expose Open WebUI publicly without authentication. For a public Service set `type: LoadBalancer` with `service.beta.kubernetes.io/coreweave-load-balancer-type: public` only after adding auth and a source allow-list. Test in-cluster with a temporary curl pod, or `kubectl port-forward`. Pin the vLLM image tag, and use `self-hosted-llms` for engine flags, `llm-d` and production-stack patterns.

CoreWeave also documents tutorials for NVIDIA Dynamo on CKS and a vLLM inference deploy.

## SUNK (Slurm on Kubernetes)

SUNK runs Slurm nodes as Kubernetes Pods on CKS, one Slurm node per Kubernetes node, so batch Slurm jobs and Kubernetes services share the same GPUs. Two modes: SUNK Self-Service (CoreWeave runs the cluster from a single `SunkCluster` resource; needs SUNK 8.0 or later and is recommended for new clusters) and SUNK Standard (you deploy the `sunk` and `slurm` Helm charts, usually through ArgoCD). Use it for training and batch evals, not for low-latency serving. See https://docs.coreweave.com/products/sunk and the SUNK 8.0 release note before configuring; key names changed between versions.

## Sources

- https://docs.coreweave.com/products/cks
- https://docs.coreweave.com/products/cks/clusters/create
- https://docs.coreweave.com/products/cks/nodes/create
- https://docs.coreweave.com/platform/capacity-plans/spot-node-pools
- https://docs.coreweave.com/products/cks/deploy-model
- https://docs.coreweave.com/products/sunk
