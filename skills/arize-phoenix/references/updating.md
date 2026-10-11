# Phoenix: updating

> Verified against Arize Phoenix v20.21.0 (docs: self-hosting/upgrade/migrations, deployment-options/kubernetes-helm; MIGRATION.md on main), 2026-10-11

## Know what you run and what is new

```bash
curl -fsS http://localhost:6006/arize_phoenix_version                       # running server
docker inspect --format '{{index .RepoDigests 0}}' phoenix 2>/dev/null       # record the digest before upgrading
gh api repos/Arize-ai/phoenix/releases/latest --jq '.tag_name,.published_at' # tag format: arize-phoenix-vX.Y.Z
curl -fsSL https://raw.githubusercontent.com/Arize-ai/phoenix/main/MIGRATION.md | sed -n '1,60p'
```

`MIGRATION.md` lists operator-visible changes per major (for example v19.0.0 added a built-in OAuth2 authorization server and an in-process MCP server on by default; v20.0.0 added persisted agent sessions, new tables, a new `session.id` shape and idle-chat retention). Read every section between your version and the target.

## Migration rules (upstream)

- Database migrations run automatically at startup of a new **major** version and are intended to be seamless.
- **Phoenix does not downgrade the schema.** Rolling back to an older image does not undo migrations, and the older version has no down-migration code. The only safe rollback is restoring the database backup taken before the upgrade.
- Migrations are tested up and down in upstream CI; debug image variants (`-debug`) give shell access for manual runs. The CLI form is `phoenix db migrate`.

## Procedure: single host

- [ ] Read `MIGRATION.md` for the span; check env vars it adds, changes or deprecates.
- [ ] Back up: PostgreSQL `pg_dump -Fc` (or a volume snapshot); for SQLite stop the container and copy the file from `PHOENIX_WORKING_DIR`.
- [ ] Bump the pinned tag in the compose file or run command; `docker compose pull && docker compose up -d`.
- [ ] `scripts/check.sh`; open one project; send a canary trace; check `docker logs` for migration errors.
- [ ] Update client packages (`arize-phoenix-otel`, OpenInference instrumentors) separately; they are versioned independently of the server. Features such as the `x-project-name` header need server 15.5.0 or newer, OTel GenAI conversion 15.10.0 or newer.

## Procedure: Kubernetes

Large PostgreSQL databases can make a migration outlast the liveness probe and cause `CrashLoopBackOff`. Upstream's fix is to run migrations first:

```yaml
initContainers:
  - name: run-migrations
    image: arizephoenix/phoenix:20.21.0 # same tag as the main container
    command: ["phoenix", "db", "migrate"]
    env:
      - name: PHOENIX_SQL_DATABASE_URL
        valueFrom: { secretKeyRef: { name: phoenix-db-secret, key: url } }
```

Concurrent initContainers are safe (one retries and finds the database at head). Simplest rollout: `maxSurge: 0, maxUnavailable: 1`; alternatives are running `phoenix db migrate` in CI before the rollout, or a Helm `pre-upgrade` Job. Helm: `helm upgrade phoenix oci://registry-1.docker.io/arizephoenix/phoenix-helm --version <chart-version> -f values.yaml`; chart patch releases default to the latest Phoenix.

## After upgrading

- Re-run the privacy canary (`privacy-retention.md`); defaults and new features (MCP server, agent sessions) can add data stores or endpoints.
- Re-check exposed surfaces: `PHOENIX_ENABLE_MCP_SERVER`, `PHOENIX_ENABLE_OAUTH2_AUTHORIZATION_SERVER`.
- Saved filters built on changed attribute shapes may need rebuilding (v20.0.0 `session.id` for the assistant project).
