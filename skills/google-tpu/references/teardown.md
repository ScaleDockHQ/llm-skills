# Teardown

> Verified against Google Cloud docs (Manage TPU resources, Queued resources, GKE TPU how-to), 2026-10-11

Ask before deleting anything the user did not create in this session. Deletion is permanent.

## 1. Find what exists

```bash
gcloud compute instances list --filter='machineType~ct6e OR machineType~ct5' --format='table(name,zone,machineType.basename(),status)'
gcloud compute tpus tpu-vm list --zone "$ZONE"
gcloud compute tpus queued-resources list --zone "$ZONE"
gcloud container node-pools list --cluster "$CLUSTER" --zone "$ZONE" 2>&1 | head
kubectl get pods -A -o wide 2>&1 | grep -i vllm
```

Repeat for each zone and project that was used.

## 2. Stop serving

Stop the `vllm serve` process or container, or `kubectl delete -f <manifest>` for GKE workloads.

## 3. Remove compute

| Resource              | Command                                                                               | Notes                                                            |
| --------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Compute Engine TPU VM | `gcloud compute instances delete my-tpu-vm --zone "$ZONE"`                            | Also decide on boot and data disks                               |
| Cloud TPU API VM      | `gcloud compute tpus tpu-vm delete my-tpu-name --zone "$ZONE" --quiet`                | Delete the queued resource too if one created it                 |
| Queued resource       | `gcloud alpha compute tpus queued-resources delete my-queued-resource --zone "$ZONE"` | A queued resource with a node may need `--force`; check `--help` |
| GKE TPU node pool     | `gcloud container node-pools delete <pool> --cluster "$CLUSTER" --zone "$ZONE"`       | Delete the cluster only if you created it for this               |
| Reservations          | Release or cancel in the console or with the reservations API                         | Reservations bill while held; confirm in Cloud Billing           |

Stopping a Cloud TPU VM (`tpu-vm stop`) pauses it but leaves the resource; use `delete` to end it.

## 4. Verify

Re-run the discovery commands. Nothing TPU-related should remain, then check Cloud Billing for the TPU SKUs over the next day. Remove any firewall rules, service accounts or buckets created for the run, with approval.
