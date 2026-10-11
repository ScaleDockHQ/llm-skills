# Sizing Chroma

> Verified against Chroma 1.5.9 (docs.trychroma.com deploy, performance, server env vars), 2026-10-11

Chroma's HNSW index must reside in RAM. When a collection outgrows RAM, the OS swaps and latency spikes.

## Upstream rule of thumb

For 1024-dimension embeddings, small documents and three metadata fields: `N = R * 0.245`, with N the maximum collection size in millions and R the RAM in GB. Reserve at least one more GB for the OS and server. Upstream tested this linearity up to about 7 million vectors and found no hard upper bound.

| System RAM | Approx. max collection (upstream table) |
| ---------- | --------------------------------------- |
| 2 GB       | 250,000 (below 2 GB is not recommended) |
| 4 GB       | 700,000                                 |
| 8 GB       | 1,700,000                               |
| 16 GB      | 3,600,000                               |
| 32 GB      | 7,500,000                               |
| 64 GB      | 15,000,000                              |

Scale for other dimensions: raw vectors are `N * dim * 4` bytes (float32), so 4096-dim Qwen3-Embedding-8B costs roughly 4x a 1024-dim model per vector. Treat the table as an upper bound for 1024-dim and measure your own data.

## Disk

Plan at least as much disk as RAM plus several GB. SQLite holds documents and metadata; its size depends on what you store.

## Ingest

Batches of 50 to 250 records are a good balance; throughput is flat between 100 and 500 and smaller batches have steadier latency. Upstream measured concurrent writers help. Splitting into many collections does not save memory.
