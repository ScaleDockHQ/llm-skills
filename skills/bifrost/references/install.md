# Install

> Verified against Bifrost gateway v2.2.6 (docker image maximhq/bifrost:v2.2.6, npm wrapper @maximhq/bifrost 1.6.3), 2026-10-11

Sources: <https://docs.getbifrost.ai/quickstart/gateway/setting-up>, <https://docs.getbifrost.ai/deployment-guides/runtime-contract>, <https://github.com/maximhq/bifrost> (Apache-2.0).

## npx (local evaluation)

```bash
npx -y @maximhq/bifrost                              # latest, port 8080, binds localhost
npx -y @maximhq/bifrost --transport-version v2.2.6   # pin the gateway build
npx -y @maximhq/bifrost -app-dir ./bifrost-data -port 8080 -host 127.0.0.1
```

The wrapper's own npm version differs from the gateway version; `--transport-version` selects the gateway release. App data defaults to `~/.config/bifrost` on Linux and macOS.

## Docker

```bash
docker pull maximhq/bifrost:v2.2.6                   # pin; also -amd64 and -arm64 tags, and -ubi9 variants
docker run -d --name bifrost -p 127.0.0.1:8080:8080 -v "$PWD/data:/app/data" maximhq/bifrost:v2.2.6
```

The image supports linux/amd64 and linux/arm64, runs as user 1000, listens on 8080 and stores data under `/app/data`. Its entrypoint reads `APP_HOST` (default `0.0.0.0`), `APP_PORT` (8080), `APP_DIR` (`/app/data`), `LOG_LEVEL` (info), `LOG_STYLE` (json). Keep the supplied entrypoint. `assets/docker-compose.yaml` is a ready template.

Publishing `-p 8080:8080` exposes the dashboard and admin API on all interfaces; publish to `127.0.0.1` and put TLS and auth in front (`caddy`, `cloudflare-tunnel`, `tailscale`) unless the user wants otherwise.

## Storage

| Store        | Options                                      | Notes                                                 |
| ------------ | -------------------------------------------- | ----------------------------------------------------- |
| config store | SQLite (default, `config.db`) or PostgreSQL  | SQLite works for one process with a persistent volume |
| logs store   | SQLite (`logs.db`), PostgreSQL or ClickHouse |                                                       |
| vector store | needed for semantic cache                    | Redis/Valkey, Weaviate, Qdrant, Pinecone              |

PostgreSQL must be 16 or newer; startup fails otherwise. Migrations run at startup under an advisory lock. Each pool defaults to 50 max open and 5 idle connections per process. When both stores use PostgreSQL no SQLite files are created. Verify a database with `psql "host=... sslmode=require" -c "SHOW server_version;"`.

## Kubernetes and cloud

Official Helm chart (`deployment-guides/helm`), EKS, GKE, AKS, ECS, Cloud Run, Fly, Render and Railway guides exist. Probe `GET /health` (200 when ready), metrics at `GET /metrics`, set `BIFROST_ENCRYPTION_KEY` to a stable secret, and keep one replica for OSS. Read `deployment-guides/runtime-contract` first; do not copy chart values from memory.

## Verify

```bash
curl -fsS http://localhost:8080/health && echo healthy
open http://localhost:8080        # or xdg-open on Linux
```
