# Lambda Cloud: teardown

> Verified against Lambda docs: Cloud Console (terminate instances), Creating and managing instances, Filesystems, 1-Click Clusters, Billing overview, Cloud API terminate and delete endpoints, 2026-10-11

Do this in order. Ask the user before each destructive step; terminating erases the instance root disk.

## 1. Back up what you need

Copy anything not on a filesystem (logs, results, adapters) with `rsync` or `scp`. The root volume is erased on terminate.

## 2. Terminate instances

Never use `sudo shutdown -h now` or `poweroff` for this: the instance goes to an Alert status and billing continues.

```bash
IDS=$(curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/instances | jq -c '[.data[]|select(.name=="llm-serve-1")|.id]')
echo "$IDS"    # confirm with the user, then:
curl -sS -X POST -H "Authorization: Bearer $LAMBDA_API_KEY" -H 'Content-Type: application/json' \
  -d "{\"instance_ids\": $IDS}" https://cloud.lambda.ai/api/v1/instance-operations/terminate | jq
```

The console asks you to type `erase data on instance` to confirm; the API does not prompt.

## 3. Delete filesystems you no longer want

A filesystem must be detached (its instances terminated) before deletion and keeps billing until deleted. Confirm the user does not need the weights, then delete in the console Storage page or with the API (`Delete filesystem` in https://docs.lambda.ai/api/cloud).

## 4. Delete firewall rulesets, SSH keys and API keys you created for this job

- Firewall rulesets: `DELETE /firewall-rulesets/{id}` (only when no instance uses them).
- SSH keys: `DELETE /ssh-keys/{id}`.
- API key: delete it in the console Cloud API keys page if it was job-specific.

## 5. 1-Click Cluster

A reservation cannot be extended and ends on its own date; local NVMe is wiped at the end. You can cancel a pending request from the console Instances page before it is approved. Copy data to a filesystem before the end date. Generic CPU nodes launched next to a cluster do not end with it; terminate them separately.

## 6. Verify nothing accrues

```bash
curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/instances | jq '.data|length'      # expect 0
curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/file-systems | jq '.data|length'   # expect 0 unless intentionally kept
curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/firewall-rulesets | jq '.data|length'
```

Then check the console Usage page the next day. Remove or update the gateway entry that pointed at the instance.

## Sources

- https://docs.lambda.ai/public-cloud/console/
- https://docs.lambda.ai/public-cloud/filesystems/
- https://docs.lambda.ai/public-cloud/1-click-clusters/
- https://docs.lambda.ai/api/cloud
