# LobeHub: install (Docker Compose, server database)

> Verified against LobeHub v2.2.19 (docs: self-hosting/server-database/docker-compose, docker, migration/v2), 2026-10-11

## What v2 needs

LobeHub 2.0 supports only the server-database deployment (the older client-side PGlite mode and `NEXT_PUBLIC_SERVICE_MODE` are gone) and only Better Auth (NextAuth, Clerk and `ACCESS_CODE` are removed).

| Piece                   | Detail                                                                                                        |
| ----------------------- | ------------------------------------------------------------------------------------------------------------- |
| App                     | image `lobehub/lobehub`, port `3210`; migrations run automatically at start                                   |
| PostgreSQL 17           | `paradedb/paradedb:latest-pg17` (pgvector and pg_search for RAG and full-text search)                         |
| Object storage          | S3-compatible; the official Compose bundle ships RustFS                                                       |
| Secrets                 | `KEY_VAULTS_SECRET`, `AUTH_SECRET`, `JWKS_KEY` (required); `APP_URL`; `DATABASE_URL`; S3 keys                 |
| Gateway (newer Compose) | `lobe-gateway` service plus `GATEWAY_SERVICE_TOKEN`, `JWKS_PUBLIC_KEY`, `AGENT_GATEWAY_*`, `DEVICE_GATEWAY_*` |

The official bundle (`docker-compose/deploy/docker-compose.yml` and `.env.example` in the repo) also defines Redis, SearXNG and an Elasticsearch-based search sync. Fetch it instead of retyping it:

```bash
mkdir -p ~/lobehub && cd ~/lobehub && umask 077
curl -fsSLO https://raw.githubusercontent.com/lobehub/lobehub/HEAD/docker-compose/deploy/docker-compose.yml
curl -fsSL  https://raw.githubusercontent.com/lobehub/lobehub/HEAD/docker-compose/deploy/.env.example -o .env
```

The upstream `.env.example` ships a literal `POSTGRES_PASSWORD` and placeholder secrets. Replace every one (locally, without echoing):

```bash
# edit .env so that these are set to fresh values; generate with:
openssl rand -base64 32      # KEY_VAULTS_SECRET, AUTH_SECRET
openssl rand -hex 32         # GATEWAY_SERVICE_TOKEN
# JWKS_KEY and JWKS_PUBLIC_KEY: generate with the command in the upstream "Necessary Configuration" section.
```

Never keep the example JWKS key (its `kid` is `6823046760c5d460`): anyone could forge tokens.

Set `APP_URL` to the URL users type (`http://localhost:3210` locally, `https://your-domain` in production). `INTERNAL_APP_URL` is how the server calls itself; `http://localhost:3210` or `http://lobe:3210` for Compose. `S3_ENDPOINT` must be reachable from browsers (uploads go direct); the Compose file sets `S3_INTERNAL_ENDPOINT` for server-side access.

```bash
docker compose up -d
docker compose ps
docker logs -f lobehub      # look for "database migration pass" and "Ready"
```

Default ports: app `3210`, RustFS `9000`/`9001`, gateways `8787` (agent) and `8788` (device). Check they are free first.

## One-click script

The docs also describe an interactive setup script for Linux, macOS and WSL 2 that generates secrets and a report. It is for first deployment only; later changes edit `.env`. Read the script before piping it to a shell.

## Pinning

The shipped Compose uses `lobehub/lobehub` with no tag. Pin it in the Compose file (`lobehub/lobehub:2.2.19`; tags are published on Docker Hub alongside `latest` and `canary`) and pin `fts-search-*` services the same way, since they use the same image.

## Exposure

Put TLS in front of `3210` (and `8787` with WebSocket upgrade for the gateway) using `caddy`, `tailscale` or `cloudflare-tunnel`. Set `APP_URL` to the public URL; auth URLs are derived from request headers, so forward `Host` and `X-Forwarded-Proto` correctly.

## Bare `docker run`

Possible with an external Postgres and S3 (`docker run -p 3210:3210 --env-file lobehub.env lobehub/lobehub`), but the current Compose adds a gateway the app expects; prefer Compose.

## Official links

- Docker Compose: https://lobehub.com/docs/self-hosting/server-database/docker-compose
- Docker: https://lobehub.com/docs/self-hosting/server-database/docker
- 2.0 breaking changes: https://lobehub.com/docs/self-hosting/migration/v2/breaking-changes
- Releases: https://github.com/lobehub/lobehub/releases
