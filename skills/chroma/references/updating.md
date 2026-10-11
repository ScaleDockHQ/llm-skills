# Backup, update and teardown

> Verified against Chroma 1.5.9 (docs.trychroma.com deploy, performance, server env vars), 2026-10-11

## Backup

No built-in backup command was found in the OSS docs; the data is the directory mounted at `/data`. Stop writes first for a consistent copy:

```bash
docker compose stop chroma
docker run --rm -v chroma-data:/data:ro -v "$PWD":/out busybox tar czf /out/chroma-$(date +%F).tgz -C /data .
docker compose start chroma
```

Test a restore into a scratch volume. The `chroma vacuum` CLI command compacts storage; read `chroma vacuum --help` before running it and back up first.

## Update

1. Read the release notes between your tag and the target; pin the new version in compose.
2. Back up (above).
3. `docker compose pull && docker compose up -d`.
4. SQLite migrations apply on start (`sqlitedb.migration_mode: apply`); set `validate` to refuse changes. Newer data may not open with an older image, so rollback means restoring the backup.
5. Run the verification query from `SKILL.md`.

## Teardown

```bash
docker compose down            # keeps data
docker compose down -v         # DELETES the data volume; confirm and back up first
```
