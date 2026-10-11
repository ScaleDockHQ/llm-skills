# Langfuse: install

> Verified against Langfuse v4.56.0 (docs: self-hosting, deployment/docker-compose, deployment/kubernetes-helm; repo docker-compose.yml on main; Docker Hub tag 4.56.0), Helm chart langfuse-k8s 2.1.4, 2026-10-11

Pick one path: Langfuse Cloud (no infrastructure), Docker Compose on one VM (trial or small team, no HA, no backups), or Helm on Kubernetes (production).

## Architecture to size for

Two app containers plus four stores. Everything is required; there is no SQLite or single-container mode.

| Component                                      | Role                                                                | Minimum for v4                        |
| ---------------------------------------------- | ------------------------------------------------------------------- | ------------------------------------- |
| `langfuse-web` (`langfuse/langfuse`)           | UI, public API, OTLP endpoint (port 3000)                           | -                                     |
| `langfuse-worker` (`langfuse/langfuse-worker`) | Async ingestion from S3 into ClickHouse, evals, exports (port 3030) | -                                     |
| PostgreSQL                                     | Transactional data (users, projects, prompts, dataset items)        | 15 (16 recommended)                   |
| ClickHouse                                     | Traces, observations, scores                                        | 25.12 (26.4 recommended)              |
| Redis or Valkey                                | Queue and cache; `maxmemory-policy noeviction` is required          | 7.0 (7.2 recommended)                 |
| S3-compatible blob storage                     | Raw events first, media, batch exports                              | MinIO, SeaweedFS, S3, GCS, Azure Blob |

Ingestion path: web writes events to S3 and queues a reference in Redis; the worker reads from S3 and writes ClickHouse. A temporary ClickHouse or Postgres outage does not lose events as long as S3 and Redis are up. Upstream VM guidance for Compose: at least 4 cores, 16 GiB memory, and plenty of disk (example 100 GiB).

## Docker Compose

The upstream file is `docker-compose.yml` in `langfuse/langfuse`; this skill ships a hardened variant in `assets/docker-compose.yaml` (pinned image tag, no defaulted secrets, everything bound to `127.0.0.1`).

```bash
mkdir -p ~/langfuse && cd ~/langfuse
cp <skill>/assets/docker-compose.yaml .
<skill>/scripts/gen-env.sh            # writes ./.env mode 600 with random secrets; prints only the path
docker compose up -d
docker compose logs -f langfuse-web   # wait for "Ready" (2-3 minutes on first start)
LANGFUSE_HOST=http://localhost:3000 <skill>/scripts/check.sh
```

- Open `http://localhost:3000`. There is no default login: click **Sign up**, create the first user, then an organization and a project, then copy the project keys (`pk-lf-...`, `sk-lf-...`) from project settings. Or pre-create them with headless initialization (below).
- Image tags: `docker.io/langfuse/langfuse:4.56.0` and `docker.io/langfuse/langfuse-worker:4.56.0` exist on Docker Hub. Upstream compose uses the floating major tag `:4` from `docker.langfuse.com/langfuse/...`; that registry mirror was not independently listed here (unverified), so the skill's template uses Docker Hub. Pin an exact tag for anything shared and record the digest before upgrades.
- Ports: only `langfuse-web` (3000) and MinIO (9090 on the host) need to be reachable from outside. MinIO must be browser-reachable because browsers upload media directly to it; set `LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT` on the web container to that URL and keep `LANGFUSE_S3_MEDIA_UPLOAD_INTERNAL_ENDPOINT=http://minio:9000`. Without this, multimodal tracing fails while text traces work.
- Changing the host port: change the left side of the mapping (`3001:3000`) and update `NEXTAUTH_URL` and the media endpoint to match.
- `CLICKHOUSE_CLUSTER_ENABLED`: the documented default is `true`; the single-container Compose setup must set `false` (the template does).
- Docker's default `json-file` log driver does not rotate; set `max-size` and `max-file` in the daemon config or Compose `logging:` to avoid filling the disk. Recreate containers after changing daemon defaults.
- Stop with `docker compose down`; `-v` also deletes all data volumes.

## Headless initialization

Set the `LANGFUSE_INIT_*` variables on `langfuse-web` to create resources on first start if missing: org (`ORG_ID`, `ORG_NAME`), project (`PROJECT_ID`, `PROJECT_NAME`, `PROJECT_PUBLIC_KEY`, `PROJECT_SECRET_KEY`, optional `PROJECT_RETENTION`), user (`USER_EMAIL`, `USER_NAME`, `USER_PASSWORD`). A project needs an org; a user needs an org. In Compose, do not double-quote the values. Generate the secret key and password into the `0600` env file, never inline in shell history.

## Helm (Kubernetes)

Chart: `langfuse/langfuse` from `https://langfuse.github.io/langfuse-k8s` (chart 2.1.4 at verification). The chart is versioned independently of the server; chart 2.x ships Langfuse v4 as its default `appVersion`.

Prerequisites: Kubernetes 1.28+, and for the default bundled ClickHouse (`clickhouse.deploy: true`) cert-manager plus the ClickHouse Kubernetes Operator CRDs installed once per cluster (the chart fails fast if CRDs are missing; the chart README has the exact commands). Deployments with every store external (`*.deploy: false`) do not need the operator.

```bash
helm repo add langfuse https://langfuse.github.io/langfuse-k8s
helm repo update
kubectl create namespace langfuse
helm install langfuse langfuse/langfuse -n langfuse -f values.yaml
kubectl get pods -n langfuse                 # web and worker restart a few times while stores come up
kubectl port-forward svc/langfuse-web -n langfuse 3000:3000
```

Key `values.yaml` paths (from the chart's `values.yaml`): `langfuse.nextauth.url` (canonical public URL), `langfuse.nextauth.secret`, `langfuse.salt`, `langfuse.encryptionKey` (each accepts `value` or `secretKeyRef`; empty values are auto-generated on first install and persisted in `<release>-app`), `langfuse.image.tag`, `langfuse.replicas`, `langfuse.features.telemetryEnabled`, `langfuse.features.signUpDisabled`, `postgresql.deploy`, `redis.deploy`, `clickhouse.deploy`, `s3.deploy`. Install the release under the name `langfuse` or fix the Redis hostname in values. Prefer `secretKeyRef` over inline `value` for every secret.

Production guidance from upstream: use managed Postgres, ClickHouse and object storage (S3, GCS, Azure Blob) rather than the bundled single-instance stores; the bundled object storage is SeaweedFS.

## Cloud providers and other hosts

Upstream maintains Terraform guides for AWS, Azure and GCP; Render and Railway are community-maintained. Langfuse does not need internet access (the playground and LLM-as-judge need an LLM API you provide); it pings a cached GitHub API for update checks and fails gracefully offline.

## Other install facts

- License: MIT for the core; `ee/` directories carry a separate Enterprise license (see `references/privacy-retention.md` for what is gated).
- Version pinning and upgrade: `references/updating.md`.

## Official links

- https://langfuse.com/self-hosting
- https://langfuse.com/self-hosting/deployment/docker-compose
- https://langfuse.com/self-hosting/deployment/kubernetes-helm
- https://langfuse.com/self-hosting/administration/headless-initialization
- https://github.com/langfuse/langfuse/blob/main/docker-compose.yml
- https://github.com/langfuse/langfuse-k8s
