# Crusoe: teardown

> Verified against Crusoe Cloud docs (CMK delete, VM and disk lifecycle, self-serve deployments), 2026-10-11

Order, leaf resources first. List before and after.

1. Self-serve deployments: `curl -X DELETE "$DEPLOYMENT_URL/deployments/$ID" -H "Authorization: Bearer $CRUSOE_API_KEY"`; confirm with the list call.
2. Kubernetes workloads and PVCs: `kubectl delete -f ...`.
3. CMK: delete all node pools, then the cluster (`crusoe kubernetes nodepools delete ...`, `crusoe kubernetes clusters delete ...`; confirm names with `--help`).
4. VMs: `crusoe compute vms delete <name>` (stopping is enough to stop VM billing but not to remove disks).
5. Disks: `crusoe storage disks list`, then `crusoe storage disks delete <name>`. Persistent and shared disks bill when detached.
6. Credentials: delete Intelligence API keys and CLI access keys created for the task; remove key files.

Verify: `crusoe compute vms list`, `crusoe storage disks list`, the deployments list and the console Billing page show nothing left that you intend to remove.
