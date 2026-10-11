# Weaviate troubleshooting

> Verified against Weaviate v1.40.0 (docs installation guide troubleshooting, resources, authentication), 2026-10-11

| Symptom                                         | Likely cause                                         | Fix                                                                                                                |
| ----------------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `bind: address already in use` on 8080 or 50051 | Port taken, or a stale `docker-proxy`                | Free the port, restart Docker; see the upstream installation troubleshooting section                               |
| 401 or 403                                      | Anonymous off and no key, or key not in allowed list | Send `Authorization: Bearer <key>`                                                                                 |
| Clients fail but curl works                     | gRPC port 50051 blocked or not proxied               | Publish or route both ports (HTTP and gRPC)                                                                        |
| Data gone after restart                         | No volume at `PERSISTENCE_DATA_PATH`                 | Mount a volume                                                                                                     |
| Vectorization errors on insert                  | Embeddings endpoint unreachable or wrong model name  | Test the endpoint from inside the container; fix `baseURL`, `endpoint`, `model`, key                               |
| 404 from the embeddings endpoint                | `baseURL` plus `endpoint` path mismatch              | Default appended path is `/v1/embeddings`; set `endpoint` or fix the base URL (TEI/LiteLLM serve `/v1/embeddings`) |
| `no module with name "text2vec-openai"`         | Module not enabled                                   | Add it to `ENABLE_MODULES` and restart                                                                             |
| OOM kill during import                          | GC cannot keep up                                    | `GOMEMLIMIT` or `LIMIT_RESOURCES=true`, container memory limit, slower import, quantization                        |
| High memory                                     | Uncompressed HNSW                                    | RQ or other quantization (`sizing.md`)                                                                             |
| Dimension mismatch                              | Model changed after collection creation              | New collection, re-import                                                                                          |
| Weaviate will not start with RBAC               | No root user configured (1.30.6 and older)           | Set `AUTHORIZATION_RBAC_ROOT_USERS`                                                                                |
| Backup fails                                    | Module not enabled or path not writable              | `ENABLE_MODULES`, `BACKUP_FILESYSTEM_PATH` on a volume                                                             |

```bash
docker logs --tail 100 weaviate
curl -fsS http://127.0.0.1:8080/v1/.well-known/ready -w ' %{http_code}\n'
docker stats --no-stream weaviate
```
