# SambaNova setup and auth

> Verified against SambaNova docs (API keys and URLs, Rate limits, Models overview, docs index llms.txt), 2026-10-11

## Products and naming

- **SambaCloud**: the hosted, multi-tenant API. Sign in at `https://cloud.sambanova.ai`. Earlier called SambaNova Cloud.
- **SambaStack**: SambaNova's dedicated deployment (also "SambaManaged" in the deprecation notes). The base URL and key tool are provided by your system administrator, and rate limits are optional and applied to user groups by the admin.

Models retired from SambaCloud can remain available on SambaStack; the route to them is the SambaNova sales team.

## API keys

- Create in the API section of the SambaCloud portal.
- Each user can generate up to 25 keys.
- A key is displayed once. It cannot be viewed again, so store it securely at creation time.
- Unverified: key rename, expiry and the delete UI wording; check https://cloud.sambanova.ai/apis.

```bash
umask 077
mkdir -p ~/.config
read -rs -p "SambaNova API key: " K && printf '%s' "$K" > ~/.config/sambanova.key && unset K
export SAMBANOVA_API_KEY="$(cat ~/.config/sambanova.key)"
[ -n "$SAMBANOVA_API_KEY" ] && echo "SAMBANOVA_API_KEY is set"
```

Use `Authorization: Bearer $SAMBANOVA_API_KEY`. Keep keys server-side.

## Tiers

| Tier      | Applied when                            |
| --------- | --------------------------------------- |
| Free      | No payment method linked to the account |
| Developer | A payment method is linked              |
| Higher    | Contact SambaNova sales                 |

Link a payment method on the Billing page of the portal. Ask the user first: it turns on paid usage. Pricing is on the SambaCloud pricing page; the docs state that per-model pricing is also returned by `/v1/models`. Unverified: spend caps and billing alerts, check the Billing page.

## Data handling

The pages read do not state prompt retention or training terms. Unverified: check https://sambanova.ai/privacy-policy and the terms before sending sensitive data.

## Official links

- API keys and URLs: https://docs.sambanova.ai/docs/en/get-started/api-keys-urls.md
- Docs index: https://docs.sambanova.ai/docs/llms.txt
- Portal: https://cloud.sambanova.ai
