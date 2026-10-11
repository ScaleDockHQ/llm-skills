# Anthropic API: teardown

> Verified against Claude Platform docs: Administration API (API keys, workspaces), Workspaces, Message Batches, Files API, API and data retention, 2026-10-11

The API has no servers to stop. What can still cost money or hold data is **keys, in-flight batches, uploaded files and enabled limits**. Ask before deleting anything you did not create in this session, and list before you delete.

## 1. Stop traffic

- [ ] Remove or repoint the gateway alias and client configs that hold the key.
- [ ] Cancel running batches (`processing_status` of `in_progress`); status becomes `canceling`, then `ended`. Requests that already completed are still billed.

```bash
H=(-H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01")
curl -sS "https://api.anthropic.com/v1/messages/batches?limit=100" "${H[@]}" \
  | jq -r '.data[] | [.id, .processing_status, .created_at] | @tsv'
curl -sS -X POST "https://api.anthropic.com/v1/messages/batches/$BATCH_ID/cancel" "${H[@]}" | jq .processing_status
```

## 2. Delete stored objects

```bash
# Finished (or cancelled) batches: stored up to 29 days; delete earlier if sensitive
curl -sS -X DELETE "https://api.anthropic.com/v1/messages/batches/$BATCH_ID" "${H[@]}"

# Files: list, then delete (deleted files cannot be recovered)
curl -sS "https://api.anthropic.com/v1/files" "${H[@]}" | jq -r '.data[] | [.id, .filename, .size_bytes] | @tsv'
curl -sS -X DELETE "https://api.anthropic.com/v1/files/$FILE_ID" "${H[@]}"
```

- In-progress batches must be cancelled before deletion.
- The `.data[]` field names for files are as documented in the Files API reference; adjust the `jq` filter if your response differs.
- Managed Agents sessions, skills and other persistent resources have their own delete endpoints; sessions persist until you delete them.
- Prompt caches expire on their own (5 minutes or 1 hour); there is nothing to delete.

## 3. Disable or archive keys

- Rotate by replacing: create a new key in the Console, deploy, verify, then deactivate the old one.
- Deactivate a key with the Admin API (it cannot create or delete keys; it can rename and change status):

```bash
curl -sS "https://api.anthropic.com/v1/organizations/api_keys?limit=100&status=active&workspace_id=$WORKSPACE_ID" \
  -H "x-api-key: $ANTHROPIC_ADMIN_KEY" -H "anthropic-version: 2023-06-01" \
  | jq -r '.data[] | [.id, .name, (.expires_at // "never")] | @tsv'
curl -sS "https://api.anthropic.com/v1/organizations/api_keys/$KEY_ID" \
  -H "x-api-key: $ANTHROPIC_ADMIN_KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d '{"status":"inactive"}'
```

- Personal keys stop working when their user is removed; service-account keys stop when the service account is archived (they survive removal of the user who created them).
- Delete keys fully in Console > Settings > API keys when you want them gone.
- Workload Identity Federation: delete the federation rule and, if unused, archive the service account (Admin API reference, OAuth `org:admin` token).
- Remove the key file and variables: `rm -P ~/.config/llm/anthropic.key; unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_ADMIN_KEY`.

## 4. Archive test workspaces

Archiving a workspace deactivates it and archives every key created for it within seconds (they stay listed as archived); it cannot be undone and the Default Workspace cannot be archived.

```bash
curl -sS -X POST "https://api.anthropic.com/v1/organizations/workspaces/$WORKSPACE_ID/archive" \
  -H "x-api-key: $ANTHROPIC_ADMIN_KEY" -H "anthropic-version: 2023-06-01"
```

Do not archive the Claude Code workspace unless intended: it disables Claude Code sign-in through Console billing for the organization.

## 5. Verify nothing still accrues

- [ ] Batch list shows no `in_progress` jobs.
- [ ] Files list is empty or only intended files.
- [ ] Key list (`status=active`) shows only intended keys.
- [ ] User-set spend limit stays on workspaces that remain.
- [ ] Console Usage and Billing pages flat the next day.

## Where to read more

- https://platform.claude.com/docs/en/build-with-claude/administration-api
- https://platform.claude.com/docs/en/build-with-claude/workspaces
- https://platform.claude.com/docs/en/build-with-claude/batch-processing
