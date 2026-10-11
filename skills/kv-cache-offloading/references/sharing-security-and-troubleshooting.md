# KV Cache Offloading: Sharing, Security, Sizing and Troubleshooting

> Verified against vLLM v0.31.0 (kv_offloading_usage docs, vllm/config/cache.py), SGLang v0.5.21 (HiCache design docs), TensorRT-LLM v1.2.1 (features/kvcache), llama.cpp master tools/server/README.md, 2026-10-11

Flags are in `engine-matrix.md`. This page covers who can see cached KV, how to size tiers and what to do when hits stay low.

## Tier scope: who can hit what

| Engine and tier                       | Scope                                                                                                                                                                    |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| SGLang L1 (GPU) and L2 (host)         | One instance only, even for two instances on the same node.                                                                                                              |
| SGLang L3                             | Whatever the backend spans: node-local for `file` on `/tmp/hicache`, cluster-wide for `mooncake`, `hf3fs`, `nixl`, `aibrix` when every instance uses the same namespace. |
| vLLM native CPU tier                  | One engine instance.                                                                                                                                                     |
| vLLM `fs` tier                        | Every instance pointing at the same `root_dir` with the same model, block size, parallelism and dtype shares blocks.                                                     |
| vLLM `obj` tier                       | Every instance using the same bucket and prefix.                                                                                                                         |
| vLLM `p2p` tier                       | Peers chosen per request by the orchestrator.                                                                                                                            |
| LMCache MP server                     | Every vLLM instance connected to that server (default port 5555 on localhost).                                                                                           |
| TensorRT-LLM host cache               | One engine; reuse is limited to requests with the same `cache_salt`, if used.                                                                                            |
| llama.cpp slot files and prompt cache | The server process, and anyone with access to `--slot-save-path`.                                                                                                        |

To reuse across instances you need a shared tier plus routing that sends a request to an instance that can reach its blocks (see the `prefix-aware-routing` skill).

## Security

Cached KV is a lossy-to-recover but real encoding of prompts, and hits are faster than misses, which is observable.

- **Shared tiers across tenants.** Do not share a CPU, disk, object or remote tier between mutually untrusted tenants unless keys are isolated. TensorRT-LLM provides `cache_salt` per request (user ID, tenant ID or hash); upstream calls out prompt theft attacks. For other engines use separate instances, directories, buckets or namespaces per tenant.
- **Hash algorithm.** vLLM's default `--prefix-caching-hash-algo sha256` is chosen to avoid collisions. Non-cryptographic `xxhash` and `xxhash_cbor` raise collision risk that, per the upstream text, can cause undefined behavior or leak private information in multi-tenant environments. Keep `sha256` unless every user is trusted.
- **Predictable seeds.** For vLLM shared `fs`, `obj` and `p2p` tiers, `NONE_HASH` derives from a fixed default seed so identical content produces identical keys across instances. With `xxhash` variants the seed is random per process; sharing then needs the same `PYTHONHASHSEED` on every instance, which makes keys predictable to anyone who knows it. Treat the seed as a secret and set it from a `0600` file or the secret store, never inline in a command that logs.
- **Data at rest.** `fs` roots, TabbyAPI `disk_cache_dir`, llama.cpp `--slot-save-path` and SGLang `file` backends hold prompt-derived data. Use a directory owned by the service user with mode `0700`, encrypted storage where policy requires it, a size budget, and a deletion routine. Do not place them in world-writable paths such as the default `/tmp/hicache`.
- **Object-store credentials.** Prefer workload identity (vLLM `obj` tier falls back to the AWS SDK default chain when `access_key` and `secret_key` are empty) or `0600` files. Never paste keys in a command.
- **P2P and control sockets.** vLLM P2P binds a control socket, loopback by default. Bind only to a private routable address and firewall the port. LMCache's ZMQ (5555) and HTTP (8080) endpoints, including `POST /clear-cache`, have no auth documented in the quickstart: keep them on localhost or a private network.
- **Clearing.** LMCache `POST /clear-cache` clears L1. For vLLM `fs` and `obj` tiers, delete the digest directory or prefix. Do it before decommissioning a tenant or after a leak.

## Sizing

- vLLM single tier: set `cpu_bytes_to_use` (or `--kv-offloading-size`, in GiB) larger than the aggregate GPU KV cache; otherwise it only mirrors the GPU. It is the total across workers.
- SGLang: `--hicache-size` is per rank in GB. Eight ranks at 30 GB reserve 240 GB. `--hicache-ratio` must be above 1. Returns diminish once hot prefixes are cached.
- TensorRT-LLM: `host_cache_size` is bytes. Default 0.
- llama.cpp: `-cram` is MiB per server, default 8192.
- TabbyAPI: `sysmem_kv_cache` and `disk_cache_size` are MB.
- Pinned host memory is page-locked: check `ulimit -l`, container memory limits and NUMA locality (GPU and RAM on the same node) before reserving large amounts.
- KV bytes per token = `2 x layers x kv_heads x head_dim x bytes_per_element`, so offload tier capacity in tokens scales with the cache dtype (see `kv-cache-quantization`). A 100 GiB tier of 128 KiB-per-token KV holds roughly 800k tokens (illustrative).
- Disk and network tiers add I/O latency to the prefill path; vLLM notes reads are latency-sensitive there.

## Troubleshooting

| Symptom                                  | Likely cause                                                                                                                                                  | Action                                                                                                                  |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Offload counters stay at zero            | Size not set (vLLM needs `--kv-offloading-size` or `cpu_bytes_to_use`), feature flag missing (SGLang `--enable-hierarchical-cache`), or engine ignored a tier | Re-read startup logs; confirm the flag reached the process with `ps`.                                                   |
| Hit rate low although tier is on         | No reuse in traffic, prefixes differ by a few tokens (timestamps, ids early in the prompt), or requests land on different instances                           | Move variable text to the end; add prefix-aware routing; check the hit counters.                                        |
| vLLM tier large but no gain              | CPU tier smaller than the GPU cache only mirrors it                                                                                                           | Raise it above aggregate GPU KV.                                                                                        |
| TTFT worse after enabling                | Slow tier on the prefill path, small chunks, or too much transfer                                                                                             | Use CPU before disk; raise `block_size` or `blocks_per_chunk`; for SGLang prefer `kernel` I/O backend and `page_first`. |
| SGLang `page_first` rejected or switched | `page_first` needs the `kernel` I/O backend                                                                                                                   | Use `page_first_direct` with `direct`, or switch the backend.                                                           |
| vLLM cross-host P2P cannot connect       | `localhost` default binds loopback                                                                                                                            | Set `VLLM_P2P_SIDE_CHANNEL_HOST` to the routable IP.                                                                    |
| vLLM `obj` tier fails at startup         | Unreachable bucket or endpoint                                                                                                                                | Fix `endpoint_override`, `scheme`, credentials; upstream fails fast.                                                    |
| Cache not shared between instances       | Different model, block size, parallelism or dtype changes the digest directory                                                                                | Align those settings or use the same namespace; remember `xxhash` needs a shared `PYTHONHASHSEED`.                      |
| Out-of-memory on host                    | Reservation exceeds free RAM or container limit                                                                                                               | Lower the size; check `free -g` and cgroup limits.                                                                      |
| Output differs between cold and warm run | Batch-shape effects (llama.cpp documents this for `cache_prompt`) or a lossy option                                                                           | Run baseline-vs-baseline for the noise floor, then the gate.                                                            |
| llama.cpp very slow after `-nkvo`        | KV now lives in host RAM                                                                                                                                      | Remove `-nkvo`; it is not a reuse tier.                                                                                 |

## Sources

- https://github.com/vllm-project/vllm/blob/v0.31.0/docs/features/kv_offloading_usage.md
- https://github.com/vllm-project/vllm/blob/v0.31.0/vllm/config/cache.py
- https://docs.sglang.ai/advanced_features/hicache_design.html
- https://github.com/NVIDIA/TensorRT-LLM/blob/v1.2.1/docs/source/features/kvcache.md
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://docs.lmcache.ai/mp/quickstart.html
