# Updating and removing Qdrant

> Verified against Qdrant v1.19.2 (GitHub releases, docs snapshots), 2026-10-11

```bash
curl -fsS -H "api-key: $QDRANT__SERVICE__API_KEY" http://127.0.0.1:6333/ | jq -r .version
gh api repos/qdrant/qdrant/releases/latest --jq '.tag_name,.published_at'
```

## Back up

```bash
Q=http://127.0.0.1:6333; H="api-key: $QDRANT__SERVICE__API_KEY"
curl -fsS -X POST $Q/collections/docs/snapshots -H "$H" | jq .
curl -fsS $Q/collections/docs/snapshots -H "$H" | jq -r '.result[].name'
# Copy ./snapshots off the host; for full-instance backups also snapshot each collection
```

Restore into a collection with the snapshot upload endpoint (`POST /collections/{c}/snapshots/upload?priority=snapshot`) or from a URL or file, per the upstream snapshot docs.

## Upgrade

1. Read the release notes from your version to the target; Qdrant's policy on skipping minor versions was not re-read for this skill, so upgrade one minor at a time unless the release notes say otherwise.
2. Snapshot every collection and copy it off-box.
3. Change the pinned tag, `docker compose up -d`, wait for `/readyz`.
4. Check collections (`points_count`, status green) and run a known query.
5. Rollback: stop, restore the previous tag and the pre-upgrade storage copy or snapshots (a newer version may have migrated storage files).

## Teardown

```bash
docker compose -f ~/qdrant/docker-compose.yml down       # keeps ./storage
# With explicit approval only:
# rm -rf ~/qdrant/storage ~/qdrant/snapshots ~/qdrant/qdrant.env
```

Remove Open WebUI, MCP or app configs that point at it.
