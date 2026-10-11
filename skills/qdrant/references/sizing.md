# Sizing Qdrant

> Verified against Qdrant v1.19.2 (docs capacity-planning, quantization, memory-tiers), 2026-10-11

Formulas are the ones in Qdrant's capacity-planning guide. Treat results as estimates, then check real RSS after indexing. Qdrant also has an interactive Sizing Calculator at sizing.qdrant.tech.

```
base        = points × replication_factor
dense_size  = base × dimensions × bytes_per_dim     (float32 4, float16 2, uint8 1)
hnsw_size   = base × m × 2 × 4 bytes × 1.2          (m default 16)
payload     = base × avg_payload_bytes × 1.5        (disk; ×3 more if cached in RAM)
payload_idx ≈ 2 × size of indexed fields            (pinned, in RAM)
quantized   = base × dimensions × quant_bytes
```

Worked example from the docs: 2,000,000 points, 768 dims, float32 gives about 5.72 GB of dense vectors; HNSW with `m=16` about 0.29 GB; 4-bit TurboQuant (0.5 byte per dim, 8x) about 0.72 GB for quantized vectors.

| Points | Dim  | float32 vectors | + HNSW (m=16) |
| ------ | ---- | --------------- | ------------- |
| 1M     | 768  | 2.9 GB          | 3.2 GB        |
| 1M     | 1024 | 3.8 GB          | 4.1 GB        |
| 10M    | 1024 | 38.1 GB         | 38.9 GB       |

## Memory tiers (v1.19+)

Each structure takes `memory`: `pinned` (heap RAM, never evicted), `cached` (memory-mapped, warmed at startup, OS may evict), `cold` (memory-mapped, no warmup). Defaults: dense vectors `cached`, HNSW `cached`, quantized vectors `pinned` (when originals are cached) or `cold`, sparse index `pinned`, payloads `cold`, payload indexes `pinned`. `pinned` is rejected for dense vectors and payloads.

Typical RAM-saving layout: quantized vectors `pinned`, originals `cold` (used for rescoring from disk), HNSW `cached`. Disk must be fast (NVMe) for `cold` originals.

## Quantization

Scalar (int8) 4x; TurboQuant (v1.18+) 4-bit 8x (default `bits4`), 2-bit 16x, 1.5-bit about 21x, 1-bit 32x; binary up to 32x (best on high-dimensional, centered embeddings, use rescoring and oversampling); product up to 64x (lowest accuracy). Upstream suggests 4-bit TurboQuant over scalar unless you need Manhattan distance, and says to test TurboQuant on your data first. Always measure recall on your own queries.

## Disk

Plan disk for vectors, payload, indexes, WAL, and at least one snapshot per collection (a snapshot is roughly the collection's size). Keep free space well above the largest optimizer segment during indexing.
