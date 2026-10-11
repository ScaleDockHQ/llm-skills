# OpenRouter teardown

> Verified against OpenRouter API v1 (docs: authentication, management-api-keys, byok, presets, workspaces, features/zdr), 2026-10-11

OpenRouter has no servers to stop. What persists or can bill: API keys, management keys, BYOK keys, presets, credits with auto top-up, Broadcast destinations, batch jobs and files, and any shared agent keys. List before deleting and get approval for each deletion.

## 1. Stop spending

- Turn off auto top-up in https://openrouter.ai/settings/credits. Set remaining keys' limits to a small value first if you are not deleting them yet.
- Check pending batches: `GET /api/v1/batches` (statuses include `cancelling` and `cancelled`; see batch-quickstart for the cancel call) and files with `GET /api/v1/files`.

## 2. Keys

```bash
# Management key required for listing; do not print key values
curl -fsS https://openrouter.ai/api/v1/keys -H "Authorization: Bearer $OPENROUTER_MANAGEMENT_KEY" \
  | jq -r '.data[] | [.name, .hash, .disabled, .limit_remaining] | @tsv'
```

Delete or disable unused inference keys in the dashboard (https://openrouter.ai/settings/keys) or with the API (`PATCH /api/v1/keys/{hash}` to disable or update, `DELETE /api/v1/keys/{hash}` to delete, with a management key). Delete management keys at https://openrouter.ai/settings/management-keys. Remove the local key file and the env var from shell profiles, CI secrets and `.claude/settings.local.json`.

## 3. BYOK, presets, guardrails, broadcast

- Remove BYOK keys in workspace integrations; that also stops billing the BYOK fee. Revoke the provider-side key afterwards.
- Delete presets no client references (search code for `@preset/`).
- Remove guardrail assignments and Broadcast destinations (and revoke the destination credentials).

## 4. Verify

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://openrouter.ai/api/v1/key -H "Authorization: Bearer $OLD_KEY"   # expect 401 after deletion
```
