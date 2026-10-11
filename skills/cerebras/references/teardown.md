# Cerebras teardown

> Verified against Cerebras Inference docs (API Keys, Projects, Account & Billing, Batch, Dedicated Inference overview), 2026-10-11

Shared Inference has no servers to stop; nothing bills when idle. Cleanup is about keys, projects, stored batch data and billing triggers. Ask the user before each deletion.

## Checklist

- [ ] **Stop traffic**: remove the model entries or keys from LiteLLM, CI and apps. Grep your repos for `CEREBRAS_API_KEY` and `api.cerebras.ai`.
- [ ] **Cancel running batches** (private preview) and delete input and output files:

```bash
curl -sS -X DELETE https://api.cerebras.ai/v1/batches/BATCH_ID -H "Authorization: Bearer $CEREBRAS_API_KEY"
```

Output files are retained 7 days by the service; use the Files API for earlier deletion. Unverified: exact file-delete route, check https://inference-docs.cerebras.ai/api-reference/files.

- [ ] **Delete API keys** (Console, API Keys, trash icon). Immediate and permanent. Rotate by creating the new key first.
- [ ] **Archive unused projects** (Org Admin only: Projects, project menu, Archive). Archiving deactivates all of the project's keys and makes the project read-only; usage data and audit logs are kept. Restore from the Archived view if needed. Archiving does not stop billing for earlier usage and the Default Project may be restricted.
- [ ] **Billing off-switches**: turn off auto-recharge, cancel model subscriptions on the Billing page, and download usage CSVs you want to keep first.
- [ ] **Dedicated Inference**: the deployment and its replicas are contract-based; ask Cerebras support or use the Management API (https://inference-docs.cerebras.ai/dedicated/overview) to remove deployments. Do not assume deleting a key stops capacity billing.
- [ ] **Local**: delete `~/.config/cerebras.key` and unset the variable in shell profiles and CI secrets.

## Verify

```bash
# A deleted key should fail with 401, not return models
curl -s -o /dev/null -w '%{http_code}\n' https://api.cerebras.ai/v1/models -H "Authorization: Bearer $OLD_KEY"
```

Expect `401`. Then check Billing (no pending recharge) and Analytics (no new usage).

## Account closure

Not self-service in the pages read. Contact Cerebras support.
