# DeepInfra setup and auth

> Verified against DeepInfra docs (Quickstart, Authentication, Data Privacy, API reference: Create API token, Create scoped JWT, docs index llms.txt), 2026-10-11

## Account and keys

- Sign in and manage keys in the Dashboard (`https://deepinfra.com/dash/api_keys`). See the Signing In page for GitHub, Google and Okta SSO options.
- API keys are full-access. Send `Authorization: Bearer $DEEPINFRA_API_KEY`.
- API for keys (all documented in the API reference, Authentication section): create (`POST /v1/api-tokens` with `{"name": "..."}`, returns `token`, `token_id`, `allowed_ips`, `fragment` = last 5 chars), list, get, delete by id. The `token_id` is what billing limits use.
- Name keys per app or environment so each can be limited and revoked on its own. Keys can carry an `allowed_ips` list (field shown in the response; unverified: how to set it, check the API reference).

```bash
umask 077
mkdir -p ~/.config
read -rs -p "DeepInfra API key: " K && printf '%s' "$K" > ~/.config/deepinfra.key && unset K
export DEEPINFRA_API_KEY="$(cat ~/.config/deepinfra.key)"
[ -n "$DEEPINFRA_API_KEY" ] && echo "DEEPINFRA_API_KEY is set"
```

## Scoped JWTs

Short-lived, restricted tokens to give to third parties or browsers. Usage counts against the API key that signed them.

```bash
curl -sS -X POST https://api.deepinfra.com/v1/scoped-jwt \
  -H "Content-Type: application/json" -H "Authorization: Bearer $DEEPINFRA_API_KEY" \
  -d '{"api_key_name":"auto","models":["<model-slug>"],"expires_delta":3600,"spending_limit":1.0}' \
  | jq -r .token > /tmp/scoped.jwt && chmod 600 /tmp/scoped.jwt
```

- `models`: omit to allow any model. `expires_delta` seconds (default and maximum one year) or `expires_at` (unix time). `spending_limit`: USD, omit for none.
- Inspect: `GET /v1/scoped-jwt?jwtoken=...` returns `expires_at`, `models`, `spending_limit`.
- Use like a key. Disallowed models, expired or over-budget tokens are rejected.
- Always set all three restrictions. Treat the token as a secret (the example writes it to a `0600` file instead of printing it).

## Data handling

From the Data Privacy page: input and output are held in memory only during inference, not stored on disk, not used for training and not shared, with exceptions for Google models (Google stores outputs per its notice and logs prompts for abuse detection) and Anthropic models (Anthropic stores outputs per its Trust Center). Image generation outputs are kept for a short time. Bulk APIs may store data encrypted on disk for a short period until results are returned. Logs have metadata only (request ID, cost, sampling parameters). Check the page again before sending regulated data: https://docs.deepinfra.com/account/data-privacy.md.

## Other account surfaces

SSO via Okta, webhooks, team display name, rate-limit increase request and account deletion are in the API reference, Account section. Account deletion is an API call (`delete-account`); do not run it without explicit approval.

## Official links

- Quickstart: https://docs.deepinfra.com/quickstart.md
- Authentication: https://docs.deepinfra.com/account/authentication.md
- Docs index: https://docs.deepinfra.com/llms.txt
