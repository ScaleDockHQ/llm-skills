# Gateway and routing

> Verified against Helicone docs (gateway provider-routing, error-handling), 2026-10-11

Sources: <https://docs.helicone.ai/gateway/provider-routing>, <https://docs.helicone.ai/gateway/concepts/error-handling>, <https://docs.helicone.ai/gateway/overview>.

## Default routing

Request a model and the gateway finds every provider offering it in the model registry, routes to the cheapest available provider (equal-cost providers are load balanced), and fails over on errors. Priority: your BYOK keys first, then Helicone's managed keys.

## Model string controls

| Goal                   | Model string                                                    |
| ---------------------- | --------------------------------------------------------------- |
| Lock to one provider   | `gpt-4o-mini/openai` (no failover)                              |
| Your own deployment    | `gpt-4o-mini/azure/<deployment-id>` (id from Provider Settings) |
| Ordered fallback chain | `gpt-4o-mini/azure,gpt-4o-mini/openai,gpt-4o-mini`              |
| Exclude providers      | `!openai,gpt-4o-mini` (comma list of `!provider`)               |
| Provider-neutral       | `gpt-4o-mini`                                                   |

Substitute a current model id from the registry. A locked provider or deployment never fails over, so use it for residency and compliance requirements, not for resilience.

## Failover triggers

The gateway moves to the next provider on 429 (rate limit), 401 (authentication), 400 (context length), 408 (timeout) and 5xx errors.

## Other gateway features (docs list)

Prompt management through the gateway, prompt caching across providers, reasoning, web search with the `:online` suffix on Anthropic models, the Responses API format, image generation, token-limit exception handlers (truncate, middle-out, fallback). Read `gateway/concepts/*` for each before use; availability can differ per model.

## Response headers

`Helicone-Id` (request id), `Helicone-Cache` (`HIT`/`MISS`), `Helicone-Fallback-Index`, `Helicone-RateLimit-Limit`, `Helicone-RateLimit-Remaining`, `Helicone-RateLimit-Policy`. Log `Helicone-Id` to correlate with the dashboard.
