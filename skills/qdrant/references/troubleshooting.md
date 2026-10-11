# Qdrant troubleshooting

> Verified against Qdrant v1.19.2 (docs, config.yaml), 2026-10-11

| Symptom                                            | Likely cause                                                                      | Fix                                                                     |
| -------------------------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| 401/403                                            | API key missing or read-only key used for writes                                  | Send `api-key` header; admin key for writes                             |
| Connection refused from another container          | Published on `127.0.0.1` only                                                     | Use the shared Docker network and the service name                      |
| Vector dimension mismatch error on upsert or query | Embedding model changed                                                           | Recreate the collection with the right size, re-embed                   |
| Data gone after restart                            | Storage not mounted                                                               | Mount `/qdrant/storage`                                                 |
| Container exits, permission denied on storage      | Unprivileged image or volume owner                                                | `chown` the directory to the container UID                              |
| OOM kill                                           | Vectors pinned or too large for RAM                                               | Quantize, set `memory: cold` for originals, bigger host, `docker stats` |
| Slow queries after restart                         | Cold page cache                                                                   | `cached` tier for HNSW, wait for warmup                                 |
| Slow indexing                                      | Optimizer working, small `indexing_threshold_kb` data stays unindexed until large | Check `optimizer_status` in collection info                             |
| Poor recall after quantization                     | Aggressive quantization                                                           | Enable `rescore`, raise `oversampling`, use scalar or 4-bit TurboQuant  |
| Large request rejected                             | `max_request_size_mb` 32                                                          | Smaller batches                                                         |
| Browser CORS errors or unwanted access             | `enable_cors: true` default                                                       | Restrict at the proxy                                                   |
| Cluster peers cannot join                          | 6335 blocked or auth mismatch                                                     | Open 6335 between nodes only; check `enforce_internal_auth` rollout     |

```bash
docker logs --tail 100 qdrant
curl -fsS -H "$H" http://127.0.0.1:6333/collections/docs | jq '.result|{status,optimizer_status,points_count,indexed_vectors_count}'
docker stats --no-stream qdrant
```
