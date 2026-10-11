# Langfuse: updating

> Verified against Langfuse v4.56.0 (docs: self-hosting/upgrade, upgrade/versioning, upgrade-guides/upgrade-v3-to-v4, deployment/docker-compose, deployment/kubernetes-helm; GitHub releases), Helm chart 2.1.4, 2026-10-11

## Where the project is

Langfuse v4 is the current major (v4.56.0 released 2026-10-09; releases land several times a week). v3 receives security patches until the end of January 2027. ClickHouse, Inc. acquired Langfuse in January 2026; upstream states the core stays MIT-licensed and self-hosting stays supported. The repository is active (`langfuse/langfuse`). Releases: `gh release list -R langfuse/langfuse -L 5`.

Versioning is semver. Infrastructure changes and removal of public API surface are major bumps; database schemas are not. Server and SDK majors are versioned independently; each SDK major requires a minimum server version (matrix: https://langfuse.com/self-hosting/upgrade/versioning).

## Minor and patch upgrades (within v4)

Migrations run automatically on container start. Back up Postgres and ClickHouse first (Compose has no backup tooling), and record the digests in use.

```bash
docker inspect --format '{{.Config.Image}} {{.Image}}' $(docker compose ps -q langfuse-web langfuse-worker)
# 1. edit LANGFUSE_TAG in .env to the new exact tag (for example 4.56.0 -> newer)
docker compose pull && docker compose up -d
docker compose logs -f langfuse-web langfuse-worker     # watch migrations finish, then "Ready"
LANGFUSE_HOST=http://localhost:3000 scripts/check.sh
```

Upstream's one-liner for floating tags is `docker compose up --pull always`; floating `:4` upgrades silently, so prefer exact tags in anything shared. Helm: `helm repo update && helm upgrade langfuse langfuse/langfuse -n langfuse` (pin `langfuse.image.tag` to hold the app version while chart values change).

Long-running data migrations run as background migrations and do not block start. Check them before a major upgrade: UI **Langfuse Version Tag > Background Migrations**, or `SELECT name, failed_at, failed_reason FROM background_migrations WHERE finished_at IS NULL;` in Postgres (must return zero rows before v3 to v4).

## Helm chart v1 to v2

Chart 2.0.0 replaced Bitnami sub-charts: ClickHouse via the ClickHouse Kubernetes Operator, PostgreSQL via `groundhog2k/postgres`, Valkey via `valkey-io/valkey`, object storage via SeaweedFS. Chart 2.x defaults to Langfuse v4. If you use bundled ClickHouse (`clickhouse.deploy: true`), complete the chart v1 to v2 upgrade (guide in `langfuse-k8s/examples/upgrade-v1-to-v2`, needs Langfuse >= v3.224.1) **before** the Langfuse v4 upgrade; pin `langfuse.image.tag` to your v3 image during the chart move. External ClickHouse is unaffected.

## v3 to v4 (major)

Three independent steps; each leaves a stable state.

1. **Infrastructure first, while still on v3.** Minimums: ClickHouse 25.12 (26.4 recommended), Postgres 15 (16 recommended), Redis 7.0 (7.2 recommended). Grant the v4 ClickHouse privileges to `CLICKHOUSE_USER` or migrations fail with `Not enough privileges`: `DROP VIEW`, `ALTER ADD COLUMN`, `ALTER MODIFY COLUMN`, `ALTER VIEW MODIFY QUERY`, `ALTER ADD/DROP/MATERIALIZE INDEX` on `default.*`, selected `SELECT` on `system.parts`, `system.mutations`, `system.tables`, `system.processes`, `system.query_log*`, `SYSTEM SYNC REPLICA, SYSTEM MERGES, ALTER SETTINGS` on `default.observations_pid_tid_sorting`, plus `READ ON REMOTE` and `CLUSTER ON *.*` when `CLICKHOUSE_CLUSTER_ENABLED=true`. The upgrade guide has the exact statements; copy them from there. Plan ~3x current ClickHouse disk if you will run the automated backfill.
2. **Upgrade the server** to the latest v4 after the latest v3 has finished all background migrations. v4 migrations drop superseded tables; unfinished background migrations mean permanent data loss. Snapshot Postgres and ClickHouse immediately before. There is no automatic downgrade. Pick a write mode with `LANGFUSE_MIGRATION_V4_WRITE_MODE`: `events_only` (v4 default, new tables only, incompatible SDKs rejected), `dual` (old and new tables, older SDKs via ~15 min delayed propagation), or `legacy` (v3 behaviour on v4 code; keep `LANGFUSE_BACKGROUND_MIGRATION_V4_ENABLE_HISTORIC_BACKFILL=false` while in legacy). Companion variables: `LANGFUSE_MIGRATION_V4_NATIVE_OTEL_BEHAVIOUR` (`dual_write` or `direct`), `LANGFUSE_MIGRATION_V4_ALLOW_PREVIEW_OPT_IN`.
3. **Move to the new data model.** Upgrade SDKs (Python >= 4.7.0, JS/TS >= 5.4.0), move API consumers to Observations API v2, Metrics API v2, Scores API v3 and experiments API, recreate trace-level evaluators as observation-level, switch exports to "Enriched observations", backfill history (or let a retention window roll over), then remove the migration overrides to cut over to `events_only`. `legacy` and `dual` will be removed in a later major.

In `dual` mode, probe the worker with `GET :3030/api/health?failIfEventPropagationStuck=true`. Prefer rolling forward over rolling back; if you must roll back, restore the pre-upgrade backups.

## After every upgrade

- Health and readiness green, worker logs free of migration errors.
- One test trace appears (`references/tracing.md`), one prompt fetch works.
- Re-run the privacy canary if masking, SDKs or callbacks changed (`references/privacy-retention.md`).

## Official links

- https://langfuse.com/self-hosting/upgrade
- https://langfuse.com/self-hosting/upgrade/versioning
- https://langfuse.com/self-hosting/upgrade/upgrade-guides/upgrade-v3-to-v4
- https://github.com/langfuse/langfuse/releases
- https://github.com/langfuse/langfuse-k8s
