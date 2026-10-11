# Operating the gateway

> Verified against LiteLLM v1.105.0 (docs: proxy/release_cycle, proxy/prod, proxy/deploy, proxy/health), 2026-10-11

## How it plugs into this stack

- Pin `ghcr.io/berriai/litellm:<release-tag>` (plain semver, bare or `v`-prefixed since 1.84.0) plus digest in `docker-compose.yaml`; never `latest` or `main-stable`.
- Upgrade: read release notes, record the running digest, `pg_dump` the database, bump the pin, `docker compose pull litellm && docker compose up -d litellm`, check `/health/readiness`, rerun smoke tests; on regression restore the old image line (and the DB dump if the schema migrated).
- Migrations run on startup; with several replicas run them once and set `DISABLE_SCHEMA_UPDATE=true` on serving containers.
- Back up the env file too: a restored DB is unreadable without the original `LITELLM_SALT_KEY`.
- Pitfall: `docker compose up -d` after a config-only edit does not restart the container; use `docker compose restart litellm`.

Depth: install the litellm skill (npx skills add ScaleDockHQ/llms-skills --skill litellm)
