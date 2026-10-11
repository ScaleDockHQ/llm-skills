# Cloudflare Access service token for an API hostname

> Verified against cloudflared 2026.10.0 and Cloudflare Access service tokens docs (page updated 2026-10-02), 2026-10-11

Use when the API hostname must not be reachable by anyone without Cloudflare-issued credentials, and every caller (CI, agents, your own SDK code) can add two request headers. Callers still send the gateway key, so keys, budgets and logs keep working. Skip it for chat apps that cannot add headers.

## Steps (each dashboard or API change needs the user's approval)

1. Create a service token (Zero Trust > Access controls > Service credentials > Service Tokens). Copy the Client Secret immediately into `~/.config/llm-stack/cf-access.secret` (`chmod 600`), the Client ID into `cf-access.id`. The secret is shown once.
2. Create a self-hosted Access application for `llm.example.com`. Add a policy with action **Service Auth** that includes the token. Do not add an Allow policy for humans on the same application unless you want browser logins too.
3. Turn on **strict service token authentication** (default for orgs created on or after 2026-10-05). Failures are then 401 or 403 instead of a 302 to the login page, which SDKs can report properly.
4. Optional: add `originRequest.access` (`required: true`, `teamName`, `audTag`) to the ingress rule so cloudflared rejects anything without a valid Access JWT.
5. Clients send both headers plus the gateway key.

```bash
( ID=$(< ~/.config/llm-stack/cf-access.id); SECRET=$(< ~/.config/llm-stack/cf-access.secret); KEY=$(< ~/.config/llm-stack/client.key)
  printf 'header = "CF-Access-Client-Id: %s"\nheader = "CF-Access-Client-Secret: %s"\nheader = "Authorization: Bearer %s"\n' "$ID" "$SECRET" "$KEY" |
    curl -sS -K - -o /dev/null -w '%{http_code}\n' https://llm.example.com/v1/models )
# expect 200; without the CF headers expect 401/403 (or a 302 if strict mode is off)
```

OpenAI SDKs: pass the two headers through the client's default-headers option (check your SDK version's docs for the exact name; not verified here), and read them from files or environment variables, never literals in code.

## Pitfalls

- Token expiry: set a calendar reminder; an expired token returns 401 or 403 from Access, not from the gateway. Failed requests for recognised tokens appear in Access authentication logs.
- Do not use the single-header option on `Authorization`: it carries the gateway key.
- Streaming is unaffected by Access, but the 125 s proxy read timeout still applies (`streaming-and-timeouts.md`).
- A leaked token grants access to the Access application only; rotate it from the dashboard. The gateway key is a second layer.
