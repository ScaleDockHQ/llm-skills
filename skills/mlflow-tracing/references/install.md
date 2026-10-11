# MLflow Tracking Server: install and run

> Verified against MLflow 3.17.0 (PyPI, ghcr.io/mlflow/mlflow:v3.17.0, mlflow.org/docs self-hosting, kubernetes-helm and docker-compose pages), 2026-10-11

Requirements: Python 3.10+ for pip installs. The tracking server serves the REST API, the trace UI and the OTLP endpoint on one port (default 5000).

## Option 1: pip (single machine, personal or small team)

```bash
python3 -m venv ~/mlflow-env && . ~/mlflow-env/bin/activate
pip install "mlflow==3.17.0"                      # pin; check the newest: curl -fsS https://pypi.org/pypi/mlflow/json | jq -r .info.version
mlflow server --host 127.0.0.1 --port 5000        # SQLite at ./mlflow.db is the default store since 3.7.0
```

- For a PostgreSQL store add the driver (`pip install psycopg2-binary`) and `--backend-store-uri postgresql://user@host:5432/mlflow` with the password in the environment or `.pgpass`, not on the command line (command lines are visible in process lists).
- Basic auth needs the extra: `pip install "mlflow[auth]==3.17.0"`; without it the server dies on start with `The MLflow basic auth app requires the Flask-WTF package`.
- Keep the process alive with systemd or a container; a minimal unit runs `ExecStart=/home/<user>/mlflow-env/bin/mlflow server --host 127.0.0.1 --port 5000 --backend-store-uri sqlite:////var/lib/mlflow/mlflow.db --default-artifact-root /var/lib/mlflow/artifacts` with `EnvironmentFile=/etc/mlflow/env` (mode `0600`) and a dedicated user.
- Apps that only send traces install the lightweight `mlflow-tracing` package instead; never both in one environment.

## Option 2: Docker (single container)

```bash
docker run -d --name mlflow --restart unless-stopped \
  -p 127.0.0.1:5000:5000 -v mlflow-data:/mlflow \
  ghcr.io/mlflow/mlflow:v3.17.0 \
  mlflow server --host 0.0.0.0 --port 5000 \
    --backend-store-uri sqlite:////mlflow/mlflow.db --default-artifact-root /mlflow/artifacts
```

Notes verified on `v3.17.0`: the image runs as root, contains the `mlflow` CLI and the OTel SDK, but **not** `psycopg2`, `boto3` or `Flask-WTF`; install what you need in a derived image rather than at every start. Publishing the port on `127.0.0.1` keeps it private; use a reverse proxy with TLS for wider access.

When clients reach the server by a name other than `localhost` or a private IP (a Docker service name, a DNS name), add `--allowed-hosts "mlflow:5000,mlflow.example.com"` or requests fail with 403 `Invalid Host header - possible DNS rebinding attack detected`.

## Option 3: Docker Compose with PostgreSQL

`assets/docker-compose.yaml` builds a small derived image (`mlflow[auth]` plus `psycopg2-binary`), runs PostgreSQL 16, requires the admin password, the Flask secret and the database password from an env file, enables basic auth and binds to loopback.

```bash
umask 077
printf 'POSTGRES_PASSWORD=%s\nMLFLOW_FLASK_SERVER_SECRET_KEY=%s\nMLFLOW_AUTH_ADMIN_PASSWORD=%s\n' \
  "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" "$(openssl rand -hex 16)" > mlflow.env
docker compose --env-file mlflow.env -f assets/docker-compose.yaml config -q && docker compose --env-file mlflow.env -f assets/docker-compose.yaml up -d --build
```

Read the admin password from `mlflow.env` yourself; do not print it into logs or chat. The upstream Compose project (`mlflow/docker-compose` in the repository: MLflow, PostgreSQL, RustFS S3) is the alternative when you want S3-compatible artifact storage; it installs `psycopg2-binary` and `boto3` at container start and ships example credentials (`s3admin`, `mlflow`) that you must replace.

## Option 4: Kubernetes (Helm)

The MLflow project publishes an official chart as an OCI artifact.

```bash
helm show values oci://ghcr.io/mlflow/charts/mlflow --version <chart version>        # chart versions track MLflow releases; list them on the mlflow org packages page
helm install mlflow oci://ghcr.io/mlflow/charts/mlflow --version <chart version> \
  --namespace mlflow --create-namespace \
  --set storage.enabled=true \
  --set mlflow.backendStoreUri="sqlite:////mlflow/mlflow.db" \
  --set mlflow.artifactsDestination="/mlflow/artifacts"
```

That quick start stores SQLite on a PVC (single replica). For production use PostgreSQL and an object store, put credentials in Kubernetes Secrets, enable TLS and the NetworkPolicy, and read the chart README for values (garbage-collection CronJob, ServiceMonitor, ingress). Prometheus metrics are optional (`--expose-prometheus`).

## Choosing

| Situation                         | Use                                                                          |
| --------------------------------- | ---------------------------------------------------------------------------- |
| One developer, laptop             | pip, loopback, SQLite                                                        |
| Small team, one VM                | Compose with PostgreSQL, reverse proxy with TLS                              |
| Cluster, several replicas of apps | Helm with PostgreSQL and object storage                                      |
| No wish to operate it             | A managed MLflow (Databricks, SageMaker, Azure ML, Nebius), see their skills |

## Verify

```bash
scripts/check.sh                                  # version, health, experiments, OTLP route
```

Open `http://127.0.0.1:5000`, create an experiment, send a test trace (`tracing.md`).

## Uninstall

```bash
docker compose --env-file mlflow.env -f assets/docker-compose.yaml down          # keeps volumes
docker compose --env-file mlflow.env -f assets/docker-compose.yaml down -v       # deletes ALL traces: only after a backup and approval
```
