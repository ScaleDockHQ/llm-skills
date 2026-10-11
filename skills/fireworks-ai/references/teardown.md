# Fireworks AI teardown

> Verified against Fireworks docs: Deployments guide (managing and deleting), Reserved capacity, Batch API, Cleanup and Teardown (training API), Data handling (stored responses); firectl command pages deployment delete/undelete/scale, batch-inference-job delete, supervised-fine-tuning-job cancel/delete, dataset delete, model delete, model unload-lora, api-key delete, 2026-10-11

Confirm with the user which resources are theirs. List before deleting.

## 1. Deployments (bill by GPU-second while replicas run)

```bash
firectl deployment list
firectl deployment get <DEPLOYMENT_ID>
```

Stop spending but keep the deployment:

```bash
firectl deployment scale <DEPLOYMENT_ID> --replica-count 0
```

Delete:

```bash
firectl deployment delete <DEPLOYMENT_ID> --wait
```

- `delete` is a soft delete (state `DELETED`) and can be reversed with `firectl deployment undelete <DEPLOYMENT_ID> --wait`. `--hard` performs a hard delete. `--ignore-checks` skips the in-use check; do not use it without a reason.
- Unload LoRAs first if the deployment hosts them: `firectl model unload-lora <LORA_ID> --deployment <DEPLOYMENT_ID>`.
- Idle deployments scale to zero after 1 hour by default and are auto-deleted after 7 days without traffic. Do not rely on either.
- Deleting is also how you drop a `--preemptible` deployment after an eval.

## 2. Reservations

Reserved capacity bills until the reservation ends even if unused, and continues to be invoiced separately. Deleting deployments does not cancel it. Contact your account representative; see https://docs.fireworks.ai/deployments/reservations. Turn down matching deployments or renew before the end to avoid on-demand rates.

## 3. Batch jobs and datasets

```bash
firectl batch-inference-job list
firectl batch-inference-job delete <JOB_ID> --wait
firectl dataset list
firectl dataset delete <DATASET_ID> --wait      # input and output datasets
```

Download results first (`firectl dataset download <OUTPUT_DATASET_ID>`). No firectl command to cancel a running batch job was found in the docs read; delete the job, or check https://docs.fireworks.ai/guides/batch-inference.

## 4. Training jobs, models and trainers

```bash
firectl supervised-fine-tuning-job list
firectl supervised-fine-tuning-job cancel <JOB_ID>
firectl supervised-fine-tuning-job delete <JOB_ID> --wait
firectl model list
firectl model delete <MODEL_ID>               # fine-tuned models and LoRAs you no longer need
```

For RFT, DPO and Training API trainers, use the matching `... cancel` and `... delete` commands (for example `firectl dpo-job cancel`, `firectl rlor-trainer-job cancel`) and the SDK-managed cleanup described at https://docs.fireworks.ai/fine-tuning/training-api/reference/cleanup. RLOR trainers auto-stop after 10 minutes without tracked activity, and weight-sync deployments hold GPUs until scaled to zero or deleted.

## 5. Stored responses

Responses API calls with `store=True` (default) keep conversation data for 30 days. Delete one immediately with the Delete Response endpoint by `response_id` (https://docs.fireworks.ai/api-reference/delete-response).

## 6. Keys and access

```bash
firectl api-key list                           # admins: add --all-users
firectl api-key delete <KEY_ID>
firectl user delete <SERVICE_ACCOUNT_OR_USER_ID>   # removes access; admin only
```

Only admins can delete other users' and service accounts' keys. Rotate by creating the replacement key first, deploying it, then deleting the old key.

## 7. Spend backstop

After teardown, keep or lower the monthly spend limit: `firectl quota update monthly-spend-usd --value <USD>`. At 100% of the limit all API traffic pauses.

## 8. Verify nothing still accrues

```bash
firectl deployment list                        # expect none, or only states you intend (scaled to 0, DELETED)
firectl batch-inference-job list
firectl supervised-fine-tuning-job list
firectl quota list                             # spend and GPU usage
```

Then check the billing and usage views (or Query Usage Costs) the next day: usage lags, and reservations are billed separately.

## Sources

- https://docs.fireworks.ai/guides/ondemand-deployments
- https://docs.fireworks.ai/tools-sdks/firectl/commands/deployment-delete
- https://docs.fireworks.ai/tools-sdks/firectl/commands/batch-inference-job-delete
- https://docs.fireworks.ai/tools-sdks/firectl/commands/supervised-fine-tuning-job-delete
- https://docs.fireworks.ai/tools-sdks/firectl/commands/api-key-delete
- https://docs.fireworks.ai/fine-tuning/training-api/reference/cleanup
