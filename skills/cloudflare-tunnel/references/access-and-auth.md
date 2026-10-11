# Access, service tokens and API authentication

> Verified against cloudflared 2026.10.0 (docs: service tokens, origin parameters `access`, Access policies), 2026-10-11

Who authenticates what in a tunnelled LLM stack:

| Hostname                                              | Caller                          | Authentication                                                              |
| ----------------------------------------------------- | ------------------------------- | --------------------------------------------------------------------------- |
| `llm.example.com` (API)                               | SDKs, coding tools, curl        | gateway virtual key, `Authorization: Bearer ...`; **no Access application** |
| `llm.example.com` (API) when it must be behind Access | CI, agents that can add headers | Access **service token** headers plus the gateway key                       |
| `dash.example.com` (dashboards, admin UIs)            | people in browsers              | Access application with an identity policy                                  |

## Why not Access on the API hostname by default

Access redirects unauthenticated browsers to a login page. Most OpenAI-compatible clients cannot complete that flow and receive HTML instead of JSON. Service tokens solve it only for clients where you can set extra request headers (not all chat apps can). The gateway's own keys give per-client revocation, budgets and logs, which Access does not.

## Service tokens

An Access service token is a Client ID and a Client Secret. Create it under Zero Trust > Access controls > Service credentials > Service Tokens, or by `POST /accounts/$ACCOUNT_ID/access/service_tokens` (API token permission `Access: Service Tokens Write`).

- The **Client Secret is shown once.** If lost, generate a new token.
- Pick a duration; the token expires. Renew or rotate before then (the docs describe rotate, renew, disable and revoke).
- Since 2026-08-26 new secrets look like `cfast_<40 chars><8 char checksum>`; older 64-hex secrets keep working. Both use the same headers.
- Send as two headers: `CF-Access-Client-Id: <id>` and `CF-Access-Client-Secret: <secret>`.
- The Access policy action must be **Service Auth**, otherwise Access asks for an identity-provider login.
- An alternative single header exists (`read_service_tokens_from_header` on the Access application, value is a JSON object in that header). Do not point it at `Authorization`: that header carries the gateway key.
- **Strict service token authentication** (org setting): failures return 401 or 403 instead of a 302 login redirect; only Service Auth policies can authorize; no `CF_Authorization` cookie returned. Organizations created on or after 2026-10-05 have it on by default. Existing orgs: Cloudflare recommends turning it on, which also gives API clients clean errors.

Never print the secret. Keep it in a `0600` file and feed headers through `curl -K -`:

```bash
( ID=$(< ~/.config/llm-stack/cf-access.id); SECRET=$(< ~/.config/llm-stack/cf-access.secret); KEY=$(< ~/.config/llm-stack/client.key)
  printf 'header = "CF-Access-Client-Id: %s"\nheader = "CF-Access-Client-Secret: %s"\nheader = "Authorization: Bearer %s"\n' "$ID" "$SECRET" "$KEY" |
    curl -sS -K - https://llm.example.com/v1/models | jq -r '.data[].id' )
```

## Protect a dashboard

1. Zero Trust > Access controls > Applications > add a self-hosted application for `dash.example.com`; allow only your identity (email, group).
2. In `config.yml` under that ingress rule add `originRequest.access` with `required: true`, `teamName` and the application's `audTag` (see "get your AUD tag" in the Access JWT docs). cloudflared then rejects requests that lack a valid Access JWT, so someone who finds another route to the tunnel cannot bypass Access.

## What Access does not give you

- Per-model or per-key limits: use the gateway.
- Protection if you point the tunnel at a raw engine port. Always target the gateway or a loopback proxy.

## Official links

- [Service tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/)
- [Origin parameters: access](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/origin-parameters/)
- [Validating the Access JWT](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/validating-json/)
- [Policies (Service Auth)](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/)
