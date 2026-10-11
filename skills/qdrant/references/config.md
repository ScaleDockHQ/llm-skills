# Qdrant configuration

> Verified against Qdrant v1.19.2 (config/config.yaml on master, docs memory-tiers, installation), 2026-10-11

Defaults printed by the shipped `config/config.yaml`:

| Key                                                | Default                                               |
| -------------------------------------------------- | ----------------------------------------------------- |
| `storage.storage_path` / `snapshots_path`          | `./storage`, `./snapshots` (images use `/qdrant/...`) |
| `storage.on_disk_payload`                          | true                                                  |
| `storage.optimizers.indexing_threshold_kb`         | 10000                                                 |
| `storage.hnsw_index.m` / `ef_construct`            | 16 / 100                                              |
| `storage.hnsw_index.on_disk`                       | false                                                 |
| `storage.wal.wal_capacity_mb`                      | 32                                                    |
| `storage.performance.max_search_threads`           | 0 (auto)                                              |
| `service.host`                                     | `0.0.0.0`                                             |
| `service.http_port` / `grpc_port`                  | 6333 / 6334                                           |
| `service.max_request_size_mb`                      | 32                                                    |
| `service.enable_cors`                              | true                                                  |
| `service.enable_tls`                               | false                                                 |
| `service.api_key`, `read_only_api_key`, `jwt_rbac` | unset                                                 |
| `cluster.enabled`                                  | false (p2p port 6335)                                 |
| `telemetry_disabled`                               | false                                                 |

Override any key with `QDRANT__SECTION__KEY` (double underscores), for example `QDRANT__SERVICE__HOST`, `QDRANT__TELEMETRY_DISABLED=true`, `QDRANT__STORAGE__PERFORMANCE__MAX_SEARCH_THREADS`. `service.enable_cors: true` by default: restrict access at the proxy if a browser can reach the port.

## Per-collection settings (set at creation or update)

- `vectors.size`, `vectors.distance` (`Cosine`, `Dot`, `Euclid`, `Manhattan`): fixed at creation.
- `memory` per structure (v1.19+): `pinned`, `cached`, `cold` (`references/sizing.md`). Older versions use `on_disk` flags (the docs have a Legacy Settings mapping).
- `quantization_config`: scalar, binary, product or TurboQuant.
- `hnsw_config.m`, `ef_construct`: higher is better recall, more memory and build time.
- Payload indexes (`PUT /collections/{c}/index`) only on fields you filter on.
- `replication_factor`, `shard_number` for clusters.

Search-time: `hnsw_ef`, `exact`, quantization `rescore` and `oversampling`.
