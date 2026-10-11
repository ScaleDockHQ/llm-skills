# Runpod teardown: stop every billable resource

> Verified against runpodctl v2.15.0 (pod, serverless, template, network-volume references), docs.runpod.io pods/storage/types, serverless/endpoints/endpoint-configurations, 2026-10-11

Always list what exists, tell the user what will be deleted and what data is lost, then delete. Deletions are permanent.

## 1. Inventory

```bash
runpodctl pod list                    # add --all for stopped Pods if --help shows it
runpodctl serverless list
runpodctl network-volume list
runpodctl template list --type user
runpodctl user                        # note currentSpendPerHr before and after
```

## 2. Remove in this order

1. **Serverless endpoints first** (they spawn workers):

   ```bash
   runpodctl serverless update <endpoint-id> --workers-max 0    # optional: drain first
   runpodctl serverless delete <endpoint-id>   # confirm exact subcommands with `runpodctl serverless --help`
   ```

2. **Pods**: stop is not enough, since a stopped Pod still bills for its volume disk.

   ```bash
   runpodctl pod delete <pod-id>
   ```

3. **Network volumes** (billed even when nothing is attached). Copy anything you need first (`runpodctl send`, the S3-compatible API, or a Pod).

   ```bash
   runpodctl network-volume delete <volume-id>
   ```

4. **Templates** you created. Free to keep, but a Serverless template binds to one endpoint, so delete leftovers:

   ```bash
   runpodctl template delete <template-id>
   ```

5. **Credentials**: revoke any API key made for this job in the console (Credentials -> API Keys -> trash icon -> Revoke Key), remove secrets and registry auth you added, and delete the local key file if it was temporary: `shred -u ~/.config/runpod/api-key` or `rm -P` on macOS.

## 3. Verify nothing accrues

```bash
runpodctl pod list; runpodctl serverless list; runpodctl network-volume list
runpodctl user | jq '{clientBalance, currentSpendPerHr}'
runpodctl billing pods; runpodctl billing serverless; runpodctl billing network-volume
```

Expected: three empty lists and a `currentSpendPerHr` near zero. Check again after a few minutes, because billing displays lag. Remove the model entry from LiteLLM or the gateway config and any client env vars that point at the deleted endpoint.

## Traps

- `wait_timeout` from `pod create --wait` or similar leaves a live resource. Look up its `id` in the error and delete it.
- `runtimeStatus` can be `unknown`; treat it as still billing until `pod list` no longer shows the Pod.
- If a resource is not visible in the CLI, check the console **Pods**, **Serverless** and **Storage** pages once as a cross-check, including team accounts, since a key only sees its own account.
