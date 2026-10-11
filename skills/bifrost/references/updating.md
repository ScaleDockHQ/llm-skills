# Updating

> Verified against Bifrost gateway v2.2.6 and the release cadence page, 2026-10-11

Sources: <https://docs.getbifrost.ai/release-cadence>, <https://github.com/maximhq/bifrost/releases>, `/migration-guides/v2.0.0`.

Cadence: patch releases every 2 to 3 days, minor releases every 3 to 4 weeks (a rollup of patches plus non-breaking features), majors for breaking changes with a migration guide. Releases are cumulative, so skipping versions is safe. Upgrade immediately only when notes flag a high-severity CVE, data-correctness fix or production regression.

```bash
gh api repos/maximhq/bifrost/releases --jq '[.[]|select(.tag_name|startswith("transports/"))][0:3][]|.tag_name+" "+.published_at'
docker ps --filter ancestor=maximhq/bifrost --format '{{.Image}}'    # what you run now
```

Steps:

- [ ] Read notes between your version and the target; for a major, read the migration guide first (v2.0.0 and v1.5.0 exist).
- [ ] Back up app data: copy `config.db`, `logs.db` and `config.json` (SQLite) or take a PostgreSQL dump.
- [ ] Pin the new tag (`maximhq/bifrost:vX.Y.Z`), recreate the container with the same volume and env.
- [ ] Migrations run at startup; a failed migration blocks startup, so keep the old tag ready for rollback.
- [ ] Verify `GET /health` is 200 and one request per provider succeeds.
