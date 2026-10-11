# Disaggregated serving: engine flag matrix

> Verified against vLLM v0.31.0 (docs: features/disagg_prefill, nixl_connector_usage, nixl_connector_compatibility, mooncake_connector_usage; vllm/config/kv_transfer.py), SGLang v0.5.21 (docs: advanced_features/pd_disaggregation, server_arguments), TensorRT-LLM v1.2.1 (docs: features/disagg-serving), NIXL v1.5.0, Mooncake v0.3.13.post1, 2026-10-11

Every row below was read from the upstream page at the version in the header. Defaults are the upstream defaults at that version. Re-read upstream before relying on a flag in a newer release.

## vLLM v0.31.0: `--kv-transfer-config`

vLLM disaggregated prefill is **experimental** upstream, and its docs state it does **not** improve throughput. You run two (or more) separate `vllm serve` instances, one `kv_producer` and one `kv_consumer`, plus a proxy that sends the request to prefill first, then to decode. The proxies shipped in the vLLM repo are examples (`tests/v1/kv_connector/nixl_integration/toy_proxy_server.py`, `examples/disaggregated/mooncake_connector/mooncake_connector_proxy.py`), not production routers.

`--kv-transfer-config` takes a JSON string (the CLI also accepts dotted keys such as `--kv-transfer-config.kv_role kv_producer`).

| Key                                                                              | Default                          | Notes                                                                                                                                                                           |
| -------------------------------------------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kv_connector`                                                                   | none                             | `NixlConnector`, `MooncakeConnector`, `LMCacheConnectorV1`, `MultiConnector`, `OffloadingConnector`, `FlexKVConnectorV1`, `ExampleConnector`, `MoRIIOConnector` (ROCm only).    |
| `kv_role`                                                                        | none                             | `kv_producer` (prefill), `kv_consumer` (decode), `kv_both`. `kv_both` is **deprecated for NixlConnector**: use the explicit roles.                                              |
| `kv_buffer_device`                                                               | platform default                 | `cuda`, `cpu` or `xpu`.                                                                                                                                                         |
| `kv_load_failure_policy`                                                         | `fail`                           | `fail` errors the request when the KV load fails. `recompute` re-runs prefill on the decode instance and can add jitter to every other decode on it. Keep `fail` in production. |
| `kv_connector_extra_config`                                                      | `{}`                             | Connector-specific, see below.                                                                                                                                                  |
| `engine_id`, `kv_rank`, `kv_parallel_size`, `kv_ip`, `kv_port`, `kv_buffer_size` | see `vllm/config/kv_transfer.py` | Legacy pipe-style connectors only.                                                                                                                                              |

### NixlConnector

Install: `uv pip install nixl` (the exact version vLLM expects is in its `requirements/kv_connectors.txt`).

| Setting                                            | Default                        | Constraint                                                                                                                                                                                                                              |
| -------------------------------------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `VLLM_NIXL_SIDE_CHANNEL_PORT` (env)                | `5600`                         | Required on both sides. One unique port per worker per host: with DP, ports are `base + dp_rank`.                                                                                                                                       |
| `VLLM_NIXL_SIDE_CHANNEL_HOST` (env)                | `localhost`                    | Set to the node's reachable IP when prefill and decode are on different hosts.                                                                                                                                                          |
| `UCX_TLS`, `UCX_NET_DEVICES` (env)                 | upstream example uses `all`    | UCX is the default NIXL backend. `NCCL_*` variables do **not** apply to NixlConnector.                                                                                                                                                  |
| `kv_connector_extra_config.backends`               | `["UCX"]` (UCX is the default) | Other plugins, for example `["LIBFABRIC"]` or `["UCX","GDS"]`, only if NIXL was built with them.                                                                                                                                        |
| `kv_connector_extra_config.kv_lease_duration`      | `30` (seconds)                 | Prefill holds KV blocks this long waiting for decode. Decode sends heartbeats that extend the lease.                                                                                                                                    |
| `kv_connector_extra_config.bidirectional_kv_xfer`  | `false`                        | Multi-turn: prefill pulls decode's blocks. Needs a stateful proxy using a `conversation_id`. Do not use it when clients strip reasoning traces from history (upstream warns this transfers KV for wrong token positions, issue #43094). |
| `kv_connector_extra_config.kv_recompute_threshold` | `64`                           | Only with bidirectional transfer.                                                                                                                                                                                                       |
| `kv_connector_extra_config.decoder_kv_blocks_ttl`  | `480` (seconds)                | Only with bidirectional transfer.                                                                                                                                                                                                       |
| `VLLM_KV_CACHE_LAYOUT=BLHNC` (env)                 | unset                          | Enables cross-layer contiguous blocks (see the compatibility matrix).                                                                                                                                                                   |

Compatibility facts from the NixlConnector matrix at v0.31.0:

- Works with all model types: chunked prefill, prefix caching, data parallel, CUDA graphs, logprobs, prompt embeds, multiple NIXL backends.
- Heterogeneous TP (prefill TP != decode TP): supported for dense and MoE, partial for MLA (KV is replicated across TP workers), **not supported for hybrid SSM/Mamba** (needs prefill TP == decode TP).
- Encoder-decoder models: not supported. Multimodal: not validated.
- Speculative decoding: supported, but P and D must use compatible speculation configs.

Minimal single-host pair (two GPUs):

```bash
CUDA_VISIBLE_DEVICES=0 UCX_NET_DEVICES=all VLLM_NIXL_SIDE_CHANNEL_PORT=5600 \
vllm serve "$MODEL" --port 8100 \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_producer","kv_load_failure_policy":"fail"}'
CUDA_VISIBLE_DEVICES=1 UCX_NET_DEVICES=all VLLM_NIXL_SIDE_CHANNEL_PORT=5601 \
vllm serve "$MODEL" --port 8200 \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_consumer","kv_load_failure_policy":"fail"}'
```

Then a proxy (for example the toy one above) in front: `--prefiller-hosts/--prefiller-ports/--decoder-hosts/--decoder-ports`.

### MooncakeConnector

Install: `uv pip install mooncake-transfer-engine-cuda13` (vLLM defaults to CUDA 13; use `mooncake-transfer-engine` on CUDA 12, otherwise import fails with `libcudart.so.<major>: cannot open shared object file`).

| Setting                                       | Default              | Notes                                                                                                                                                                                                   |
| --------------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kv_role`                                     | none                 | `kv_producer`, `kv_consumer`, `kv_both`.                                                                                                                                                                |
| `kv_connector_extra_config.num_workers`       | `10`                 | Transfer thread pool per prefiller worker.                                                                                                                                                              |
| `kv_connector_extra_config.mooncake_protocol` | `rdma`               |                                                                                                                                                                                                         |
| `kv_connector_extra_config.device_name`       | empty (discover all) | Comma list such as `mlx5_0,mlx5_1`; use on hosts with mixed IB and RoCE ports so both peers pick the same link layer.                                                                                   |
| `VLLM_MOONCAKE_BOOTSTRAP_PORT` (env)          | `8998`               | Prefillers; unique per host; headless instances must match the master.                                                                                                                                  |
| `VLLM_MOONCAKE_CONNECTOR_TIMEOUT` (env)       | `30.0`               | Raise if bootstrap timeouts appear with a large `MOONCAKE_GLOBAL_SEGMENT_SIZE`.                                                                                                                         |
| `VLLM_MOONCAKE_ABORT_REQUEST_TIMEOUT` (env)   | `480`                | Prefill frees an aborted request's KV after this.                                                                                                                                                       |
| `WITH_NVIDIA_PEERMEM` (env, read by Mooncake) | `1`                  | Needs the `nvidia-peermem` module. Set `0` for DMA-BUF where the module is absent (for example GB200); symptom otherwise: `Failed to register memory <addr>: Bad address [14]` from `rdma_context.cpp`. |

llm-d's P/D guide adds that MooncakeConnector needs the **same** `--tensor-parallel-size` on both sides.

### Other connectors

`LMCacheConnectorV1` (LMCache moves KV, uses NIXL underneath in the shipped example), `MultiConnector` (ordered list of connectors in `kv_connector_extra_config.connectors`), `OffloadingConnector` (CPU offload: `block_size`, `cpu_bytes_to_use`; see the `kv-cache-offloading` skill), `FlexKVConnectorV1`. Prefer NixlConnector or MooncakeConnector for plain P/D.

### vLLM request fields

- Prefill request: `kv_transfer_params: {"do_remote_decode": true}`; decode request: `kv_transfer_params: {"do_remote_prefill": true, ...}` carrying what prefill returned. Orchestrators do this for you.
- Optional token-id reuse (chat completions): prefill with `return_token_ids`, then pass `kv_transfer_params["prompt_token_ids"]` on decode so decode skips templating and tokenizing.

## SGLang v0.5.21: `--disaggregation-*`

Run one prefill server and one decode server per replica, then a router (`sglang_router` / SGLang Model Gateway) with `--pd-disaggregation`. SGLang supports Mooncake and NIXL as transfer engines (plus `ascend`, `mori`, `mooncake_tcp`, `fake` values in the flag).

| Flag                                             | Default                          | Notes                                                                                                                                      |
| ------------------------------------------------ | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `--disaggregation-mode`                          | `null` (not disaggregated)       | `prefill` or `decode`.                                                                                                                     |
| `--disaggregation-transfer-backend`              | `mooncake`                       | `mooncake`, `nixl`, `ascend`, `fake`, `mori`, `mooncake_tcp`.                                                                              |
| `--disaggregation-bootstrap-port`                | `8998`                           | On the prefill server. Router prefill URLs accept an optional bootstrap port.                                                              |
| `--disaggregation-ib-device`                     | none (auto-detect with Mooncake) | `mlx5_0`, `mlx5_0,mlx5_1`, a per-GPU JSON map, or a path to a JSON file.                                                                   |
| `--disaggregation-decode-enable-radix-cache`     | `False`                          | Decode-side prefix cache to avoid redundant transfers. Incompatible with `--enable-hisparse`, speculative decoding and the `fake` backend. |
| `--disaggregation-decode-enable-offload-kvcache` | `False`                          | Async KV offload on decode.                                                                                                                |
| `--disaggregation-decode-polling-interval`       | `1`                              | Larger values reduce polling overhead.                                                                                                     |
| `--num-reserved-decode-tokens`                   | `512`                            | Decode tokens reserved per new running request.                                                                                            |
| `--optimistic-prefill-retries`                   | `0`                              |                                                                                                                                            |
| `--base-gpu-id`                                  | not checked                      | Used in the upstream single-node example so prefill and decode use different GPUs.                                                         |

Environment variables documented at v0.5.21:

| Variable                                                 | Default                                        | Side    | Meaning                                                                                                                                                                                     |
| -------------------------------------------------------- | ---------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SGLANG_DISAGGREGATION_THREAD_POOL_SIZE`                 | `int(0.75 * cpu_count) // 8`, clamped to 4..12 | prefill | KV transfer worker threads per TP rank.                                                                                                                                                     |
| `SGLANG_DISAGGREGATION_QUEUE_SIZE`                       | `4`                                            | prefill | Parallel transfer queues; `1` means FCFS one at a time.                                                                                                                                     |
| `SGLANG_MOONCAKE_MAX_TRANSFER_BATCH_INDICES`             | `0` (disabled)                                 | prefill | Opt-in slicing of large Mooncake transfer batches.                                                                                                                                          |
| `SGLANG_DISAGGREGATION_BOOTSTRAP_TIMEOUT`                | `300` s                                        | prefill | Waiting for destination KV indices. Raising it delays cleanup when a decode node drops.                                                                                                     |
| `SGLANG_DISAGGREGATION_BOOTSTRAP_ENTRY_CLEANUP_INTERVAL` | `120` s                                        | prefill |                                                                                                                                                                                             |
| `SGLANG_DISAGGREGATION_HEARTBEAT_INTERVAL`               | `5.0` s                                        | decode  | Health checks to prefill bootstrap servers.                                                                                                                                                 |
| `SGLANG_DISAGGREGATION_HEARTBEAT_MAX_FAILURE`            | `2`                                            | decode  | Failures before prefill is marked offline.                                                                                                                                                  |
| `SGLANG_DISAGGREGATION_WAITING_TIMEOUT`                  | `300` s                                        | decode  | Waiting for KV after init.                                                                                                                                                                  |
| `SGLANG_DISAGGREGATION_NIXL_BACKEND`                     | `UCX`                                          | both    | NIXL plugin such as `LIBFABRIC`.                                                                                                                                                            |
| `SGLANG_MOONCAKE_CUSTOM_MEM_POOL`                        | unset                                          | both    | `NVLINK` (or `True`), `BAREX`, `INTRA_NODE_NVLINK`. With `NVLINK` also `MC_FORCE_MNNVL=True`; with `INTRA_NODE_NVLINK` also `MC_INTRANODE_NVLINK=true`. Auxiliary data still goes over TCP. |
| `MOONCAKE_PROTOCOL=efa`                                  | unset                                          | both    | AWS EFA build only (x86_64 `mooncake-transfer-engine-efa-cuda13`). Do not use `NVLINK`/`BAREX` pools, `expandable_segments:True`, `MC_FORCE_MNNVL` or `NCCL_MNNVL_ENABLE` with EFA.         |
| `SGLANG_DISAGG_STAGING_BUFFER`                           | `False`                                        | both    | GPU staging buffer for **heterogeneous TP** over Mooncake (2-5x throughput at high concurrency per upstream). Not for MLA models.                                                           |
| `SGLANG_DISAGG_STAGING_POOL_SIZE_MB`                     | `4096`                                         | decode  | Staging ring buffer size.                                                                                                                                                                   |

Constraints from upstream: `--enable-response-store` fails at startup with PD; stateful `/v1/responses` features (`store`, `previous_response_id`, `background`, built-in tools) are not supported under PD, send explicit history instead.

Single-node pair (from upstream, Mooncake):

```bash
python -m sglang.launch_server --model-path "$MODEL" --disaggregation-mode prefill --port 30000 \
  --disaggregation-ib-device mlx5_roce0
python -m sglang.launch_server --model-path "$MODEL" --disaggregation-mode decode --port 30001 \
  --base-gpu-id 1 --disaggregation-ib-device mlx5_roce0
python -m sglang_router.launch_router --pd-disaggregation \
  --prefill http://127.0.0.1:30000 --decode http://127.0.0.1:30001 --host 127.0.0.1 --port 8000
```

Router flags for PD (SGLang Model Gateway): `--pd-disaggregation`, `--prefill URL [BOOTSTRAP_PORT]`, `--decode URL`, `--prefill-policy`, `--decode-policy`, `--worker-startup-timeout-secs` (default `600`). The router default `--host` is `127.0.0.1`.

## TensorRT-LLM v1.2.1

Two ways: Dynamo (see `orchestrators.md`) or `trtllm-serve` with a separate "disaggregated" orchestrator server.

```yaml
# context_config.yml (prefill)
disable_overlap_scheduler: true
cache_transceiver_config:
  backend: UCX # DEFAULT | UCX | NIXL | MPI ; default backend is NIXL
  max_tokens_in_buffer: 2048
```

```yaml
# disagg_config.yaml
hostname: localhost
port: 8000
backend: pytorch
context_servers:
  num_instances: 1
  urls: ["localhost:8001"]
generation_servers:
  num_instances: 1
  urls: ["localhost:8003"]
```

```bash
CUDA_VISIBLE_DEVICES=0 trtllm-serve "$MODEL" --host localhost --port 8001 --backend pytorch --config ./context_config.yml &
CUDA_VISIBLE_DEVICES=1 trtllm-serve "$MODEL" --host localhost --port 8003 --backend pytorch --config ./gen_config.yml &
trtllm-serve disaggregated -c disagg_config.yaml
```

- `--config <file>` is the preferred flag; `--extra_llm_api_options <file>` is an equivalent alias.
- `max_tokens_in_buffer`: upstream recommends at least the maximum ISL of all requests.
- Overlap scheduler is disabled for context servers in the upstream example.
- Limits: decoder-only models, beam width 1, homogeneous per-layer KV (same dtype and head count). Context and generation instances may use different TP/PP.
- Mixed context-only and generation-only traffic on one server is allowed but not recommended.

| Environment variable                                                | Default         | Meaning                                                                                                                                                                |
| ------------------------------------------------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TRTLLM_NIXL_KVCACHE_BACKEND`                                       | `UCX`           | NIXL backend: `UCX` or `LIBFABRIC` (the container does not include the LIBFABRIC plugin; rebuild NIXL or set `NIXL_PLUGINS_DIR`). Unsupported values fall back to UCX. |
| `TRTLLM_DISABLE_KV_CACHE_TRANSFER_OVERLAP`                          | `0`             | `1` stops overlapping KV transfer with compute.                                                                                                                        |
| `TRTLLM_ENABLE_KVCACHE_RECEIVE_PARALLEL`                            | `0`             | Receive from multiple context ranks in parallel.                                                                                                                       |
| `TRTLLM_REQUEST_KV_CACHE_CONCURRENT`                                | see upstream    | Per-context-executor receive resources.                                                                                                                                |
| `TRTLLM_TRY_ZCOPY_FOR_KVCACHE_TRANSFER`                             | `0`             | Skip the staging copy.                                                                                                                                                 |
| `TRTLLM_KVCACHE_TRANSFER_BUFFER_SIZE`                               | `512MB`         | `cudaMalloc` buffer instead of the stream-ordered allocator.                                                                                                           |
| `TRTLLM_KVCACHE_TRANSFER_USE_ASYNC_BUFFER`                          | `0`             | `cudaMallocAsync`; only with a buffer size above 0.                                                                                                                    |
| `TRTLLM_KVCACHE_SEND_MAX_CONCURRENCY_NUM`                           | `1`             | Only with a buffer size above 0.                                                                                                                                       |
| `UCX_MAX_RNDV_RAILS`                                                | UCX default `2` | Lower it when TP ranks contend for shared NICs.                                                                                                                        |
| `UCX_CUDA_IPC_ENABLE_MNNVL=n`, `UCX_NET_DEVICES`, `UCX_RNDV_SCHEME` | n/a             | Upstream workarounds for servers in different NVLink domains (`UCX_RNDV_SCHEME=get_zcopy` or `put_zcopy` on GB200).                                                    |

Error `Disaggregated serving is not enabled, please check the configuration?` means `cache_transceiver_config` (the C++ `CacheTransceiverConfig` backend type) is not set. Expect lower KV bandwidth on the first requests (connections are set up lazily): warm up before benchmarking.

## Not covered here (unverified for this skill)

- llama.cpp, Ollama, ExLlamaV3 and TensorFold: prefill/decode disaggregation was **not checked** (unverified). Do not offer it for them until their upstream docs are read.
- Default of `--base-gpu-id` and the exact semantics of `SGLANG_MOONCAKE_MAX_TRANSFER_BATCH_INDICES` beyond the table (unverified).
- LMCache connector configuration beyond what the vLLM page shows.
