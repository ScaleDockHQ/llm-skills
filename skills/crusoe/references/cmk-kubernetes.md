# Crusoe: Managed Kubernetes (CMK)

> Verified against Crusoe Cloud docs (Crusoe Managed Kubernetes: create cluster, node pools, add-ons, kubeconfig, delete), 2026-10-11

Inconsistency to know: the CLI command reference page we read did not list a `kubernetes` subcommand, while the CMK docs use `crusoe kubernetes ...`. Run `crusoe kubernetes --help` first. If it is missing, upgrade the CLI or use the console (unverified: check https://docs.crusoecloud.com).

## Create

```bash
crusoe kubernetes clusters create --name "$CLUSTER" --location "$LOCATION" \
  --add-ons "nvidia_gpu_operator,nvidia_network_operator,crusoe_csi"
crusoe kubernetes nodepools create --name "$POOL" --cluster-id "$CLUSTER_ID" \
  --type "$TYPE" --count 1
crusoe kubernetes clusters get-credentials "$CLUSTER" --kubeconfig-path "$HOME/.kube/crusoe.yaml"
chmod 600 "$HOME/.kube/crusoe.yaml"
```

Flags shown beyond `--add-ons`, `--type`, `--count`, `--cluster-id` and `--kubeconfig-path` (such as `--name`, `--location`, version) must be checked with `--help` (unverified). The cluster has a management fee in addition to node costs; read it from the docs or console, do not assume.

Then `kubectl get nodes`, and deploy vLLM using `self-hosted-llms`.

## Delete

Delete all node pools before the cluster (see `teardown.md`).
