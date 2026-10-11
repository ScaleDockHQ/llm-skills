# Open WebUI: persistence, config precedence, backup and updating

> Verified against Open WebUI v0.12.0 (docs: getting-started/updating, reference/env-configuration), 2026-10-11

## Where state lives

`/app/backend/data` (volume `open-webui` in the shipped assets) holds `webui.db` (SQLite by default), uploads, vector data and cache. Secrets and settings changed in the UI are stored in the database. Lose the volume and you lose users, chats, connections and keys.

## Persistent config: env vs UI

Variables marked "PersistentConfig" in the docs (for example `OPENAI_API_BASE_URLS`, `OPENAI_API_KEYS`, `OPENAI_API_CONFIGS`, `ENABLE_OPENAI_API`, `DEFAULT_MODELS`, RAG settings) are read from the environment on first boot only. After that, the database copy wins and changing the env var does nothing. To change:

- Edit it in the Admin UI; or
- Set `ENABLE_PERSISTENT_CONFIG=False` to make env vars win every start (UI edits then do not survive a restart); or
- Reset the database (destructive).

Non-persistent variables (for example `WEBUI_SECRET_KEY`, `WEBUI_URL` handling, `CORS_ALLOW_ORIGIN`, timeouts) are read at every start.

## Backup

```bash
# stop writers for a consistent SQLite copy
docker stop open-webui
docker run --rm -v open-webui:/data -v "$PWD":/backup alpine tar czf /backup/open-webui-$(date +%F).tgz -C /data .
docker start open-webui
```

Do this before every upgrade. Treat the archive as secret (it contains stored connection keys and chat history). For multi-user or multi-replica deployments use PostgreSQL (`DATABASE_URL`), Redis for sessions and WebSocket sync, and a shared secret key; the docs cover this under scaling.

## Update (pinned image)

```bash
docker pull ghcr.io/open-webui/open-webui:v0.12.1        # pick the release you intend (check GitHub releases)
# edit the tag in compose, then:
docker compose pull open-webui && docker compose up -d open-webui
docker logs --tail 50 open-webui                          # migrations run on start
curl -fsS http://localhost:3000/api/version | jq .
```

With `docker run`, stop and remove the container (`docker rm`) and run it again with the new tag and the same `-v`. The data volume is untouched by removing the container.

## Rolling and automatic updates

`:main` and `:latest` move unpredictably, including database migrations that older versions cannot read. Avoid automatic updaters (Watchtower and similar) for anything shared, or restrict to a patch line `:0.12`. Always back up first.

## Rollback

A newer release may migrate the database forward; to roll back, restore the backup archive and run the older tag. Starting an older image on a migrated database can fail or lose features.

## Official links

- Updating: https://docs.openwebui.com/getting-started/updating
- Environment configuration (PersistentConfig): https://docs.openwebui.com/reference/env-configuration
- Releases: https://github.com/open-webui/open-webui/releases
