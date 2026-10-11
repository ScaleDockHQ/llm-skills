# Together AI teardown

> Verified against Together docs: Manage endpoints and deployments (Delete resources), Dedicated endpoints Quickstart, Manage batch jobs, Monitor a fine-tuning job, Files CLI, Authentication, Projects; API reference index entries for cluster, volume, deployment and secret deletion, 2026-10-11

Deletion is permanent. Confirm with the user which resources are theirs to remove. List first.

## 1. Dedicated endpoints and deployments (bills per ready replica)

```bash
tg beta endpoints ls
tg beta endpoints get <endpoint>            # deployments and states
```

To pause billing and keep the setup (redeploy later):

```bash
tg beta endpoints update dep_abc123 --min-replicas 0 --max-replicas 0
tg beta endpoints get <endpoint>            # wait for DEPLOYMENT_STATE_STOPPED
```

To delete:

```bash
tg beta endpoints rm dep_abc123             # deployment must be stopped; auto-detaches from traffic split and experiments
tg beta endpoints rm ep_abc123              # endpoint must have no deployments
# or, for a throwaway endpoint, one step:
tg beta endpoints rm ep_abc123 --force
```

Order for SDK or API: scale to zero, wait for `STOPPED`, set the traffic weight to 0, delete the deployment, delete the endpoint. If a rollout or A/B or shadow experiment is active, complete or cancel it first. Errors: `the deployment stands in an endpoint's traffic split and cannot be deleted` (remove it from the split) and `the deployment is an A/B experiment member` (remove it from the test). The CLI's `rm` handles both.

Legacy v1 endpoints: `tg endpoints stop <id>` then `tg endpoints delete <id>`. Stopped v1 endpoints cannot be restarted.

## 2. Batches

```bash
tg batches list
tg batches cancel <BATCH_ID>                # only VALIDATING or IN_PROGRESS; completed requests are still billed
```

Output and error files expire after 7 days. Download first (`tg batches download`), then delete files (section 4).

## 3. Fine-tune jobs

```bash
tg fine-tuning list
tg fine-tuning cancel <JOB_ID>              # billed only for steps completed
tg fine-tuning delete <JOB_ID>              # removes the job and files it produced
```

Delete the dedicated endpoint serving a fine-tuned model separately (section 1); deleting the job does not remove an endpoint.

## 4. Files

```bash
tg files list
tg files delete <FILE_ID>
```

## 5. Other billable products

Together also offers GPU clusters, shared volumes and container deployments (Jig). Each has a delete operation in the API reference: `DELETE` for GPU clusters (https://docs.together.ai/reference/clusters-delete), shared volumes (https://docs.together.ai/reference/clusters_storages-delete), deployments (https://docs.together.ai/reference/deployments-delete), volumes (https://docs.together.ai/reference/deployments-storage-volumes-delete) and secrets (https://docs.together.ai/reference/deployments-secrets-delete). Read GPU clusters billing at https://docs.together.ai/docs/gpu-clusters-billing before deleting; this skill does not cover those products in depth.

## 6. Keys and access

- Revoke keys in the console: project, API keys settings, row menu. Legacy keys cannot be revoked, only regenerated (which invalidates the old one immediately).
- Disconnecting a Vercel project from the Together integration removes the env var in Vercel but does not revoke the key. Revoke it in the default project.
- Remove collaborators in Settings, Project, Collaborators (takes effect within minutes).
- Turn off auto-recharge in billing settings if you want funding to stop.

## 7. Verify nothing still accrues

```bash
tg beta endpoints ls                         # expect no endpoints, or only ones you intend to keep
tg batches list; tg fine-tuning list; tg files list
```

Then open Cost analytics for the project and confirm usage flattens after the teardown (metering lags; billing usage API current-month data can be up to 1 hour behind). For clusters or Jig deployments, check their pages in the console.

## Sources

- https://docs.together.ai/docs/dedicated-endpoints/manage
- https://docs.together.ai/docs/dedicated-endpoints/quickstart
- https://docs.together.ai/docs/inference/batch/manage
- https://docs.together.ai/docs/fine-tuning/monitoring
- https://docs.together.ai/docs/api-keys-authentication
