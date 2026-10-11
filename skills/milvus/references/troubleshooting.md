# Milvus troubleshooting

> Verified against Milvus v3.0.2 (docs prerequisite-docker, authenticate, mmap, index-explained; standalone compose healthcheck), 2026-10-11

| Symptom                                                 | Likely cause                                  | Fix                                                                       |
| ------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------- |
| Container not healthy for minutes                       | Start period is 90 s; etcd or MinIO not ready | `docker compose ps`, `docker logs milvus-etcd milvus-minio`               |
| Exits or crashes on start                               | CPU lacks AVX2 or required instruction sets   | Check CPU flags, use supported hardware                                   |
| etcd leader changes, timeouts                           | Slow disk                                     | NVMe; test with `fio`; etcd needs under 10 ms p99 fsync                   |
| Permission errors on `/var/lib/milvus`                  | Volume ownership                              | The upstream compose runs a `milvus-volume-init` job to chown it; keep it |
| `rpc error: unauthenticated` / auth failure             | Auth on, token missing or wrong               | `root:<password>` token; changed root password                            |
| Can still connect with `root:Milvus`                    | Default password unchanged                    | Rotate it now                                                             |
| Collection search returns nothing or error "not loaded" | Collection not loaded                         | Load it; create with an index so it auto-loads                            |
| OOM                                                     | Index plus raw data above RAM                 | Quantized index, mmap, DiskANN, more RAM (`sizing.md`)                    |
| Data lost after recreate                                | Volumes not mounted                           | Mount `/var/lib/milvus`, etcd and MinIO data                              |
| Insert dimension error                                  | Embedding model changed                       | New collection, re-embed                                                  |
| REST 404 on `/v2/vectordb/...`                          | Wrong path or old server                      | Check version and path                                                    |
| Port 9091 returns 401                                   | `adminAuthEnabled`                            | Send Basic auth and `X-Milvus-Admin-Request: true`                        |
| Upgrade fails to start                                  | Image-only change after data written          | Restore backup, follow the upgrade guide                                  |
| MinIO access denied                                     | Key mismatch between Milvus and MinIO         | Same pair in both                                                         |

```bash
docker logs --tail 100 milvus-standalone
curl -fsS http://127.0.0.1:9091/healthz
docker stats --no-stream
```
