# Lambda Cloud: filesystems and 1-Click Clusters

> Verified against Lambda docs: Filesystems, On-Demand Cloud overview, 1-Click Clusters introduction and Billing overview, and the Cloud API filesystem endpoints (spec 1.10.0), 2026-10-11

## Storage tiers

| Storage        | Persists after terminate? | Notes                                                                                                |
| -------------- | ------------------------- | ---------------------------------------------------------------------------------------------------- |
| Root volume    | No                        | Size depends on instance type. Terminate erases it.                                                  |
| Filesystem     | Yes, until deleted        | Regional network storage, billed per GiB used per month in one-hour increments, even when unmounted. |
| 1CC local NVMe | No                        | Ephemeral; deleted when the reservation ends.                                                        |

## Filesystems

- Create in the console Storage page, or `POST /filesystems` (older path `/file-systems`); list with `GET /file-systems`; delete with `DELETE /filesystems/{id}` (see API browser for the exact body).
- Must be in the same region and workspace as the instance. They cannot be moved between regions.
- Attach only at instance or cluster creation: `file_system_names` or `file_system_mounts` in the launch call. They cannot be attached to a running instance or mounted over NFS remotely.
- Mount path: `/lambda/nfs/<FILESYSTEM_NAME>`, symlinked in the `ubuntu` home directory. Custom mount points must start with `/home`, `/lambda/nfs` or `/data`.
- Limits: in most regions up to 24 filesystems with very large capacity; `us-south-1` is limited to 10 TB. You cannot set a usage limit (quota) on a filesystem, so watch usage yourself.
- Usage: console Usage page (Filesystems tab), `df -h -BG` on an instance, or `bytes_used` from `GET /file-systems`.
- Access remotely with the Filesystem S3 Adapter (select regions only; works with `rclone` and `s5cmd`) or `rsync` through a running instance.
- JupyterLab and other apps may create hidden `.Trash-*` directories on the filesystem. They count toward billed storage until permanently deleted.

```bash
curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/file-systems \
  | jq -r '.data[] | [.name, .region.name, (.bytes_used|tostring), (.is_in_use|tostring)] | @tsv'
```

Put model weights and the Hugging Face cache on a filesystem so a relaunch does not re-download.

## 1-Click Clusters (1CC)

- 16 to 512 NVIDIA H100 or B200 SXM GPUs, InfiniBand fabric between GPU nodes, 3 CPU management (head) nodes with public IPs, GPU nodes on a private network.
- Reserved, not on-demand: choose duration in weeks, region, filesystem and SSH key in the console wizard, then submit a reservation request. Lambda emails an invoice; pay within 10 days of approval or risk losing the reservation. Billing is weekly per GPU per hour under the reservation terms.
- Reservation cannot currently be extended or renewed; request a new one.
- When it ends, all ephemeral local storage is deleted. Back up to a filesystem first.
- Access: SSH to a head node, then to compute nodes (cluster SSH config from the console). No API launch path appears in the docs read; use the console. Instances in a cluster appear in `GET /instances?cluster_id=<id>`.
- The home page also lists Managed Kubernetes, preinstalled Kubernetes and Slurm for the public cloud. Unverified: check https://docs.lambda.ai/ for the current setup path before promising any of these.

## Sources

- https://docs.lambda.ai/public-cloud/filesystems/
- https://docs.lambda.ai/public-cloud/1-click-clusters/
- https://docs.lambda.ai/public-cloud/billing/
- https://docs.lambda.ai/api/cloud
