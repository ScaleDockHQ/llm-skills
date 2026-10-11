# Migrating away from Helicone

> Verified against the Helicone and Mintlify announcements (2026-03-03) and Helicone docs, 2026-10-11

Sources: <https://www.helicone.ai/blog/joining-mintlify>, <https://www.mintlify.com/blog/mintlify-acquires-helicone>.

Helicone is in maintenance mode: security updates, new models, and bug and performance fixes continue; no new features; no announced shutdown date. A planning window is yours to choose, but do not wait for an outage.

## Inventory first

```bash
rg -n -e 'helicone' -e 'HELICONE_' -e 'ai-gateway.helicone.ai' --glob '!node_modules' .
```

List every base URL, header (`Helicone-*`) and `helicone/` model prefix in use.

## Replace by function

| You used Helicone for             | Alternatives in this repo                                          |
| --------------------------------- | ------------------------------------------------------------------ |
| Gateway, routing, fallbacks, keys | `litellm`, `bifrost`, `cloudflare-ai-gateway`, `vercel-ai-gateway` |
| Tracing, sessions, evals          | `langfuse`, `llm-observability`, `llm-evals`                       |
| Caching and rate limits           | the new gateway's own features                                     |

Install any of them with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

## Steps

- [ ] Export what you need first (requests, datasets, prompts) from the dashboard or API while the service is live.
- [ ] Stand up the replacement in parallel and send a copy or a percentage of traffic.
- [ ] Map `Helicone-User-Id`, session and property headers to the new tool's equivalents.
- [ ] Switch base URLs, remove `Helicone-*` headers and rotate the Helicone key.
- [ ] Verify cost and error rates match, then run `references/teardown.md`.
