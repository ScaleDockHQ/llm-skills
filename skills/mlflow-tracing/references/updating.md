# Updating MLflow

> Verified against MLflow 3.17.0 (PyPI, docs self-hosting/architecture/backend-store, helm chart page, release listing), 2026-10-11

## Check versions

```bash
curl -fsS https://pypi.org/pypi/mlflow/json | jq -r .info.version         # newest
curl -fsS "$MLFLOW_URL/version"                                            # running server (needs credentials when auth is on)
pip show mlflow mlflow-tracing | grep -E '^(Name|Version)'                 # clients
```

Release notes: https://github.com/mlflow/mlflow/releases. Clients and server should be on compatible versions; upgrade the server first, then apps. Features have minimums: OTLP ingest 3.6.0, OTLP compression 3.7.0, GenAI semconv export 3.11, RBAC 3.13.0.

## Routine

1. Read the release notes between your version and the target, especially schema migrations and flag changes.
2. **Back up the database** (`pg_dump` or copy the SQLite file with the server stopped) and the artifact store.
3. Stop all MLflow servers and other writers.
4. Upgrade the package or image tag (pin it): `pip install "mlflow==<new>"` or the derived image with `MLFLOW_VERSION` and `MLFLOW_PIP_VERSION` for the Compose asset.
5. **Run the schema migration before starting the server**: `mlflow db upgrade <database-url>`. `mlflow server` fails against a database with an out-of-date schema. Migrations can cause downtime on large databases.
6. Start the server, run `scripts/check.sh`, send a canary trace.
7. Upgrade clients (`mlflow-tracing`, instrumentation packages).

Some migrations (trace analytics rollups in newer docs) have special steps: stop every writer, optional prepopulation (`mlflow db prepopulate-trace-analytics <url>`), and no mixed-version rolling upgrades. Read the backend-store page for your target version before upgrading large databases.

## Docker, Compose, Helm

- Compose asset: `MLFLOW_VERSION=v<new> MLFLOW_PIP_VERSION=<new> docker compose --env-file mlflow.env -f assets/docker-compose.yaml up -d --build`, then run `mlflow db upgrade` in a one-off container if the server reports an outdated schema: `docker compose ... run --rm mlflow mlflow db upgrade "postgresql://mlflow:<password>@postgres:5432/mlflow"` (pass the password through the environment, not shell history).
- Helm: `helm upgrade mlflow oci://ghcr.io/mlflow/charts/mlflow --version <chart version> --reuse-values -n mlflow` after checking `helm show values` for changes; chart versions follow MLflow releases.

## Rollback

Downgrading code does not undo schema changes. Restore the database backup taken in step 2, or use the documented schema downgrade (stop writers, back up first). Archived traces stay in the archive location and cannot be moved back.
