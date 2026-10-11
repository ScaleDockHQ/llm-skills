# Gemini API: teardown

> Verified against Gemini API docs: Using Gemini API keys, Files, Caching, Batch API, Billing, 2026-10-11

There are no servers to stop. What can still cost money or hold data is **keys, caches, files, batches and billing settings**. Ask before deleting anything you did not create in this session, and list before you delete.

## 1. Stop traffic

- [ ] Remove or repoint the gateway alias and client configs that hold the key.
- [ ] Check running batch jobs: states `JOB_STATE_PENDING` or `JOB_STATE_RUNNING` keep billing and may overshoot caps. Cancel through the Batch API or SDK (`client.batches.cancel(name=...)`; check the Batch API reference for the current call, unverified here).

## 2. Delete stored objects

```bash
H=(-H "x-goog-api-key: $GEMINI_API_KEY")
B=https://generativelanguage.googleapis.com/v1beta

# Files (auto-delete after 48 hours, but remove sensitive ones now)
curl -sS "$B/files" "${H[@]}" | jq -r '.files[]? | [.name, .displayName, .expirationTime] | @tsv'
curl -sS -X DELETE "$B/$FILE_NAME" "${H[@]}"            # FILE_NAME like files/abc-123

# Explicit caches (storage is billed until TTL or deletion)
curl -sS "$B/cachedContents" "${H[@]}" | jq -r '.cachedContents[]? | [.name, .model, .expireTime] | @tsv'
curl -sS -X DELETE "$B/$CACHE_NAME" "${H[@]}"           # CACHE_NAME like cachedContents/abc
```

- Batch results are kept for 6 weeks and then deleted. A delete call for a batch is not confirmed in the pages read; check the Batch API reference before relying on early deletion.
- Implicit caches need no cleanup. Tuned models, if any, can be deleted in AI Studio or through the API (tuning data is removed with them).

## 3. Disable and delete keys

- Create the replacement first, deploy, then disable the old key in the Cloud console (credentials page); delete it after the new key is confirmed active. AI Studio also deletes or revokes keys (API keys page).
- Remove the key file and variables: `rm -P ~/.config/llm/gemini.key; unset GEMINI_API_KEY GOOGLE_API_KEY`.
- Leaked key: follow the leak checklist in `references/setup-and-auth.md`; leaked keys may also be blocked by Google and return "Your API key was reported as leaked".

## 4. Billing and projects

- [ ] Prepay: stop auto-reload (AI Studio Billing > Manage auto-reload). Unused credits expire after 12 months and are not refundable except when switching to Postpay.
- [ ] Keep a project spend cap on projects that remain.
- [ ] Unlink or remove test projects in the Cloud console (project deletion is a Cloud operation, not an AI Studio one).

## 5. Verify nothing still accrues

- [ ] File and cache lists are empty or only intended items.
- [ ] No pending or running batches.
- [ ] Key list shows only intended keys.
- [ ] AI Studio Usage and Spend pages flat after the billing latency (about 10 minutes, so check again the next day).

## Where to read more

- https://ai.google.dev/gemini-api/docs/api-key
- https://ai.google.dev/gemini-api/docs/files
- https://ai.google.dev/api/caching
