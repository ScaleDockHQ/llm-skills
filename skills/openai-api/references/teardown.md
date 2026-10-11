# OpenAI API: teardown

> Verified against OpenAI API reference: List files, Delete file, List batches, Cancel batch, Delete a model response, Delete a conversation, Delete a fine-tuned model, Delete project API key; Spend limits and Your data guides, 2026-10-11

The API has no running servers: what can still cost money or hold data is **keys, in-flight batches, stored objects and fine-tuned models**. Ask before deleting anything you did not create in this session, and list before you delete.

## 1. Stop traffic

- [ ] Remove or repoint the gateway alias (`llm-gateway`, `litellm`) and any client config that holds the key.
- [ ] Cancel running batches: `POST /v1/batches/{id}/cancel` (status `cancelling` for up to 10 minutes, then `cancelled`). Completed requests inside a cancelled batch are still billed.

```bash
H=(-H "Authorization: Bearer $OPENAI_API_KEY")
curl -sS "https://api.openai.com/v1/batches?limit=100" "${H[@]}" \
  | jq -r '.data[] | select(.status|test("validating|in_progress|finalizing")) | [.id,.status,.created_at] | @tsv'
curl -sS -X POST "https://api.openai.com/v1/batches/$BATCH_ID/cancel" "${H[@]}" | jq .status
```

## 2. Delete stored objects

```bash
# Files (also removes them from vector stores). List first.
curl -sS "https://api.openai.com/v1/files?limit=100" "${H[@]}" | jq -r '.data[] | [.id,.purpose,.filename,.bytes] | @tsv'
curl -sS -X DELETE "https://api.openai.com/v1/files/$FILE_ID" "${H[@]}"

# A stored model response (stored 30 days by default unless store=false)
curl -sS -X DELETE "https://api.openai.com/v1/responses/$RESPONSE_ID" "${H[@]}"

# A conversation (items inside are NOT deleted by this call)
curl -sS -X DELETE "https://api.openai.com/v1/conversations/$CONVERSATION_ID" "${H[@]}"

# A fine-tuned model (needs the Owner role)
curl -sS -X DELETE "https://api.openai.com/v1/models/$FT_MODEL_ID" "${H[@]}"
```

- Batch output files are deleted automatically 30 days after the batch completes; delete earlier if sensitive.
- Vector stores, assistants, threads, evals and other persistent objects have their own delete endpoints in the API reference; deleted Assistants-era objects are removed from servers 30 days later.
- Hosted containers (code interpreter, shell) are deleted when they expire or are explicitly deleted.
- Check the dashboard Storage or Files pages as a cross-check; the API has no single "delete everything" call.

## 3. Revoke keys

- Rotate by replacing: create a new key, deploy it, verify, then revoke the old one.
- Delete a **user-owned project key** with the Admin API (the endpoint cannot delete a service account's key):

```bash
curl -sS "https://api.openai.com/v1/organization/projects/$PROJECT_ID/api_keys" \
  -H "Authorization: Bearer $OPENAI_ADMIN_KEY" | jq -r '.data[] | [.id,.name,.last_used_at,.owner.type] | @tsv'
curl -sS -X DELETE "https://api.openai.com/v1/organization/projects/$PROJECT_ID/api_keys/$KEY_ID" \
  -H "Authorization: Bearer $OPENAI_ADMIN_KEY"    # -> {"deleted": true}
```

- Service-account keys: remove them in the dashboard or by removing the service account (unverified for the API: check the Administration API reference for service-account deletion).
- Revoke the Admin key too if it was created for this task.
- Remove the key file and unset the variable: `shred -u ~/.config/llm/openai.key 2>/dev/null || rm -P ~/.config/llm/openai.key; unset OPENAI_API_KEY`.

## 4. Cap what remains

- [ ] Keep (or lower) the hard spend limit on projects that still exist; delete unused projects in the dashboard.
- [ ] Remove spend-alert recipients that no longer apply.

## 5. Verify nothing still accrues

- [ ] Batch list shows no `validating`, `in_progress` or `finalizing` jobs.
- [ ] Files list is empty or only contains intended files.
- [ ] Project key list shows only intended keys; test keys gone.
- [ ] Usage page and spend dashboard flat the next day.

## Where to read more

- https://developers.openai.com/api/docs/guides/batch
- https://developers.openai.com/api/docs/guides/your-data
- https://developers.openai.com/api/docs/guides/spend-limits
