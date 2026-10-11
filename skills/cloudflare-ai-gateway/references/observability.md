# Observability and privacy

> Verified against Cloudflare AI Gateway docs (changelog through 2026-10-06), 2026-10-11

Sources: observability/logging, observability/custom-metadata, configuration/custom-costs, features/spend-limits under <https://developers.cloudflare.com/ai-gateway/>.

## Logs

Each log can hold prompt, response, provider, timestamp, status, tokens, cost, duration and user agent, plus DLP and Guardrails details. Logs are on by default per gateway. Eligibility depends on when the first gateway was created: accounts whose first gateway was created on or after 2026-09-24 follow Workers Logs pricing and retention; older accounts use Legacy Logs. Check the logging page for the current retention and limits instead of assuming.

- `cf-aig-collect-log: false` skips the whole log entry for one request; `true` forces it when gateway logging is off.
- `cf-aig-collect-log-payload: false` keeps metadata (tokens, model, provider, status, cost, duration) but drops request and response bodies. Use it for prompts with personal data.

Ask before turning payload logging on for sensitive workloads. An authenticated gateway also keeps invalid traffic out of log volume.

## Custom metadata

Tag requests with `cf-aig-metadata` (JSON of strings, numbers or booleans). Only the first five entries are kept. Metadata shows in logs, filters them and scopes spend limits. Reserved key `cf.user_id` comes from Cloudflare Access.

## Custom costs

For private or self-hosted models without public pricing, send `cf-aig-custom-cost` or configure custom costs (see `configuration/custom-costs`) so analytics and spend limits have a number to work with.

## Analytics

The dashboard shows requests, tokens, cost, errors and cache hit rate per gateway. Spend limits and cost views only cover models with known pricing, so unknown models appear without cost.
