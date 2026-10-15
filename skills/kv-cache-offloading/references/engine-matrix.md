# KV Cache Offloading: Per-Engine Flag Matrix

> Verified against vLLM v0.31.0 (kv_offloading_usage docs, vllm/config/cache.py), LMCache multiprocess-mode docs (docs.lmcache.ai mp/quickstart), SGLang v0.5.21 (HiCache design and best-practices docs, server arguments), TensorRT-LLM v1.2.1 (features/kvcache, kv-cache-connector), llama.cpp master tools/server/README.md (release v0.6.0), TabbyAPI config_sample.yml with ExLlamaV3, TensorFold v1.0.7 (self-hosted-llms engine-tensorfold reference), Ollama docs FAQ, 2026-10-11

Every row comes from the upstream pages in the Sources list. Anything not confirmed is marked "(unverified)". Flags change between releases: run the installed engine's `--help` before applying one.

Numerics: plain offload and reload copies bytes and is not meant to change outputs, but reused KV can still differ from recomputation through batch and kernel effects. Options that reuse non-prefix KV or compress KV are lossy (marked below where known). Gate every change with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`) using the procedure in `SKILL.md`: baseline against candidate (cold and warm) on the user's eval set, a user-chosen acceptance threshold, and a rollback to the baseline launch command.

## Quick comparison

| Engine               | Mechanism                                                         | Tiers                                  | Main knobs                                                       |
| -------------------- | ----------------------------------------------------------------- | -------------------------------------- | ---------------------------------------------------------------- |
| vLLM                 | `--kv-offloading-size`, `--kv-offloading-backend native\|lmcache` | CPU                                    | size in GiB (total across TP ranks)                              |
| vLLM                 | `OffloadingConnector` via `--kv-transfer-config`                  | CPU, plus fs, obj, p2p secondary tiers | `cpu_bytes_to_use`, `block_size`, `secondary_tiers`              |
| vLLM + LMCache       | `LMCacheMPConnector` plus `lmcache server`                        | CPU (L1) and L2 adapters               | `--l1-size-gb`, `--eviction-policy`                              |
| SGLang               | HiCache (`--enable-hierarchical-cache`)                           | L1 GPU, L2 host, L3 storage            | `--hicache-ratio`, `--hicache-size`, `--hicache-storage-backend` |
| TensorRT-LLM         | `KvCacheConfig.host_cache_size`, KV Cache Connector               | GPU, host; connector for any           | `host_cache_size`, `secondary_offload_min_priority`              |
| llama.cpp            | `-cram`, `--cache-idle-slots`, `--slot-save-path`                 | RAM prompt cache, disk slot files      | `-cram` MiB, `/slots` save and restore                           |
| TabbyAPI / ExLlamaV3 | `memory.sysmem_kv_cache`, `disk_cache_dir`                        | GPU, system RAM, disk                  | MB sizes                                                         |
| TensorFold           | `--prompt-cache-gib`                                              | retained prefixes                      | GiB                                                              |
| Ollama               | none documented                                                   |                                        |                                                                  |

## vLLM v0.31.0

### Simple flags (native or LMCache backend)

- `--kv-offloading-size <GiB>`: size of the offloading buffer in GiB. Default unset, meaning no offloading. With tensor parallelism it is the total summed across ranks.
- `--kv-offloading-backend native|lmcache`: default `native` (vLLM native CPU offloading). Offloading is only active when the size is set. Whether this combines with an explicit `--kv-transfer-config` is (unverified); prefer one path.

### `OffloadingConnector` (documented configuration path)

Supports CUDA, ROCm and XPU only. Offloads completed KV blocks to pinned host memory (DMA, async alongside compute) and promotes hits back on demand.

```bash
vllm serve <model> \
  --kv-transfer-config '{
    "kv_connector": "OffloadingConnector",
    "kv_role": "kv_both",
    "kv_connector_extra_config": {"block_size": 64, "cpu_bytes_to_use": 1000000000}
  }'
```

`kv_connector_extra_config` keys:

| Key                         | Default             | Notes                                                                                          |
| --------------------------- | ------------------- | ---------------------------------------------------------------------------------------------- |
| `cpu_bytes_to_use`          | required            | Total host bytes across all workers, not per worker.                                           |
| `spec_name`                 | `CPUOffloadingSpec` | `TieringOffloadingSpec` for CPU primary plus secondary tiers.                                  |
| `block_size`                | GPU block size      | Tokens per offloaded block; multiple of the GPU block size; exclusive with `blocks_per_chunk`. |
| `blocks_per_chunk`          | `1`                 | Larger chunks mean larger I/Os.                                                                |
| `eviction_policy`           | `lru`               | `lru`, `arc`, or a custom policy via `cache_policy_module_path`.                               |
| `store_threshold`           | `0`                 | Single-tier only. Values 2 or more are rejected by the tiering spec.                           |
| `max_tracker_size`          | `64000`             | Single-tier lookup tracker.                                                                    |
| `offload_prompt_only`       | `true`              | Only prefill blocks offloaded; decode blocks skipped.                                          |
| `secondary_tiers`           | `[]`                | Ordered list, tier 0 consulted first.                                                          |
| `self_describing_kv_events` | `false`             | Richer KV events for external indexers; needs `--kv-events-config`.                            |

Secondary tiers (staged through the CPU tier; they cannot touch GPU memory directly):

- `fs`: `root_dir` (required), `n_read_threads` 16, `n_write_threads` 16. Writes `<root_dir>/<model>_<digest>/...` with per-rank subdirectories and block files named by hash. A shared `root_dir` lets instances with the same model, block size, parallelism and dtype share blocks.
- `obj`: S3-compatible through NIXL OBJ. `store_config` with `bucket`, `endpoint_override` (required), `scheme` (default `http`), `region`, `ca_bundle`, and optional explicit credentials (empty means the AWS SDK default provider chain, which allows workload identity). Optional `prefix`, `io_threads` 4. Fails fast at startup if the bucket is unreachable.
- `p2p`: RDMA via NIXL between peers. `host` defaults to `$VLLM_P2P_SIDE_CHANNEL_HOST` (`localhost`, loopback only; set the routable IP for cross-host use), `port` `$VLLM_P2P_SIDE_CHANNEL_PORT` (5710, plus DP index), `backends` `["UCX"]`, `unbound_store_timeout_s` 60. The orchestrator chooses peers through `kv_transfer_params` (`remote_decoder`, `remote_prefiller`, `remote_kv_source`).
- Out-of-tree tiers via `module_path` and a `SecondaryTierManager` class.
- `locality` (`LOCAL`/`REMOTE`) and `enable_kv_events` are metadata for KV events only.

Per-request controls in `kv_transfer_params` (both experimental): `max_offload_tokens` (cap tokens stored; `0` disables for the request) and `max_load_tokens` (cap tokens loaded; `0` disables external loading).

Related flags: `--enable-prefix-caching` (on by default), `--prefix-caching-hash-algo sha256|sha256_cbor|xxhash|xxhash_cbor` (default `sha256`; non-cryptographic hashes raise collision risk and can leak data in multi-tenant setups), `PYTHONHASHSEED` (needed to share caches when using `xxhash`/`xxhash_cbor`).

Tuning from upstream: make `cpu_bytes_to_use` larger than the aggregate GPU KV cache for single-tier setups; prefer more FS read threads when prefill hit rates are high; changing model, block size, parallelism or dtype creates a new digest directory and orphans the old one (delete to reclaim disk).

### LMCache multiprocess mode with vLLM

```bash
lmcache server --l1-size-gb 100 --eviction-policy LRU       # ZMQ port 5555, HTTP 8080 by default
vllm serve <model> --kv-transfer-config \
  '{"kv_connector":"LMCacheMPConnector","kv_role":"kv_both"}'
```

- Server flags: `--l1-size-gb`, `--eviction-policy LRU`, `--port` (default 5555), `--http-port` (default 8080), `--max-workers` (Docker example uses 4).
- vLLM side: `kv_connector_extra_config` keys `lmcache.mp.host`, `lmcache.mp.port`, `lmcache.mp.mp_transfer_mode` (`auto`, `lmcache_driven`, `engine_driven`).
- HTTP endpoints: `GET /healthcheck`, `GET /status`, `POST /clear-cache` (clears L1 including locked objects).
- Containers need `--ipc host` for CUDA IPC; the Docker docs use nightly images because MP-mode interfaces are changing.
- A CPU-only mode over POSIX shared memory exists (`engine_driven`, needs `--disable-hybrid-kv-cache-manager` and `--no-enable-prefix-caching` in the documented example).
- L2 adapters, CacheBlend-style blending and compression options: (unverified here). Anything that reuses non-prefix KV or compresses KV is lossy; gate it.

## SGLang v0.5.21 HiCache

Tiers: L1 GPU, L2 host memory (private to one instance, even on the same node), L3 storage backend (the only tier that can be shared).

| Flag                                        | Default         | Notes                                                                                                                                                                                                                    |
| ------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `--enable-hierarchical-cache`               | off             | Required for HiCache.                                                                                                                                                                                                    |
| `--hicache-ratio`                           | `2.0`           | Host pool as a multiple of the device pool. Must be above 1.                                                                                                                                                             |
| `--hicache-size`                            | `0`             | Host pool in GB per rank (8 ranks times 30 is 240 GB). Overrides the ratio when set.                                                                                                                                     |
| `--hicache-write-policy`                    | `write_through` | `write_back`, `write_through`, `write_through_selective`.                                                                                                                                                                |
| `--hicache-io-backend`                      | `kernel`        | `direct`, `kernel` (GPU-assisted, recommended), `kernel_ascend`.                                                                                                                                                         |
| `--hicache-mem-layout`                      | `page_first`    | `layer_first`, `page_first`, `page_first_direct`, `page_first_kv_split`, `page_head`. `page_first` works only with the `kernel` I/O backend and switches to `layer_first` with `direct`.                                 |
| `--hicache-storage-backend`                 | none            | `file`, `mooncake`, `hf3fs`, `nixl`, `aibrix`, `dynamic`, `eic`, `simm`.                                                                                                                                                 |
| `--hicache-storage-prefetch-policy`         | `timeout`       | `best_effort`, `wait_complete`, `timeout` (recommended for production by upstream).                                                                                                                                      |
| `--hicache-storage-backend-extra-config`    | none            | JSON string or `@file` (TOML, JSON, YAML). Keys include `prefetch_threshold` (default 256 tokens), `prefetch_timeout_base` (2 s), `prefetch_timeout_per_ki_token` (0.1 s), `prefetch_timeout_max` (30 s), `tp_lcm_size`. |
| `--page-size`                               | engine default  | Larger pages cut metadata overhead; examples use 64.                                                                                                                                                                     |
| `--enable-lmcache`, `--lmcache-config-file` | off             | LMCache as the alternative hierarchical cache.                                                                                                                                                                           |

Constraints and notes:

- `file` backend writes to `/tmp/hicache` unless `SGLANG_HICACHE_FILE_BACKEND_STORAGE_DIR` is set; it is a demonstration backend and node-local unless that path is a shared mount.
- Cluster-wide L3 sharing needs one namespace across instances (`mooncake`, `hf3fs`, `nixl`, `aibrix`). Mooncake example environment: `MOONCAKE_TE_META_DATA_SERVER`, `MOONCAKE_GLOBAL_SEGMENT_SIZE`, `MOONCAKE_PROTOCOL`, `MOONCAKE_DEVICE`, `MOONCAKE_MASTER`.
- Mixed tensor-parallel sizes sharing one L3 need `tp_lcm_size` set to the least common multiple.
- Prefill/decode disaggregation: HiCache can run on prefill nodes only, or with `--disaggregation-decode-enable-offload-kvcache` on decode nodes. The storage backend can be attached or detached at runtime through admin endpoints (see the SGLang docs).
- Not supported with SM100 native NVFP4 KV cache (see the `kv-cache-quantization` skill).

## TensorRT-LLM v1.2.1

`KvCacheConfig` (LLM API; `kv_cache_config:` in the serve YAML, (unverified) for the exact key placement in your version):

| Property                                        | Default | Notes                                                                                                                                 |
| ----------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `host_cache_size`                               | `0`     | Host memory in bytes for offloading evicted GPU blocks. Reusable until evicted from host. Reused blocks are copied back to GPU first. |
| `secondary_offload_min_priority`                | `35`    | Blocks with lower priority are not offloaded. Priorities run 0 to 100.                                                                |
| `enable_block_reuse`                            | `true`  | Cross-request reuse via a radix tree.                                                                                                 |
| `free_gpu_memory_fraction`                      | `0.9`   | Share of free GPU memory for KV; with `max_tokens` set, the lesser is used.                                                           |
| `enable_partial_reuse`, `copy_on_partial_reuse` | enabled | Partial block reuse.                                                                                                                  |
| `dtype`                                         | `auto`  | See `kv-cache-quantization`.                                                                                                          |

- Eviction is prioritized LRU; retention policies (`KvCacheRetentionConfig`) set priority per token range and duration; default priority is 35.
- Only leaf blocks can be evicted, which works well for full attention but not for limited-attention layers (upstream caveat).
- Cache salting: pass `cache_salt` on a request so only requests with the same salt can reuse its blocks (user ID, tenant ID or hash); upstream recommends it to prevent prompt-theft style attacks.
- KV Cache Connector: subclass `KvCacheConnectorScheduler` and `KvCacheConnectorWorker` for custom offload to CPU RAM, NVMe or network storage, custom disaggregation or P2P. The bundled persistent-cache example uses synchronous `torch.save` and is not production-grade by upstream's own limitations list.

## llama.cpp (master docs, release v0.6.0)

These are different things; do not conflate them:

- `-kvo, --kv-offload` / `-nkvo, --no-kv-offload`: default enabled. Disabling keeps the KV cache in host RAM instead of VRAM. It frees VRAM at a large speed cost; it is not a reuse tier.
- `-cram, --cache-ram N`: maximum prompt-cache size in MiB. Default `8192`, `-1` no limit, `0` disables. Env `LLAMA_ARG_CACHE_RAM`.
- `--cache-idle-slots`: saves idle slots to the prompt cache when a new task arrives and clears them with unified KV. Default enabled, requires `--cache-ram`.
- `--cache-prompt` / `--no-cache-prompt`: default enabled. Per-request `cache_prompt` reuses the KV of a common prefix. The docs warn logits are not guaranteed identical across batch sizes, so results can be nondeterministic.
- `--cache-reuse N`: minimum chunk size to reuse by KV shifting (default 0, off).
- `--slot-save-path PATH` (default disabled): enables `POST /slots/{id}?action=save` and `?action=restore` with a `filename` inside that directory, for persistent per-slot prompt caches on disk. Erase and other slot actions exist; see the server README.
- `--kv-unified` and `--kv-unified-per-slot N` change how slots share one KV pool.

## TabbyAPI with ExLlamaV3 (config_sample.yml, ExLlamaV3 v1.6.1)

Under `memory:`:

- `sysmem_kv_cache`: second-tier K/V cache in system memory, MB, default `0` (off).
- `disk_cache_dir`: persistent third tier on disk, default none. Experimental. Requires `sysmem_kv_cache` above 0 and ExLlamaV3 1.6.2 or later (ignored with a warning otherwise). Pages entering the system tier are written through to disk and read back, including in a later server process. Each model and cache configuration gets its own subdirectory.
- `disk_cache_size`: budget for the whole directory in MB, default 51200, least recently used entries removed.
- `disk_cache_flush_on_idle`: default `true`, persists complete VRAM pages when the generator idles.
- `disk_cache_checkpoint_interval`: tokens between recurrent checkpoints, default 4096 (checkpoints take far more space than pages on hybrid models).
- `sysmem_recurrent_cache`: MB, default 4096. `sysmem_multimodal_cache`: MB, default 1024.

## TensorFold v1.0.7

- `--prompt-cache-gib GIB`: retained-prefix budget; default 16 GiB on CUDA inside the memory budget; `0` turns it off. Documented in the `self-hosted-llms` skill's TensorFold reference.
- Disk, remote or P2P tiers: none documented (unverified); check `tensorfold capabilities --json`.
- Recipe knobs such as `KV_POOL_GB` and `TENSORFOLD_MEMORY_RESERVE_GIB` are recipe settings, not flags.

## Ollama

No KV offload or persistent KV cache setting is documented. Memory behavior is governed by context length, `OLLAMA_NUM_PARALLEL`, `OLLAMA_KEEP_ALIVE` (models stay loaded 5 minutes by default) and automatic GPU/CPU placement shown by `ollama ps`. Treat KV offloading as not available through documented settings.

## Sources

- https://github.com/vllm-project/vllm/blob/v0.31.0/docs/features/kv_offloading_usage.md
- https://github.com/vllm-project/vllm/blob/v0.31.0/vllm/config/cache.py
- https://docs.lmcache.ai/mp/quickstart.html
- https://docs.sglang.ai/advanced_features/hicache_design.html
- https://docs.sglang.ai/advanced_features/hicache_best_practices.html
- https://docs.sglang.ai/advanced_features/server_arguments.html
- https://github.com/NVIDIA/TensorRT-LLM/blob/v1.2.1/docs/source/features/kvcache.md
- https://github.com/NVIDIA/TensorRT-LLM/blob/v1.2.1/docs/source/features/kv-cache-connector.md
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://github.com/theroyallab/tabbyAPI/blob/main/config_sample.yml
- https://github.com/ashhart/TensorFold
- https://docs.ollama.com/faq
