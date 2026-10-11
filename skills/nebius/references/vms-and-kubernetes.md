# Nebius: GPU VMs and Managed Kubernetes

> Verified against Nebius AI Cloud docs (CLI reference compute instance, mk8s cluster and node-group, quotas, VM stop and start, capacity reservations), 2026-10-11

## Before creating anything

```bash
nebius compute platform list --parent-id "$PROJECT_ID"          # platforms and presets
nebius quotas quota-allowance list --parent-id "$PROJECT_ID"    # quotas and limits
nebius vpc subnet list --parent-id "$PROJECT_ID"                # subnets
nebius compute instance list                                    # what already bills
```

Quotas count a VM from creation to deletion, running or stopped. GPU and non-GPU VMs have separate quotas, and quotas apply to mk8s and Soperator nodes too. Increases go through your Nebius manager or support. Defaults and platform names change by region: read https://docs.nebius.com/compute/resources/quotas-limits.

## VM

Required flags for `nebius compute instance create`: `--boot-disk-attach-mode`, `--network-interfaces`, `--parent-id`, `--resources-platform`, `--resources-preset`. Build the boot disk and cloud-init (SSH key) as in https://docs.nebius.com/compute/virtual-machines/manage; flag syntax for disks and networks is not reproduced here (unverified: copy the current example).

```bash
nebius compute instance get --id "$VM_ID"
nebius compute instance stop --id "$VM_ID"      # stop
nebius compute instance start --id "$VM_ID"
nebius compute instance delete --id "$VM_ID"   # also deletes managed disks declared in the spec
```

Stopping does not free quota. Standalone disks outlive the VM unless managed: check `nebius compute disk list`, delete with `nebius compute disk delete --id`. Whether a stopped VM still bills is documented in the billing pages: check https://docs.nebius.com/compute/resources/pricing before promising anything.

Reservations: capacity block groups are arranged through your manager; reserved GPUs stay yours while VMs are stopped. Use `--reservation-policy-reservation-ids` to pin specific reservations.

After SSH, serve with vLLM as in `self-hosted-llms`.

## Managed Kubernetes (mk8s)

```bash
nebius mk8s cluster create --control-plane-subnet-id "$SUBNET_ID" --control-plane-version "$K8S_VERSION" --parent-id "$PROJECT_ID"
nebius mk8s node-group create --parent-id "$CLUSTER_ID" \
  --template-resources-platform "$PLATFORM" --template-resources-preset "$PRESET" \
  --template-gpu-settings-drivers-preset "$DRIVER_PRESET" --fixed-node-count 1
nebius mk8s cluster get-credentials --id "$CLUSTER_ID" --external   # writes kubeconfig
```

Required flags only; add a name and other options (network settings, auto-scaling) are in the CLI reference; check `nebius mk8s node-group create --help` before use. The driver preset must match the GPU platform: look it up in https://docs.nebius.com/kubernetes (unverified exact values). Then deploy vLLM from `self-hosted-llms`.

Cleanup: see `teardown.md`.
