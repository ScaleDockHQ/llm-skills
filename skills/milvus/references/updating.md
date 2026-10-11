# Updating and removing Milvus

> Verified against Milvus v3.0.2 (milvus-docs v3.0.x upgrade_milvus_standalone-docker), 2026-10-11

```bash
docker ps --format '{{.Names}}\t{{.Image}}' | grep -i milvus
gh api repos/milvus-io/milvus/releases/latest --jq '.tag_name,.published_at'
```

## Back up first

Copy `docker-compose.yml`, `user.yaml` and `milvus.env`, then back up data with Milvus Backup (`milvus-backup`, recommended with the Compose deployment) or stop the stack and copy `./volumes` (milvus, etcd, minio). Keep the backup until the upgrade is verified.

## Upgrade (Compose standalone)

Upstream's validated flow: save the current Compose file, confirm `docker compose ps` is healthy, change the `milvusdb/milvus` image tag, `docker compose pull standalone`, `docker compose up --detach standalone`, then verify. Read the current page: the guide covers 2.6.x to 3.0.x and notes message-queue limitations during the upgrade.

**Rollback warning (upstream):** downgrading by changing the image back is not validated; after the new version writes data an image-only rollback can fail. Restore the pre-upgrade metadata and data backups instead, and rehearse in a non-production copy.

## Teardown

```bash
docker compose --env-file ~/milvus/milvus.env -f ~/milvus/docker-compose.yml down     # keeps ./volumes
# Embedded script: bash standalone_embed.sh stop   (delete removes data: needs explicit approval)
# With explicit approval after a verified backup: rm -rf ~/milvus/volumes
```

Remove application and Open WebUI settings that point at Milvus.
