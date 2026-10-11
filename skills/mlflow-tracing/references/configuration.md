# MLflow Tracking Server: configuration

> Verified against MLflow 3.17.0 (docs self-hosting, architecture/tracking-server, security/network, security/basic-http-auth, workspaces, community/usage-tracking; live tests of OTLP ingest and basic auth against ghcr.io/mlflow/mlflow:v3.17.0), 2026-10-11

Flags come from `mlflow server --help`; most also exist as `MLFLOW_*` environment variables.

## Storage

| Setting                                | Flag                                                                             | Notes                                                                                                                                                                         |
| -------------------------------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Metadata and **trace spans**           | `--backend-store-uri`                                                            | SQLite by default since 3.7.0 (`sqlite:///mlflow.db`); PostgreSQL or MySQL for teams. The OTLP endpoint needs a SQL store; a file store (`./mlruns`) does not work for ingest |
| Artifacts (large payloads, multimodal) | `--artifacts-destination` with `--serve-artifacts`, or `--default-artifact-root` | With `--serve-artifacts` clients upload through the server and need no cloud credentials                                                                                      |
| Archived trace payloads                | `--trace-archival-config`                                                        | See `privacy-retention.md`                                                                                                                                                    |

PostgreSQL needs `psycopg2-binary` in the server environment; S3-compatible artifact stores need `boto3` and `MLFLOW_S3_ENDPOINT_URL` for non-AWS endpoints. Keep database passwords out of command lines (use environment or a secret).

## Network and Host validation

Security middleware (3.5.0+, default uvicorn server; not with `--gunicorn-opts` or `--waitress-opts`):

| Setting              | Flag / env                                                      | Default                                     |
| -------------------- | --------------------------------------------------------------- | ------------------------------------------- |
| Allowed Host headers | `--allowed-hosts` / `MLFLOW_SERVER_ALLOWED_HOSTS`               | localhost and private IPs                   |
| CORS origins         | `--cors-allowed-origins` / `MLFLOW_SERVER_CORS_ALLOWED_ORIGINS` | any localhost origin                        |
| X-Frame-Options      | `--x-frame-options` / `MLFLOW_SERVER_X_FRAME_OPTIONS`           | `SAMEORIGIN`                                |
| Disable middleware   | `--disable-security-middleware`                                 | off; only behind a proxy that does the same |

The first one bites most: a client using `http://mlflow:5000` (a Docker service name) or `https://mlflow.example.com` is rejected with HTTP 403 `Invalid Host header - possible DNS rebinding attack detected` until the exact `host:port` is in `--allowed-hosts`. Wildcards work (`*.example.com`); `*` allows everything and defeats the protection.

Bind with `--host 127.0.0.1` unless you need remote access; for remote access terminate TLS at a reverse proxy (see the `caddy` skill) and keep `--allowed-hosts` exact.

## Authentication

Off by default. The built-in basic auth:

```bash
pip install "mlflow[auth]"                       # the extra is required (Flask-WTF)
export MLFLOW_FLASK_SERVER_SECRET_KEY="<random>"  # from a 0600 env file
export MLFLOW_AUTH_ADMIN_PASSWORD="<random>"      # no default password; the first start with an empty user store creates `admin` with it
mlflow server --app-name basic-auth --host 127.0.0.1 --port 5000
```

- Tested on 3.17.0: with basic auth on, `/health` answers without credentials (healthchecks work), while `/version`, the REST API and **`/v1/traces` return 401** without credentials and reach the handler with valid ones. OTLP clients therefore send `Authorization=Basic <base64 user:password>` in `OTEL_EXPORTER_OTLP_TRACES_HEADERS` (together with `x-mlflow-experiment-id`); MLflow SDK clients use `MLFLOW_TRACKING_USERNAME` and `MLFLOW_TRACKING_PASSWORD`.
- Create a dedicated user per application and grant it permission to its experiment, rather than sharing the admin account (REST `2.0/mlflow/users/create`, `3.0/mlflow/users/permissions/grant`). RBAC with roles exists from 3.13.0; earlier versions use per-resource permissions.
- Credentials are stored in a SQL database (`basic_auth.db` by default); back it up with the rest.
- Other options: SSO, custom auth and Kubernetes patterns (docs `self-hosting/security/`). If you terminate auth at a reverse proxy, apps need the header there.

## Workspaces

`--enable-workspaces` isolates experiments, models and prompts per workspace; OTLP clients select one with `X-MLFLOW-WORKSPACE`. Enable only when you need multi-team isolation; it interacts with archival and permissions (docs `self-hosting/workspaces`).

## Telemetry

Since 3.2.0 open-source MLflow collects anonymized usage data by default. Disable with `MLFLOW_DISABLE_TELEMETRY=true` or `DO_NOT_TRACK=true`; set it **before `mlflow server`** to also stop UI telemetry, and in apps that import `mlflow`. The Compose asset sets it on the server.

## Performance and scale

- Multiple workers: `--workers N`; SQLite is fine for a single user, PostgreSQL for concurrent writers.
- Client side: async trace logging is on by default for the MLflow SDK; `MLFLOW_TRACE_SAMPLING_RATIO` samples traces (production guide).
- The opt-in server job executor supports single-replica deployments only.
- Prometheus metrics: `--expose-prometheus <dir>`.
