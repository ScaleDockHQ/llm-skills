# Endpoints and usage

> Verified against Cloudflare AI Gateway docs (changelog through 2026-10-06), 2026-10-11

Sources: usage/rest-api, usage/chat-completion, usage/universal, usage/worker-binding-methods, usage/providers under <https://developers.cloudflare.com/ai-gateway/>.

## REST API (recommended for new work)

Base: `https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID`. Authenticate with `Authorization: Bearer $CLOUDFLARE_API_TOKEN` (a token with gateway `Run`).

| Path                           | Schema                         | Use                                          |
| ------------------------------ | ------------------------------ | -------------------------------------------- |
| `POST /ai/run`                 | envelope with `model`, `input` | every modality                               |
| `POST /ai/v1/chat/completions` | OpenAI chat                    | LLMs, OpenAI SDK                             |
| `POST /ai/v1/responses`        | OpenAI Responses               | agentic flows, model dependent               |
| `POST /ai/v1/messages`         | Anthropic Messages             | Claude clients; not Workers AI `@cf/` models |

Model names are `{provider}/{model}` such as `openai/<model>`; Workers AI models use `@cf/<author>/<model>` and need `cf-aig-gateway-id`. List live models from the models page in the docs, not from memory.

```bash
curl -sS -X POST "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/ai/v1/chat/completions" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "cf-aig-gateway-id: default" -H "Content-Type: application/json" \
  -d '{"model":"openai/<model>","messages":[{"role":"user","content":"ping"}],"max_tokens":16}' | jq '.choices[0].message.content'
```

Dynamic routes are scoped to the gateway that owns them. On REST set `cf-aig-gateway-id` to that gateway, otherwise the call resolves against `default` and returns 404. Dynamic routes accept the OpenAI chat shape only.

## Provider-native URLs

```
https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/{provider}
```

The provider's own schema and SDK work unchanged (OpenAI, Anthropic, Google AI Studio, Workers AI, Bedrock, Azure OpenAI and more; see `usage/providers`). Authenticate to the gateway with `cf-aig-authorization: Bearer <gateway token>`; send the provider key in its normal header unless BYOK or Unified Billing supplies it.

## Compat endpoint (existing integrations)

`https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/compat/chat/completions` stays working but is deprecated for single-model calls. Dynamic routes (`model: dynamic/<route>`) still work through it. The model format is `{provider}/{model}`.

## Worker binding

A Worker with an AI binding calls the gateway pre-authenticated, no `cf-aig-authorization` header needed. See `usage/worker-binding-methods` and `integrations/aig-workers-ai-binding`.

## Request headers

| Header                                                        | Purpose                                           |
| ------------------------------------------------------------- | ------------------------------------------------- |
| `cf-aig-authorization`                                        | gateway token for provider-native URLs            |
| `cf-aig-gateway-id`                                           | pick the gateway on REST; required for Workers AI |
| `cf-aig-skip-cache`                                           | bypass the cache for one request                  |
| `cf-aig-cache-ttl`                                            | per-request cache TTL (60 s to one month)         |
| `cf-aig-cache-key`                                            | custom key, also opts the request into caching    |
| `cf-aig-collect-log`                                          | override gateway log setting                      |
| `cf-aig-collect-log-payload`                                  | store or skip request and response bodies         |
| `cf-aig-metadata`                                             | JSON custom metadata, up to five entries          |
| `cf-aig-custom-cost`                                          | custom per-request cost                           |
| `cf-aig-max-attempts`, `cf-aig-retry-delay`, `cf-aig-backoff` | retries                                           |
| `cf-aig-request-timeout`                                      | first-byte timeout in ms                          |
| `cf-aig-byok-alias`                                           | pick a stored key alias on pass-through URLs      |

Old names `cf-cache-ttl` and `cf-skip-cache` still work but are replaced by the `cf-aig-` forms. Response header `cf-aig-cache-status` is `HIT` or `MISS`.

Discovery without a token: the docs index at `https://developers.cloudflare.com/ai-gateway/llms.txt` lists every page as markdown.
