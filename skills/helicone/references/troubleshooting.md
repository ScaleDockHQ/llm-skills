# Troubleshooting

> Verified against Helicone docs (provider routing, error handling, caching, self-host), 2026-10-11

Sources: the pages under <https://docs.helicone.ai/>. Items marked inferred follow from documented behaviour.

| Symptom                                    | Cause and fix                                                                                                                                        |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Requests do not appear in the dashboard    | Wrong base URL or key, or you are on a legacy per-provider host. Use `https://ai-gateway.helicone.ai` and `Authorization: Bearer $HELICONE_API_KEY`. |
| Insufficient credits error                 | PTB is tried first; add credits or configure BYOK so the gateway can fall back.                                                                      |
| Unknown model                              | Not in the registry; it routes only through your BYOK deployments. Check helicone.ai/models.                                                         |
| No failover happens                        | You locked a provider or deployment in the model string, which disables failover.                                                                    |
| Excluded provider still used               | Syntax is `!provider,model` with a comma list; check spelling (inferred).                                                                            |
| Cache never hits                           | Caching is off unless `Helicone-Cache-Enabled: true`; any body or auth change is a new key; check `Helicone-Cache` in the response.                  |
| Wrong cached answers across users          | Add `Helicone-Cache-Seed` per user.                                                                                                                  |
| Per-user rate limit ignored                | `Helicone-User-Id` is required with `s=user`.                                                                                                        |
| Header ignored                             | Values must be strings; check spelling against the header directory.                                                                                 |
| Self-hosted dashboard loads, requests fail | `NEXT_PUBLIC_HELICONE_JAWN_SERVICE` and `S3_ENDPOINT` must be browser-reachable public URLs.                                                         |
| Cannot proxy through self-hosted Jawn      | `/v1/gateway/*` was removed; run the AI Gateway alongside it.                                                                                        |
| Open issues unanswered                     | Maintenance mode: only security, new-model and bug fixes are promised. Plan migration (`migration.md`).                                              |
