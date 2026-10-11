# Updating and removing Weaviate

> Verified against Weaviate v1.40.0 (docs deploy/configuration/backups, installation guide, releases), 2026-10-11

```bash
curl -fsS -H "Authorization: Bearer $K" http://127.0.0.1:8080/v1/meta | jq -r .version
gh api repos/weaviate/weaviate/releases/latest --jq '.tag_name,.published_at'
```

## Back up

Enable a backup module (`ENABLE_MODULES=backup-filesystem`, `BACKUP_FILESYSTEM_PATH=/var/lib/weaviate/backups`; the docs list the filesystem module for development, testing and single-node, and S3, GCS and Azure modules for others). Then:

```bash
curl -fsS -H "Authorization: Bearer $K" -H 'content-type: application/json' -X POST \
  http://127.0.0.1:8080/v1/backups/filesystem -d '{"id":"pre-upgrade-1"}' | jq .status
curl -fsS -H "Authorization: Bearer $K" http://127.0.0.1:8080/v1/backups/filesystem/pre-upgrade-1 | jq .status
```

Copy the backup directory off the host. Restore uses `POST /v1/backups/filesystem/<id>/restore` (see the backups doc for options and rules about class names).

## Upgrade

1. Read the release notes and migration notes for each version between yours and the target; upstream advises moving through minor versions in order, so check the current guidance before skipping.
2. Back up (above).
3. Change the pinned image tag, `docker compose pull && docker compose up -d`.
4. Check `/v1/.well-known/ready`, `/v1/meta` version, object counts and a test query.
5. Rollback: restore the old image only if data files were not migrated; otherwise restore the backup into a fresh instance of the old version.

## Teardown

```bash
docker compose -f ~/weaviate/docker-compose.yml down       # keeps the data volume
# With explicit approval only, after a verified backup:
# docker compose -f ~/weaviate/docker-compose.yml down -v; rm ~/weaviate/weaviate.env
```

Remove application and Open WebUI settings that point at it.
