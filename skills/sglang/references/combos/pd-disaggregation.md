# SGLang with prefill/decode (PD) disaggregation

> Verified against SGLang v0.5.21, sglang-router 0.3.2 and mooncake-transfer-engine 0.3.13.post1 (docs: advanced_features/pd_disaggregation, sgl_model_gateway, server_arguments; PyPI), 2026-10-11

Not run on hardware in this pass.

## What it is and when to use it

PD disaggregation runs prefill (compute-bound) and decode (memory-bound) on separate server processes and ships the KV cache between them. It removes prefill interruptions of running decodes (better inter-token latency) and the DP-attention imbalance where one rank prefills while another decodes. Worth the complexity when: long prompts and strict inter-token latency targets, large MoE deployments with DP attention, or a cluster with fast fabric (InfiniBand/RoCE/NVLink). Not worth it on a single GPU or a laptop. Start with a normal TP/DP deployment and benchmark first.

Components: prefill server(s), decode server(s), a transfer engine (Mooncake default, or NIXL), and the router that sends each request to one prefill + one decode.

## Requirements

- Same SGLang version and model on all instances; same `--tp`/layout rules unless using the heterogeneous-TP staging buffer (below).
- Fast fabric for KV transfer: RDMA (`--disaggregation-ib-device`), NVLink (NVL72, intra-node NVLink), or EFA on AWS. TCP works (`mooncake_tcp` backend exists) but is slow; measure.
- Install the transfer engine in the image/venv: Mooncake `uv pip install mooncake-transfer-engine` (CUDA 13 package; 0.3.13.post1 on PyPI at check time) or NIXL `pip install nixl` (or build against your UCX).
- Router: `pip install sglang-router` (or image `lmsysorg/sgl-model-gateway:latest`).
- Host networking for RDMA: `--network host`, `--privileged`/device access, `--ipc=host`, `ulimit -l unlimited`; these widen exposure, so firewall the host and bind carefully.

## Flags

| Flag                                             | Default    | Meaning                                                                                 |
| ------------------------------------------------ | ---------- | --------------------------------------------------------------------------------------- |
| `--disaggregation-mode` (`prefill` or `decode`)  | null (off) | Role of this server.                                                                    |
| `--disaggregation-transfer-backend`              | `mooncake` | `mooncake`, `nixl`, `ascend`, `mori`, `mooncake_tcp`, `fake` (testing).                 |
| `--disaggregation-bootstrap-port`                | `8998`     | Bootstrap server port on prefill servers.                                               |
| `--disaggregation-ib-device`                     | none       | IB/RoCE devices: `mlx5_0` or `mlx5_0,mlx5_1`; per-GPU JSON map or file path (Mooncake). |
| `--disaggregation-decode-enable-radix-cache`     | off        | Radix cache on decode to avoid redundant transfers.                                     |
| `--disaggregation-decode-enable-offload-kvcache` | off        | Async KV offload on decode.                                                             |
| `--num-reserved-decode-tokens`                   | `512`      | Tokens reserved when admitting new decode requests.                                     |
| `--base-gpu-id`                                  | `0`        | GPU offset for multiple servers on one host.                                            |
| `--max-queued-requests`                          | none       | Ignored in PD mode.                                                                     |

## Single node (one prefill, one decode, router)

```bash
# prefill on GPU 0
python -m sglang.launch_server --model-path meta-llama/Llama-3.1-8B-Instruct \
  --disaggregation-mode prefill --port 30000 --disaggregation-ib-device mlx5_roce0
# decode on GPU 1
python -m sglang.launch_server --model-path meta-llama/Llama-3.1-8B-Instruct \
  --disaggregation-mode decode --port 30001 --base-gpu-id 1 --disaggregation-ib-device mlx5_roce0
# router (clients talk to this port)
python -m sglang_router.launch_router --pd-disaggregation \
  --prefill http://127.0.0.1:30000 --decode http://127.0.0.1:30001 --host 127.0.0.1 --port 8000
```

For NIXL replace `--disaggregation-ib-device ...` with `--disaggregation-transfer-backend nixl` on both servers. The upstream examples bind the router to `0.0.0.0`; keep it on loopback or behind a gateway unless you intend to expose it. Servers are unauthenticated unless you pass `--api-key`.

The router also accepts an optional bootstrap port per prefill entry (`--prefill http://prefill1:30001 9001`) and policies, for example `--prefill-policy cache_aware --decode-policy power_of_two`.

## Multi-node (DeepSeek-style, from the docs)

Two prefill nodes and two decode nodes, each a 2-node TP16/DP8 group:

```bash
# prefill node 0 (node 1 uses --node-rank 1)
python -m sglang.launch_server --model-path deepseek-ai/DeepSeek-V3-0324 \
  --disaggregation-ib-device ${device_name} --disaggregation-mode prefill \
  --host ${local_ip} --port 30000 --trust-remote-code \
  --dist-init-addr ${prefill_master_ip}:5000 --nnodes 2 --node-rank 0 \
  --tp-size 16 --dp-size 8 --enable-dp-attention --moe-a2a-backend deepep --mem-fraction-static 0.8
# decode node 0 (node 1 uses --node-rank 1); add a request cap
python -m sglang.launch_server --model-path deepseek-ai/DeepSeek-V3-0324 \
  --disaggregation-ib-device ${device_name} --disaggregation-mode decode \
  --host ${local_ip} --port 30001 --trust-remote-code \
  --dist-init-addr ${decode_master_ip}:5000 --nnodes 2 --node-rank 0 \
  --tp-size 16 --dp-size 8 --enable-dp-attention --moe-a2a-backend deepep --mem-fraction-static 0.8 \
  --max-running-requests 128
```

Use `--deepep-mode normal` on prefill and `--deepep-mode low_latency` on decode (or `auto` in mixed mode). Kubernetes: the LWS-based DeepSeek R1 example in `references/multi_node_deployment/lws_pd/` upstream (needs k8s >= 1.26 and the LeaderWorkerSet controller) and an RBG example.

## Tuning and environment variables

Prefill side: `SGLANG_DISAGGREGATION_THREAD_POOL_SIZE` (transfer threads per TP rank; default `int(0.75*cpu_count)//8` clamped to 4..12), `SGLANG_DISAGGREGATION_QUEUE_SIZE` (default 4 parallel transfer queues), `SGLANG_DISAGGREGATION_BOOTSTRAP_TIMEOUT` (default 300 s), `SGLANG_DISAGGREGATION_BOOTSTRAP_ENTRY_CLEANUP_INTERVAL` (120 s), `SGLANG_MOONCAKE_MAX_TRANSFER_BATCH_INDICES` (opt-in). Decode side: `SGLANG_DISAGGREGATION_HEARTBEAT_INTERVAL` (5 s), `SGLANG_DISAGGREGATION_HEARTBEAT_MAX_FAILURE` (2), `SGLANG_DISAGGREGATION_WAITING_TIMEOUT` (300 s). Raising the timeouts to 600 trades slower cleanup for fewer spurious timeouts at higher mean TTFT.

Transports: NVLink KV transfer (NVL72): `SGLANG_MOONCAKE_CUSTOM_MEM_POOL=NVLINK` and `MC_FORCE_MNNVL=True`. Intra-node NVLink (A100/H100/H20 class): `SGLANG_MOONCAKE_CUSTOM_MEM_POOL=INTRA_NODE_NVLINK` and `MC_INTRANODE_NVLINK=true`. Auxiliary data still moves over TCP. AWS EFA (x86_64): install `mooncake-transfer-engine-efa-cuda13==0.3.13.post1` instead of the standard package (never both), set `MOONCAKE_PROTOCOL=efa`, `LD_LIBRARY_PATH` with the EFA libs, and avoid `NVLINK`/`BAREX` pools, `expandable_segments:True`, `MC_FORCE_MNNVL` and `NCCL_MNNVL_ENABLE`.

Heterogeneous TP (for example prefill TP=4, decode DP-attention with attention TP=1) with Mooncake: set `SGLANG_DISAGG_STAGING_BUFFER=1` and `SGLANG_DISAGG_STAGING_POOL_SIZE_MB=4096` on both sides; bypassed when TP sizes match; not for MLA models.

## Router and API limits

- `/v1/responses` works in foreground (including streaming) under the HTTP PD router, but not stored responses, `previous_response_id`, `background=true`, retrieval/cancel by ID, or built-in tools (`web_search`, `code_interpreter`). Send full history instead.
- v0.5.21 release notes: PD instances can switch between prefill and decode role without restart.
- Profile prefill and decode workers separately (torch profiler limitation).

## Verify

```bash
curl -fsS http://127.0.0.1:30000/health -o /dev/null -w 'prefill %{http_code}\n'
curl -fsS http://127.0.0.1:30001/health -o /dev/null -w 'decode %{http_code}\n'
curl -fsS http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"MODEL","messages":[{"role":"user","content":"Hi"}],"max_tokens":16}' | jq .choices[0].message
curl -fsS http://127.0.0.1:30001/metrics | grep -E 'sglang:(num_decode_transfer_queue_reqs|kv_transfer_latency_ms|kv_transfer_speed_gb_s)'   # needs --enable-metrics
```

Expect transfer speed in GB/s on RDMA/NVLink; single-digit MB/s means it fell back to TCP. Compare TTFT and inter-token latency against an aggregated baseline using `bench_serving` through the router before keeping the split.

## Pitfalls

- Bootstrap timeouts under load: raise `SGLANG_DISAGGREGATION_BOOTSTRAP_TIMEOUT`, then look for transfer-queue backlog and fabric errors.
- Version skew between prefill, decode and router breaks transfers: upgrade all together.
- Mixing `--disaggregation-ib-device` devices that do not share a fabric with the peer silently picks slow paths: use `ibv_devices` / `ibstat` to match.
- Do not assume Spark or consumer GPUs have the RDMA stack: see `combos/dgx-spark.md` for what the repo has verified (it has not verified PD on two Sparks).
- For multi-engine PD design (vLLM, TensorRT-LLM, Dynamo) use skill `multi-node-inference`.
