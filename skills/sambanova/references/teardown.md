# SambaNova teardown

> Verified against SambaNova docs (API keys and URLs, Rate limits, Deprecations; portal deletion UI not documented in the pages read), 2026-10-11

SambaCloud is serverless: nothing runs or bills while idle. Cleanup means keys, gateway config and billing settings. Ask before each deletion.

## Checklist

- [ ] **Stop traffic.** Remove `sambanova/...` entries from LiteLLM and gateway configs and any `SAMBANOVA_API_KEY` from CI, shells and `.env` files. Search code for `api.sambanova.ai`.
- [ ] **Delete API keys** in the API section of the SambaCloud portal (https://cloud.sambanova.ai/apis). Unverified: the exact delete control, check the portal. Keys are not retrievable after creation, so rotate by making a new key, switching apps, then deleting the old one.
- [ ] **Billing**: if you linked a payment method only for a trial, check the Billing page for unlinking. Unverified: the docs pages read do not describe unlinking; ask support (help@sambanova.ai) if needed.
- [ ] **Local**: `rm ~/.config/sambanova.key`, `unset SAMBANOVA_API_KEY`.
- [ ] **SambaStack**: deprovisioning is handled with your SambaNova contact, not through the public API.

## Verify

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://api.sambanova.ai/v1/models -H "Authorization: Bearer $OLD_KEY"
```

Expect `401` (`invalid_authentication`).
