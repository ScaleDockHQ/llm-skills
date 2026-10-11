# Phoenix: install and self-host

> Verified against Arize Phoenix v20.21.0 (docs: self-hosting/configuration, deployment-options/docker, deployment-options/terminal, deployment-options/kubernetes-helm, self-hosting/license), 2026-10-11

Phoenix is one process: web UI, GraphQL and REST API, and an OTLP collector (HTTP and gRPC). State lives in one SQL database. Licensed Elastic License 2.0; self-hosting is free and has no feature gates (upstream statement).

## Ports

| Port | Protocol | Path          | Env var                                        |
| ---- | -------- | ------------- | ---------------------------------------------- |
| 6006 | HTTP     | `/` (UI, API) | `PHOENIX_PORT`                                 |
| 6006 | HTTP     | `/v1/traces`  | `PHOENIX_PORT`                                 |
| 4317 | gRPC     | OTLP traces   | `PHOENIX_GRPC_PORT`                            |
| 9090 | HTTP     | Prometheus    | `PHOENIX_ENABLE_PROMETHEUS=true` (default off) |

`PHOENIX_HOST` defaults to `0.0.0.0`, so a bare `docker run -p` or `phoenix serve` is reachable from the network. Bind to loopback or put it behind a reverse proxy unless auth is on.

## Option 1: pip (laptop trial)

```bash
python -m venv .venv && . .venv/bin/activate
pip install arize-phoenix            # server + UI; client libraries are separate packages
PHOENIX_WORKING_DIR="$HOME/.phoenix" phoenix serve
```

Defaults to SQLite under `PHOENIX_WORKING_DIR` (`~/.phoenix/`). Without `PHOENIX_SQL_DATABASE_URL` it starts with a SQLite file in a temporary folder whose path is printed at startup.

## Option 2: Docker, one container

```bash
docker run -d --name phoenix --restart unless-stopped \
  -p 127.0.0.1:6006:6006 -p 127.0.0.1:4317:4317 \
  -e PHOENIX_WORKING_DIR=/data -e PHOENIX_TELEMETRY_ENABLED=false \
  -v phoenix-data:/data \
  arizephoenix/phoenix:20.21.0
```

- Tags: `X.Y.Z`, `X.Y`, `X` (floating major), `latest`, plus `-nonroot` and `-debug` variants. Upstream warns to pin the version for production; the compose files they ship default to the latest release.
- The `-debug` image gives shell access for manual migrations; `-nonroot` runs unprivileged (check the volume's ownership matches).
- Check the newest tag before pinning: `gh api repos/Arize-ai/phoenix/releases/latest --jq .tag_name` (the tag is `arize-phoenix-vX.Y.Z`).

## Option 3: Docker Compose with PostgreSQL

Use `assets/docker-compose.yaml`: Phoenix plus PostgreSQL 16 (upstream supports PostgreSQL 14 or newer), ports bound to loopback, password read from an env file.

```bash
umask 077
printf 'POSTGRES_PASSWORD=%s\nPHOENIX_SECRET=%s\nPHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD=%s\n' "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" "$(openssl rand -base64 18)Aa1!" > phoenix.env
docker compose --env-file phoenix.env -f assets/docker-compose.yaml up -d
scripts/check.sh
```

Database URL forms: `postgresql://user:pass@host/dbname` or `PHOENIX_POSTGRES_HOST/PORT/USER/PASSWORD/DB` separately; `PHOENIX_SQL_DATABASE_SCHEMA` selects a non-`public` schema (created if missing); `PHOENIX_SQL_DATABASE_READ_REPLICA_URL` (14.0.0+) serves read-only queries. Passwords with special characters must be URL-encoded in the URL form, which is why the separate variables are safer in shell scripts.

## Option 4: Kubernetes (Helm)

```bash
export CHART_URL=oci://registry-1.docker.io/arizephoenix/phoenix-helm
helm show chart "$CHART_URL" --version <chart-version>      # pick and pin a chart version
helm install phoenix "$CHART_URL" --version <chart-version> -f values.yaml
```

- The chart deploys with PostgreSQL by default; values are listed on the Docker Hub `arizephoenix/phoenix-helm` page (`server.port`, `database.defaultRetentionPolicyDays`, `auth.defaultAdminPassword`).
- `helm uninstall` removes everything except the PostgreSQL persistent volume claim.
- Upgrades with large databases: run migrations in an initContainer, see `updating.md`.
- Behind a reverse proxy at a sub-path, set `PHOENIX_HOST_ROOT_PATH`.

## Sizing and storage

Upstream gives no CPU or memory sizes. Start small, watch database growth, and move from SQLite to PostgreSQL when more than one writer, a Kubernetes rollout or multi-replica use is needed. SQLite needs a persistent volume; do not put it on network storage that lacks reliable file locking.

## Verify

```bash
scripts/check.sh                                   # /healthz, /readyz, version, auth probe
curl -fsS http://localhost:6006/readyz             # 200 with {} means the database answers
```

Next: `tracing.md` to send the first trace, `configuration.md` to turn on auth.
