# Hyperbolic setup and auth

> Verified against hyperbolic.ai/docs general/account-management, on-demand/quickstart, api-reference/openapi.json (API 2.0.0), 2026-10-11

## Account

- Sign up at https://app.hyperbolic.ai with email, Google or GitHub, and verify the email.
- Plans: free, pro, enterprise. There is no monthly fee. You buy compute credits that sit as a balance.
- The free tier cannot launch GPU instances or storage volumes. A one-time deposit (the docs state the minimum on the account page) moves you to pro, which unlocks GPUs and higher API rate limits. Read the current minimum and limits on https://hyperbolic.ai/docs/general/account-management rather than copying them.
- Credits are 1:1 with dollars and the billing page says they do not expire. Card payments go through Stripe.
- Organizations share a workspace, balance and infrastructure: https://hyperbolic.ai/docs/general/organizations.

## API key

1. Open the API Keys section in settings and create a key.
2. The key cannot be viewed or recovered afterwards, so store it immediately in a `0600` file.
3. Keys can be revoked at any time and an account may have any number of them.

```bash
mkdir -p ~/.config/hyperbolic && chmod 700 ~/.config/hyperbolic
umask 077
# paste the key when prompted; input is not echoed
read -rs HYP_KEY && printf '%s' "$HYP_KEY" > ~/.config/hyperbolic/api_key && unset HYP_KEY
export HYPERBOLIC_API_KEY="$(cat ~/.config/hyperbolic/api_key)"
```

List the keys on the account (the response is metadata, check it before sharing): `GET /v2/api-keys/list`.

## Hosts and header

| Item            | Value                                                                                             |
| --------------- | ------------------------------------------------------------------------------------------------- |
| Production host | `https://api.hyperbolic.ai`                                                                       |
| Legacy host     | `https://api.hyperbolic.xyz`, the same API on the original domain, kept for existing integrations |
| Auth            | `Authorization: Bearer $HYPERBOLIC_API_KEY` (OpenAPI security scheme: http bearer)                |
| Spec            | `GET /v2/openapi.json`, also https://hyperbolic.ai/docs/api-reference/openapi.json                |

Smoke test:

```bash
curl -sS https://api.hyperbolic.ai/v2/users/me -H "Authorization: Bearer $HYPERBOLIC_API_KEY" | jq 'keys'
```

A 401 means the key is missing, revoked or pasted with whitespace.

## SSH keys

- An SSH key is required to provision an instance. Password login is disabled.
- Generate one: `ssh-keygen -t ed25519 -C "you@example.com"`. Upload only the `.pub` file.
- Settings, SSH Keys: https://app.hyperbolic.ai/settings/ssh-keys. You can save several keys, rename them, and select one or more when you launch.
- A key cannot be deleted while a live instance uses it.
- API: `GET /v2/ssh-keys`, `POST /v2/ssh-keys`, `POST /v2/ssh-keys/update` (rename), `POST /v2/ssh-keys/delete`, `GET /v2/ssh-keys/rental` (keys attached to a rental).
- Some regions accept more than one key per instance. Others return `MULTIPLE_SSH_PUBLIC_KEYS_NOT_SUPPORTED_FOR_REGION`.
- If a create request names no key, Hyperbolic attaches your newest saved key (an organization uses its newest key). Pass `sshPublicKeyIds` to choose.
- Changing keys on a running VM (no reboot) is in the changelog dated 2026-10-10: `POST /v2/on-demand/rentals/ssh-keys/attach` and the matching detach. A rental must keep at least one key and bare metal does not support changes. The OpenAPI spec read on 2026-10-11 did not list these paths yet, so unverified: check https://hyperbolic.ai/docs/changelog before relying on them.

## Verify

- [ ] `GET /v2/users/me` returns 200.
- [ ] `GET /v2/customer/balance` shows enough balance for at least one hour of the GPU you plan to rent.
- [ ] `GET /v2/ssh-keys` lists the key you intend to use.
