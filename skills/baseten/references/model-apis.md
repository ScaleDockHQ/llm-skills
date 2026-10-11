# Baseten Model APIs

> Verified against docs.baseten.co model-apis overview, model-apis/pricing-and-limits, inference/errors, organization/billing, 2026-10-11

Model APIs are hosted open models you call per token, with no deployment. The catalog changes, so discover it instead of copying names.

## Discover models and limits

```bash
baseten model-api list
baseten model-api describe --model <slug>
curl -sS https://inference.baseten.co/v1/models -H "Authorization: Bearer $BASETEN_API_KEY" | jq '.data[].id'
```

The `/v1/models` catalog can differ from the limits actually enforced. `GET https://api.baseten.co/v1/model_apis/{name}` returns the effective limits for your account. Prices, context lengths and tier limits are on the pricing-and-limits page: https://docs.baseten.co/model-apis/pricing-and-limits. Do not copy numbers from here.

## Endpoints

| API                       | Base URL                          | Path                |
| ------------------------- | --------------------------------- | ------------------- |
| OpenAI Chat Completions   | `https://inference.baseten.co/v1` | `/chat/completions` |
| Anthropic Messages (beta) | `https://inference.baseten.co`    | `/v1/messages`      |

```bash
curl -sS https://inference.baseten.co/v1/chat/completions \
  -H "Authorization: Bearer $BASETEN_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"<slug from model-api list>","messages":[{"role":"user","content":"ping"}],"max_tokens":16}'
baseten model-api predict --model <slug> --content "ping"
```

With the Anthropic SDK, set the base URL to the host above and override default headers so `Authorization: Bearer ...` is sent.

## Features

- All Model APIs support tool calling, structured outputs and JSON mode. Reasoning, vision and sampling options vary per model: check `model-api describe`.
- Session affinity: send `x-session-affinity: <id>` so related requests reuse cache. The docs recommend staying around 60 requests per minute per session, check the page for the current figure.
- Web search is early access.

## Rate limits

- Limits are requests per minute plus tokens per minute, either combined or split into uncached input and output (early access). Tier defaults are in the pricing-and-limits table.
- Response headers: `x-ratelimit-limit-requests`, `x-ratelimit-remaining-requests`, and the matching `-tokens`, `-uncached-input-tokens`, `-output-tokens` variants. A client should back off on 429 and read these.
- Errors: 400, 401, 402 (billing), 404, 429, 500, 529 (overloaded, honour `Retry-After`).

## Budget and usage

- Set a monthly budget in the dashboard: emails at 75%, 90% and 100%.
- "Enforce budget" rejects Model API requests once the budget is hit. It does not stop dedicated deployments or training jobs.
- Usage and cost:

```bash
baseten model-api usage --start 2026-10-01 --end 2026-10-11
baseten org billing usage --jq '.model_apis_usage.total'
curl -sS https://api.baseten.co/v1/model_apis/usage -H "Authorization: Bearer $BASETEN_API_KEY"   # 92-day retention
```

REST cost endpoints: `GET /v1/billing/model_apis`, `GET /v1/billing/usage_summary`. Prometheus metrics: `baseten_model_api_tokens_total`, `baseten_model_api_inference_requests_total`.

## Streaming

Chat streaming ends with `data: [DONE]`. Anthropic-style streams end with `event: message_stop`.

## When to switch to dedicated

Switch when you need private weights, a fixed model version, guaranteed capacity or a model not offered. See `references/dedicated-deploy.md`.
