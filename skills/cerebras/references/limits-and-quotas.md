# Cerebras limits, quotas and spend control

> Verified against Cerebras Inference docs (Rate Limits, Projects, Usage & Monitoring, Account & Billing, Service Tiers), 2026-10-11

## How limits work

- Measured in requests (RPM, RPH, RPD) and tokens (TPM, TPH, TPD). Whichever trips first applies.
- Applied per organization (and per project when you set project limits), and they vary per model.
- **Dual token buckets**: every organization has an uncached token limit and a total token limit (uncached plus cached). The total default is a multiple of the uncached limit. A 429 names which bucket was exceeded. Cached tokens do not count toward the uncached bucket, so prompt caching raises effective throughput.
- Token bucketing: capacity refills continuously, not at fixed intervals.
- **Pre-flight estimate**: the request is checked against input tokens plus `max_completion_tokens` (or an estimated upper bound) before it runs, then corrected afterwards. Set `max_completion_tokens` close to what you expect.

## See your real limits (do not copy numbers from docs)

The tier tables in the docs are examples and "may differ". The authoritative view is the Cloud Console, Limits page:

- "All projects" shows org-level limits; a selected project shows its project-level limits.
- Columns: model, context length, limit type (requests or tokens), quota per minute and per day; hourly only at org level.

Tiers (as documented): Free Trial has low per-minute limits plus hourly and daily token caps; Developer (Pay as You Go) removes hourly and daily caps; Enterprise limits are provisioned per organization. Purchasing credits moves you from Free Trial to Developer. Current numbers: https://inference-docs.cerebras.ai/support/rate-limits.

## Project-level limits (budget guard rails)

Two-level model: a request must fit under both the project quota and the org quota. By default a project has no explicit quota and inherits the org's. A project quota cannot exceed the org quota. Only Org Admins set them (All Projects view, Projects tab, Project Settings, per model, Save). Recommended by the docs: start conservative, watch 429 responses and graphs, adjust.

If two projects together exceed the org ceiling you still get throttled at the org level even when each is under its own limit.

## Spend control

On the pages read there is no hard monthly spend cap setting. Controls that exist:

- Prepaid credits (Billing, Pay as you go) with auto-recharge off by default: leave it off to cap spend at what you bought.
- Project limits per model (above).
- Analytics, Cost tab: spend per calendar month by model and input or output tokens (can lag by up to 10 minutes; usage under an active monthly subscription is excluded from usage-based billing). Downloadable CSV on Usage and Cached-Usage.
- Subscriptions: per-model monthly plans on the Billing page (can show Temporarily Sold Out).
- Your own gateway: LiteLLM budgets and rate limits in front of Cerebras (`llm-gateway`, `litellm`).

Pricing is on https://www.cerebras.ai/pricing and on each model page. Programmatic lookup: unverified, check the pricing page.

## Monitoring

- Console Analytics: Usage (toggle Show quotas), Cached-Usage, Cost. UTC timestamps.
- Logs: Request Logs filterable by model, key, date and status code (include the Request ID when contacting support); Audit Logs (admins only).
- Dedicated endpoints: Prometheus-compatible metrics endpoint (see https://inference-docs.cerebras.ai/capabilities/metrics).

## Handling 429

1. Read the message: uncached bucket, total bucket, requests or tokens.
2. Lower `max_completion_tokens`; trim the prompt; stabilize the prefix for caching.
3. Back off and retry (the SDK retries twice by default); add jitter in your own clients.
4. Move bursty low-priority traffic to another project or provider, or ask for higher limits via the Billing tab or support.
5. Put a fallback model from another provider behind your gateway (`cloud-llms`).

## Official links

- Rate limits: https://inference-docs.cerebras.ai/support/rate-limits
- Projects: https://inference-docs.cerebras.ai/console/projects
- Usage and monitoring: https://inference-docs.cerebras.ai/console/usage-monitoring
