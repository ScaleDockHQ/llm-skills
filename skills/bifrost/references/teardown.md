# Teardown

> Verified against Bifrost gateway v2.2.6, 2026-10-11

Sources: <https://docs.getbifrost.ai/deployment-guides/runtime-contract>, `/quickstart/gateway/setting-up`.

Nothing bills by the hour, but provider keys, virtual keys and stored logs persist. Ask before deleting data.

- [ ] Revoke virtual keys: `DELETE /api/governance/virtual-keys/{id}` (list first) or in the UI.
- [ ] Rotate or delete provider keys at each provider if they were pasted into the UI; remove `env.` secrets from the platform.
- [ ] Stop the process: `docker rm -f bifrost`, or stop the npx process.
- [ ] Decide on data: the app dir holds `config.json`, `config.db`, `logs.db` and may contain prompts. Delete the volume only when the user agrees; otherwise archive it. For PostgreSQL, drop the database or schema; for a vector store, delete the cache index.
- [ ] Remove client env vars (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`) and any reverse-proxy or tunnel routes.
- [ ] Verify: nothing listens on 8080 (`curl -sS localhost:8080/health` fails) and old virtual keys are rejected.
