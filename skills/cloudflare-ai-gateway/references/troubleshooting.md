# Troubleshooting

> Verified against Cloudflare AI Gateway docs (changelog through 2026-10-06), 2026-10-11

Sources: authentication, manage-gateway, features pages, usage pages under <https://developers.cloudflare.com/ai-gateway/>. Items marked "inferred" are consequences of documented behaviour, not quoted error text.

| Symptom                                  | Cause and fix                                                                                                                                                    |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Request fails with missing authorization | Gateway has authentication on and no token was sent. REST: `Authorization: Bearer`. Provider-native: `cf-aig-authorization: Bearer`. Binding calls need neither. |
| 401 or 403 from the provider             | Provider key wrong or absent. A key on the request overrides BYOK. Check credential precedence in `setup-and-auth.md`.                                           |
| Unexpected Cloudflare credit charges     | No request key and no `default`-alias BYOK key, so the call fell through to Unified Billing. Store the key or enable Require provider credentials.               |
| 429                                      | Rate limit or spend limit rule on the gateway, or the upstream provider. Read the gateway's limits first; spend limits apply on cost, rate limits on count.      |
| Spend overshoots a limit                 | Limits are eventually consistent; concurrent bursts finish before cost is recorded. Lower the limit or add a provider-side cap.                                  |
| 404 on `dynamic/<route>`                 | The route belongs to another gateway. Send `cf-aig-gateway-id` for the owning gateway on REST.                                                                   |
| Workers AI call rejected                 | Needs the `@cf/` model prefix and `cf-aig-gateway-id`.                                                                                                           |
| Claude Code cannot connect               | Must use the Anthropic endpoint, not chat completions; `ANTHROPIC_API_KEY` must be set (to the gateway token) and the custom header carries the auth.            |
| Cache never hits                         | Caching is off by default, bodies differ in any field, or the provider auth header changed (it is part of the default key). Check `cf-aig-cache-status`.         |
| Wrong cached answers                     | A shared `cf-aig-cache-key` groups different prompts. Use a key per equivalent request.                                                                          |
| No cost in logs                          | Model has no known pricing. Send custom cost or configure custom costs. (inferred from spend-limit docs)                                                         |
| Missing prompts in logs                  | `cf-aig-collect-log-payload: false` or gateway logging off, or the account follows the newer Workers Logs rules.                                                 |
| Isolation between teams fails            | Tokens are account-scoped. Use separate accounts or the binding.                                                                                                 |
