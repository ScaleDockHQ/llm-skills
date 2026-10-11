# Setup and authentication

> Verified against Cloudflare AI Gateway docs (changelog through 2026-10-06), 2026-10-11

Sources: get-started, configuration/manage-gateway, configuration/authentication, configuration/bring-your-own-keys, features/unified-billing under <https://developers.cloudflare.com/ai-gateway/>.

## Credentials you need

- **Account ID**: `wrangler whoami` or the dashboard. Keep it in `CLOUDFLARE_ACCOUNT_ID`.
- **Cloudflare API token**: permissions `AI Gateway - Read`, `AI Gateway - Edit` and `Workers AI - Read` for the first-request guide. Store it in `CLOUDFLARE_API_TOKEN` or a `0600` file.
- **Gateway token** (client use): created under the gateway's Settings with `Run` permission. Send it as `Authorization: Bearer` on the REST API, or as `cf-aig-authorization: Bearer <token>` on `gateway.ai.cloudflare.com` URLs.

```bash
umask 077; printf '%s' "$TOKEN_VALUE" > ~/.config/cf-aig-token   # never echo the token
export CLOUDFLARE_API_TOKEN="$(cat ~/.config/cf-aig-token)"
```

Tokens for `AI Gateway Read`, `Run` and `Edit` cannot be limited to one gateway. Any `Run` token reaches every gateway in the account, including ones with BYOK keys. For tenant isolation use separate accounts or the Worker binding.

## Default gateway

The first authenticated request to gateway id `default` auto-creates it (third-party models need no gateway id; Workers AI requests need the `cf-aig-gateway-id` header). Defaults: authentication on, log collection on, caching off (TTL 0), rate limiting off, require provider credentials off, Workers AI billing Standard. Deleting it is safe, the next authenticated request recreates it. Only the id `default` auto-creates.

## Create a gateway

Dashboard: AI > AI Gateway > Create Gateway (name up to 64 characters, choose Workers AI billing). API:

```bash
curl -sS -X POST "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/ai-gateway/gateways" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
  --data '{"id":"my-gateway","cache_invalidate_on_update":false,"cache_ttl":0,"collect_logs":true,"rate_limiting_interval":0,"rate_limiting_limit":0,"rate_limiting_technique":"fixed"}' | jq '.success'
```

The create schema marks several fields as required (id, caching, logging and rate-limit fields). Read `/api/resources/ai_gateway/methods/create/` for the current list, and for the retry, ZDR and authentication fields, before sending anything else. Edit uses `PUT`, delete uses `DELETE` on `/ai-gateway/gateways/{id}`.

## Authentication behaviour

| Authenticated Gateway | Header  | Result        |
| --------------------- | ------- | ------------- |
| On                    | present | ok            |
| On                    | missing | request fails |
| Off                   | any     | ok            |

Requests from a Worker through an AI binding are pre-authenticated.

## Who pays: credential precedence

1. A provider key on the request (for example `Authorization` for a provider-native URL) is forwarded unchanged. BYOK and credits are not consulted.
2. A stored BYOK key under the `default` alias.
3. Unified Billing: Cloudflare-managed credentials, billed to credits.

Alias selection with `cf-aig-byok-alias` works only on provider pass-through requests, not on REST or binding paths that use Unified Billing. To block fall-through to credits for third-party providers, enable **Require provider credentials** (dashboard or API).

## BYOK (stored keys)

Dashboard: gateway > Provider Keys > Add API Key. Keys live in Cloudflare Secrets Store. Requires an authenticated gateway and Secrets Store permissions. Via API, create the secret first, named `{gateway_id}_{provider_slug}_{alias}`, then create the provider config. Rotate by adding a new key and removing the old one.

## Unified Billing

Prepaid credits cover Workers AI and supported third-party providers on one Cloudflare bill. A fee applies to credit purchases, and provider token rates pass through; read the live fee on the Unified Billing page and do not copy a number from here. The balance can go negative in rare cases and is then charged to the card on file at the start of the month. Set Workers AI Billing to Unified on the gateway to use credits for Workers AI. Auto top-up is configured under Credits Available > Manage; ask the user before enabling it.

## Cloudflare Access and custom domains

An Access-protected custom domain adds the reserved metadata `cf.user_id`, usable for per-user spend limits. Service-token requests carry no `cf.user_id`. See `configuration/cloudflare-access` and `configuration/custom-domains`.
