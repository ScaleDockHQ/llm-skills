# Troubleshooting

> Verified against Bifrost gateway v2.2.6, 2026-10-11

Sources: <https://docs.getbifrost.ai/features/retries-and-fallbacks>, `/deployment-guides/runtime-contract`, `/quickstart/gateway/setting-up-auth`, `/features/semantic-caching`, `/features/governance/virtual-keys`. Items marked inferred follow from documented behaviour.

| Symptom                                      | Cause and fix                                                                                                                                  |
| -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `/health` returns 503                        | A configured config, log or vector store check failed. Check storage connectivity and PostgreSQL version (16+ required).                       |
| Startup fails after upgrade                  | Migration failure or PostgreSQL older than 16. Roll back to the previous image tag; read the logs.                                             |
| Dashboard open without a password            | No admin account yet. Enable auth with a setup token (`BIFROST_SETUP_TOKEN`). Rejected first-admin creation means the token is not configured. |
| `502 upstream_credentials_exhausted`         | Every key for the provider returned 401, 402 or 403 during the request. Fix or replace the provider keys.                                      |
| Virtual key rejected, "provider not allowed" | Virtual keys are deny-by-default; add the provider and model to `provider_configs` or use Allow all providers.                                 |
| Old-style key with `Authorization` fails     | Keys without the `sk-bf-` prefix work only via `x-bf-vk`.                                                                                      |
| Budget not enforced across replicas          | OSS holds state in memory per node; multi-node OSS is unsupported. Run one instance or use Enterprise.                                         |
| Config edits in the UI disappear             | A DB-backed `config.json` with changed rows overwrites on startup (split mode), or file-only mode ignores UI edits. Pick one source of truth.  |
| Cache never hits                             | No cache key (`x-bf-cache-key`), no vector store configured, or semantic threshold not met.                                                    |
| Retries do nothing                           | `max_retries` defaults to 0; set it in the provider's `network_config`.                                                                        |
| Claude Code uses the wrong model             | Remove the `model` field from `settings.json`; set `ANTHROPIC_DEFAULT_*_MODEL` env vars.                                                       |
| `/metrics` returns 401                       | Auth is on; give the scraper credentials.                                                                                                      |
| Container cannot be reached remotely         | `APP_HOST` and published ports: bind and publish deliberately; add TLS and auth first.                                                         |
| Self-hosted model shows no cost (inferred)   | No pricing for private models; add custom pricing (`providers/custom-pricing`).                                                                |
