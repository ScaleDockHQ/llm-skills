# Troubleshooting Chroma

> Verified against Chroma 1.5.9 (docs.trychroma.com deploy, performance, server env vars), 2026-10-11

| Symptom                              | Likely cause and fix                                                                                                                         |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Connection refused on 8000           | Chroma is only on the internal network by design; use the proxy on 8001 or `docker compose exec`.                                            |
| 401 from the proxy                   | Missing or wrong `Authorization: Bearer` header; the client needs `headers=`.                                                                |
| Latency spikes, high swap            | Index larger than RAM. Check `free -g` and `references/sizing.md`; add RAM or split by instance.                                             |
| Dimension mismatch on add or query   | The collection was created with another embedder; create a new collection and re-embed.                                                      |
| Poor results with default settings   | Default space is `l2`; recreate with `cosine` if your embedder expects it.                                                                   |
| 413 or payload errors                | Batch exceeds the 40 MiB payload cap or is too large; use batches of 50 to 250.                                                              |
| Embedding call fails from the client | The embedding function runs in the client process, so the embedder URL must be reachable from the client, not from Chroma. Check `api_base`. |
| Data gone after restart              | Volume not mounted at `/data`.                                                                                                               |
| Auth settings ignored                | v1 has no built-in auth; use the proxy.                                                                                                      |

Read-only checks: `docker logs chroma --tail 100`, `curl .../api/v2/heartbeat`, `docker stats --no-stream`.
