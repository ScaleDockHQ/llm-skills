# Sizing Weaviate

> Verified against Weaviate v1.40.0 (docs weaviate/concepts/resources, compression/rq-compression, env-vars), 2026-10-11

Upstream's rule of thumb for HNSW:

```
memory ≈ 2 × (vectors × dimensions × 4 bytes)
```

Worked example from the docs: 1M vectors at 384 dims is 1536 B each, 1.5 GB raw, about 3 GB with the factor 2. A more precise at-rest estimate adds graph links: `1e6 × (1536 B + maxConnections × 10 B)`, for example about 2.2 GB with `maxConnections` 64; the factor 2 in the rule covers garbage-collection overhead during imports.

| Vectors | Dim  | raw float32 | rule of thumb (2x) |
| ------- | ---- | ----------- | ------------------ |
| 1M      | 768  | 2.9 GB      | 5.7 GB             |
| 1M      | 1024 | 3.8 GB      | 7.6 GB             |
| 10M     | 1024 | 38.1 GB     | 76.3 GB            |

## Quantization

RQ (rotational quantization): 8-bit up to 4x compression with about 98 to 99 percent recall in upstream tests (recommended), 4-bit smaller, 1-bit close to 32x with moderate recall. Also PQ, SQ and BQ docs exist. Since v1.33 `DEFAULT_QUANTIZATION` sets a default for new collections; the env-var docs say it is unset by default, while the site's `llms.txt` describes RQ8 as the default HNSW setup. These conflict, so read the collection's `vectorIndexConfig` after creating one (`GET /v1/schema/<Class>`) and set quantization explicitly. Always measure recall on your queries.

## Import safety

Weaviate can allocate faster than the Go garbage collector frees, and the kernel may OOM-kill it during very fast imports. Set `GOMEMLIMIT` (a bit below the container limit) or `LIMIT_RESOURCES=true`, and set a Docker memory limit.

## Disk

Vectors, object store, inverted indexes and backups. Plan more than the raw data size, and extra for each backup copy.
