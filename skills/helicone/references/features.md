# Observability, caching and rate limits

> Verified against Helicone docs (caching, custom rate limits, sessions, custom properties, header directory), 2026-10-11

Sources: <https://docs.helicone.ai/features/advanced-usage/caching>, `/features/advanced-usage/custom-rate-limits`, `/features/sessions`, `/features/advanced-usage/custom-properties`, `/features/advanced-usage/user-metrics`, `/helicone-headers/header-directory`.

All values are strings.

## Request headers

| Header                                                                  | Purpose                                                                 |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `Helicone-Session-Id`, `Helicone-Session-Path`, `Helicone-Session-Name` | group multi-call traces; path like `/plan/step-1`                       |
| `Helicone-User-Id`                                                      | per-user metrics; required for per-user rate limits                     |
| `Helicone-Property-<Name>`                                              | custom properties, for example `Helicone-Property-Environment: staging` |
| `Helicone-Cache-Enabled: true`                                          | turn caching on                                                         |
| `Cache-Control: max-age=3600`                                           | cache duration (default `max-age=604800`, 7 days)                       |
| `Helicone-Cache-Bucket-Max-Size`                                        | number of distinct responses stored per request (default 1)             |
| `Helicone-Cache-Seed`                                                   | separate cache namespace, for example per user                          |
| `Helicone-Cache-Ignore-Keys`                                            | exclude body fields from the key                                        |
| `Helicone-Retry-Enabled`                                                | proxy-side retries (see the retries docs)                               |
| `Helicone-RateLimit-Policy`                                             | `[quota];w=[seconds];u=[unit];s=[segment]`                              |

## Caching

Responses are stored on Cloudflare's edge. The key hashes the request body and relevant headers (including the authorization header), so any change makes a new entry. Separate this from provider prompt caching (`gateway/concepts/prompt-caching`). Ask before enabling caching for personalised content; use `Helicone-Cache-Seed` per user to avoid cross-user answers.

## Rate limits

```
Helicone-RateLimit-Policy: 1000;w=3600             # 1000 requests per hour
Helicone-RateLimit-Policy: 1000;w=86400;s=user      # per user (needs Helicone-User-Id)
Helicone-RateLimit-Policy: <n>;w=3600;u=cents       # by spend instead of request count
```

Segment `s=` takes `user` or `organization`; unit `u=` can be `cents`. Limits are bounded by the provider's own limits. Verify the exact unit names on the page.

## Sessions, properties, users

Sessions collect related calls into one trace and cost. Properties tag requests for filtering and cost breakdowns. User ids drive user metrics and per-user limits. Alerts, reports, datasets, webhooks and prompt management are separate features in the dashboard; read their docs before relying on them.
