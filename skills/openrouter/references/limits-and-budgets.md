# OpenRouter limits, budgets and workspaces

> Verified against OpenRouter API v1 (docs: api_reference/limits, features/guardrails, features/workspaces, workspaces/workspace-budgets, overview/auth/management-api-keys), 2026-10-11

Three kinds of limit, distinguished by the error:

| Type          | Governs                                               | Error | Check                                                   |
| ------------- | ----------------------------------------------------- | ----- | ------------------------------------------------------- |
| Credit limits | Balance, per-key cap, in-flight spending budget       | 402   | `GET /api/v1/key` and `error.metadata.limit_source`     |
| Budget limits | Guardrail budgets, workspace budgets, key's own limit | 403   | `budgets` and `effective_budget` from `GET /api/v1/key` |
| Rate limits   | Free-model request caps, DDoS protection              | 429   | `X-RateLimit-*` and `Retry-After` headers               |

Extra accounts or keys do not raise rate limits (capacity is governed globally), but limits differ per model.

## `GET /api/v1/key`

Returns `limit`, `limit_reset`, `limit_remaining`, `usage`, `usage_daily/weekly/monthly` (UTC windows), `byok_usage*`, `include_byok_in_limit`, `is_free_tier`, `free_model_daily_requests` (`used`, `limit`, `remaining`), `budgets[]` and `effective_budget`. Each budget has `scope` (`workspace_default_member`, `workspace_default_key`, `member`, `api_key`, `workspace`, `key_limit`), `limit_usd`, `spend_usd`, `remaining_usd`, `reset_interval`, `resets_at`, `include_byok`. Call it before long tasks and stop if `effective_budget.remaining_usd` is small.

## 402 handling

`error.metadata.limit_source` tells you which:

- `openrouter_in_flight_budget`: many concurrent paid requests filled an estimate-based cap, not your balance. Transient; honor `Retry-After` and retry. The SDKs do not retry 402 on their own.
- `openrouter_key_limit`: the key's credit limit is spent; raise it or wait for `limit_reset`.
- `openrouter_credits`: balance too low, or the single request's estimate (prompt plus `max_tokens`, or the default cap when unset) exceeds the in-flight budget. Lower `max_tokens` or the prompt, or add credits.

The in-flight budget applies only to some prepaid accounts, not to free models or fully-BYOK requests.

## 403 budget errors

Raised before a provider is contacted, with `limit_source` `openrouter_guardrail_budget`, `openrouter_workspace_budget` or `openrouter_key_limit`, plus `scope`, `limit_usd`, `spend_usd` and `resets_at`. There is no `Retry-After`; retrying before `resets_at` fails the same way. Check order: guardrail budgets, then workspace budgets, then the key's own limit. Windows reset at 00:00 UTC (daily), Monday 00:00 UTC (weekly), the first of the month (monthly); lifetime workspace budgets never reset.

## 429 handling

Free (`:free`) models have per-minute and per-day request caps that depend on how many credits you have purchased in total. Read the current table in https://openrouter.ai/docs/api_reference/limits and the `free_model_daily_requests` field rather than hardcoding. Back off using `Retry-After`; do not rotate keys to evade limits.

## Workspaces and team patterns

Workspaces separate API keys, guardrails, BYOK keys, presets, plugins and observability. Everyone starts in Default. Use one workspace per environment or team. Suggested layout: a key per app per environment, a credit limit with a monthly reset on each, a guardrail with a budget and allowlist for people, and a workspace budget for the whole workspace. Capping shared agent keys is a documented best practice; see guides/best-practices/capping-shared-agent-keys and spend-controls.

## Verify

- [ ] Every key has a limit; `GET /api/v1/key` shows the expected `effective_budget`.
- [ ] 402, 403 and 429 are handled differently in client code, each branching on `limit_source` or headers rather than message text.
