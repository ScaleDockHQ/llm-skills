# Nebius: teardown

> Verified against Nebius AI Cloud docs (CLI reference compute instance delete, VM stop and start, quotas) and Token Factory docs, 2026-10-11

Order, leaf resources first. List before and after.

1. Token Factory dedicated endpoints: `DELETE /v0/dedicated_endpoints/<id>` (stop with `enabled:false` only if you plan to resume; a stop releases capacity).
2. Fine-tuned models, files and datasets you no longer need (console or API).
3. mk8s: delete workloads and PVCs, then node groups, then the cluster.

```bash
kubectl delete -f <manifests>
nebius mk8s node-group list --parent-id "$CLUSTER_ID"
nebius mk8s node-group delete --id "$NODE_GROUP_ID"
nebius mk8s cluster delete --id "$CLUSTER_ID"
```

4. VMs: `nebius compute instance delete --id "$VM_ID"` (also deletes managed disks declared in the spec; it fails if one cannot be deleted).
5. Leftovers: `nebius compute disk list` then `nebius compute disk delete --id`, filesystems, public IPs and subnets you created.
6. Credentials: revoke Token Factory keys you made for the task; delete service accounts and private key files.

Verify: `nebius compute instance list`, `nebius mk8s cluster list`, `nebius compute disk list` return nothing you intend to remove, and the console Billing page stops climbing.
