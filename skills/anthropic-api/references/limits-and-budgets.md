# Anthropic API: limits, tiers and spend controls

> Verified against Claude Platform docs: Rate limits, API overview, API errors, Workspaces, 2026-10-11

## Where to see your limits (do not copy numbers)

- Console: the **Rate limits** page shows your tier and per-model limits; the **Billing** page shows your tier's monthly spend cap and lets you set your own lower limit; the **Usage** page charts token use, rate-limit headroom and cache hit rate.
- Programmatic: the docs mention a Rate Limits API for reading organization and workspace limits; find the endpoint in the Admin API reference before using it.
- Response headers on `/v1/messages`: `anthropic-ratelimit-requests-limit|remaining|reset`, `anthropic-ratelimit-tokens-*`, `anthropic-ratelimit-input-tokens-*`, `anthropic-ratelimit-output-tokens-*` (reset values are RFC 3339 timestamps), plus `retry-after` on `429`. The `tokens` headers show the most restrictive limit currently in effect.

```bash
curl -sS -D - -o /dev/null https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d "$(jq -n --arg m "$ANTHROPIC_MODEL" '{model:$m,max_tokens:16,messages:[{role:"user",content:"hi"}]}')" \
  | grep -i -E '^(anthropic-ratelimit|retry-after|request-id)'      # tiny billable call: ask first
```

## How limits work

- Two kinds: **spend limits** (monthly cost) and **rate limits** (requests per minute RPM, input tokens per minute ITPM, output tokens per minute OTPM, per model class). Exceeding any returns `429` with a `retry-after` header.
- Limits are set at organization level by **usage tier** (Start, Build, Scale, Custom); an organization is placed on a tier automatically and moves up with history. New or low-history organizations may begin in an Evaluation tier with lower limits that rise automatically.
- Token bucket algorithm: capacity replenishes continuously, so short bursts can trip limits even under the per-minute number (60 RPM may be enforced as 1 per second).
- **Cache-aware ITPM:** for most models only `input_tokens` plus `cache_creation_input_tokens` count; `cache_read_input_tokens` do not. One older model counts them. Caching therefore raises effective throughput.
- OTPM counts actual output tokens; `max_tokens` does not count toward it.
- Limits are per model, and are shared across `inference_geo` values.
- Message Batches, Files API and Managed Agents have separate limits; fast mode (research preview) has dedicated limits and `anthropic-fast-*` headers.
- **Acceleration limits:** a sharp usage increase can cause `429`s; ramp traffic gradually.

## Spend limits: two behaviors

| Cap                          | Where set                              | What the API returns                                                                                    |
| ---------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Tier monthly spend cap       | Fixed by tier; raise via tier increase | `429 rate_limit_error`, `error.details.error_code = enforced_spend_limit_reached`, **no** `retry-after` |
| Limit you set (organization) | Console > Settings > Billing           | `400 invalid_request_error`, message starts `You have reached your specified API usage limits`          |
| Limit you set (workspace)    | Console > Settings > Workspaces        | `400`, message starts `You have reached your specified workspace API usage limits`                      |

- Access resumes at 00:00 UTC on the first of the next month, or when you raise or remove the limit or move up a tier. SDK retries cannot fix these.
- Your limit cannot exceed the tier cap. The Claude Code workspace is checked separately and can return `429` with `retry-after`.

## Workspace limits

- Set per-workspace RPM, ITPM and OTPM on the Rate limits page (choose the workspace), and spend limits with alerts under Settings > Workspaces > Spend limits. Default Workspace limits cannot be set.
- Unset workspace limits match the organization's. Organization limits always apply even if workspace limits add up to more.

## Requesting more

Use **Request tier increase** on the Rate limits page, or contact support. On Claude Platform on AWS the flow differs (account representative). Include models, peak input and output TPM per model and how much input is cached.

## Cost control checklist

- [ ] User-set spend limit and alerts on every non-default workspace before traffic.
- [ ] `max_tokens` bounded; streaming for long outputs.
- [ ] Prompt caching for repeated prefixes; Batches for non-interactive work.
- [ ] Alert on `enforced_spend_limit_reached` and on `400` limit messages in the gateway.
- [ ] Prices: read the pricing page linked from the Claude docs; never hardcode.

## Where to read more

- https://platform.claude.com/docs/en/api/rate-limits
- https://platform.claude.com/docs/en/api/errors
- https://platform.claude.com/docs/en/build-with-claude/workspaces
