# Sizing Milvus

> Verified against Milvus v3.0.2 (milvus-docs v3.0.x index-explained, mmap, prerequisite-docker), 2026-10-11

Upstream's own worked example for HNSW, 1M vectors of 128 dimensions:

```
raw vectors = 1M × 128 × 4 bytes        = 512 MB
HNSW graph  = 1M × degree 32 × 4 bytes  = 128 MB
total                                   = 640 MB
```

With HNSWPQ (about 64x vector compression in the docs example) the same data is about 136 MB (128 MB graph + 8 MB compressed vectors).

General formula for planning:

```
raw      = vectors × dimensions × 4 bytes (float32)
HNSW RAM ≈ raw + vectors × degree × 4 bytes        (degree M; docs example uses 32)
IVF_FLAT ≈ raw (+ small centroid table)
IVF_SQ8  ≈ raw / 4        IVF_PQ and HNSW_PQ: much smaller, lower recall
```

| Vectors | Dim  | raw float32 | HNSW (degree 32) |
| ------- | ---- | ----------- | ---------------- |
| 1M      | 768  | 2.9 GB      | 3.0 GB           |
| 1M      | 1024 | 3.8 GB      | 3.9 GB           |
| 10M     | 1024 | 38.1 GB     | 39.4 GB          |

Add scalar fields, delta logs, growing segments and query-node overhead; the standalone minimum of 8 GB RAM and 16 GB recommendation are for the whole process set (milvus, etcd, MinIO).

## Index choices (from the index guide)

FLAT, IVF_FLAT, IVF_SQ8, IVF_PQ, IVF_RABITQ, HNSW, HNSW_SQ, HNSW_PQ, HNSW_PRQ, DISKANN (plus binary indexes BIN_FLAT, BIN_IVF_FLAT, MINHASH_LSH). Upstream guidance: HNSW for low `k` and high recall; if filters exclude over 98% of data use FLAT; if about a quarter of raw data fits in memory consider DiskANN for stable latency; mmap trades RAM for disk and is not a fix when most data is on disk. DiskANN adds IOPS pressure, so use NVMe.

## Disk

etcd needs fast disk; MinIO or local storage holds all segments and index files, which are roughly the size of the raw data plus index. Plan 2 to 3 times the raw data for segments, indexes and compaction, and more for backups.
