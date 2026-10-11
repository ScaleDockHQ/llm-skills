# Operating the gateway

> Verified against LiteLLM v1.105.0 (docs: proxy/release_cycle, proxy/prod, proxy/deploy, proxy/health, proxy/debugging) and Docker CLI behavior, 2026-10-11

## What it covers

Pinning, upgrades with rollback, database migrations, backups, logs and health monitoring for a Docker Compose LiteLLM deployment. Kubernetes and Terraform paths are in the upstream production guide.

## Pin the image

- LiteLLM ships a stable release every week (minor bump), with patch releases for hotfixes; release candidates (`-rc.N`) and nightlies (`-dev.N`) also exist. Pin a stable tag such as `ghcr.io/berriai/litellm:v1.105.0`; never `latest`, `main-latest` or `main-stable` for shared deployments.
- A tag can in theory be re-pushed; a digest cannot. Record the digest after the first pull and pin both:

```bash
docker pull ghcr.io/berriai/litellm:v1.105.0
docker image inspect ghcr.io/berriai/litellm:v1.105.0 --format '{{join .RepoDigests "\n"}}'
# then in compose: image: ghcr.io/berriai/litellm:v1.105.0@sha256:<digest>
```

- Find the newest stable tag: `curl -fsS https://api.github.com/repos/BerriAI/litellm/releases/latest | jq -r .tag_name`.

## Upgrade with rollback

1. Read release notes for every version between current and target (GitHub releases, LiteLLM release notes). Look for breaking changes, removed config keys and migration notes.
2. Record what runs now: `docker compose images litellm` and the digest as above. Save it next to the compose file.
3. Back up Postgres (below). Migrations are forward-only.
4. Capture a baseline: latency and success for one chat, one stream and one tool call per alias.
5. Bump the tag (and digest) in compose, then `docker compose pull litellm && docker compose up -d litellm`.
6. Watch `docker compose logs -f litellm` until the server reports it is listening; check `/health/readiness` shows `"db": "connected"`.
7. Re-run the baseline. On regression, restore the old image line and `docker compose up -d litellm`. If the new version migrated the schema and the old one fails against it, restore the DB backup taken in step 3.

Do not jump many versions at once on a busy gateway; step through releases that carry migrations.

## Database migrations

- LiteLLM runs `prisma migrate deploy` on startup by default, applying migrations shipped with the version you start.
- With several replicas, let one job run migrations and set `DISABLE_SCHEMA_UPDATE=true` on the serving containers (upstream Helm does this with a pre-sync job).
- Read-only container filesystems need `LITELLM_MIGRATION_DIR` pointed at a writable path.

## Backups

```bash
docker compose exec -T db pg_dump -U litellm -d litellm -Fc > "litellm-$(date +%F).dump"
# restore: docker compose exec -T db pg_restore -U litellm -d litellm --clean < litellm-YYYY-MM-DD.dump
```

Back up the env file separately in your secret store; without the same `LITELLM_SALT_KEY` a restored DB's stored credentials are unreadable.

## Health and monitoring

- Liveness `GET /health/liveliness`, readiness `GET /health/readiness` (no auth, no model calls). Use these for Docker healthchecks and load balancers.
- `GET /health` with a key probes each model with a real request; enable `background_health_checks` to cache and avoid token spend on every poll.
- Prometheus `GET /metrics` when the `prometheus` callback is enabled.
- Spend and usage: Admin UI or `/global/spend/report`.

## Logs

- `docker compose logs --since 30m litellm`.
- Raise verbosity temporarily with `LITELLM_LOG=DEBUG` and a restart; revert after, since debug logs may contain prompts.
- `json_logs: true` in `litellm_settings` for log shipping.

## Exposure

- Bind to `127.0.0.1` until a TLS reverse proxy or private network is in place. Clients outside the host reach it via the proxy URL (for example `https://llm.example.com`).
- Reverse proxies must not buffer SSE and need generous read timeouts for long generations.
- Set `general_settings.health_check_details: false` when the proxy is reachable by many users.

## Known pitfalls

- `docker compose up -d` after editing only the config does not restart an unchanged container; use `docker compose restart litellm`.
- Running two LiteLLM versions against the same DB during a rolling upgrade can break when the new one migrates the schema.
- Prisma needs a writable cache dir in hardened images (`PRISMA_BINARY_CACHE_DIR`, `XDG_CACHE_HOME`).

## Official links

- Release cycle: https://docs.litellm.ai/docs/proxy/release_cycle
- Releases: https://github.com/BerriAI/litellm/releases
- Production checklist: https://docs.litellm.ai/docs/proxy/prod
- Production deployment: https://docs.litellm.ai/docs/proxy/deploy
- Health: https://docs.litellm.ai/docs/proxy/health
