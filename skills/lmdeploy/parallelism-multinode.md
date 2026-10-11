# Parallelism and multi-node

> Verified against LMDeploy v0.18.0 (docs `advance/context_parallel.md`, `advance/pytorch_multinodes.md`, `llm/proxy_server.md`, `advance/metrics.md`; source `lmdeploy/cli`), 2026-10-11

## Choose

| Need                                            | Use                                                                                     |
| ----------------------------------------------- | --------------------------------------------------------------------------------------- |
| Model does not fit one GPU                      | `--tp N` (power of two) inside the node                                                 |
| TP larger than KV heads (e.g. 4 KV heads, TP 8) | TurboMind `--tp 8 --cp 2` instead of duplicating KV heads                               |
| More throughput, model fits per GPU group       | Several `api_server` replicas behind `lmdeploy serve proxy` (or any router)             |
| MoE models at scale                             | PyTorch `--dp` with `--ep`, optionally `--enable-eplb`, via proxy                       |
| Model needs more than one node                  | PyTorch engine with Ray and `--tp` across nodes                                         |
| Split prefill and decode                        | DistServe: proxy `--serving-strategy DistServe`, api_server `--role`, migration backend |

## Tensor parallel on one node

```bash
lmdeploy serve api_server meta-llama/Llama-3.1-70B-Instruct --tp 4 --server-name 127.0.0.1
CUDA_VISIBLE_DEVICES=0,1 lmdeploy serve api_server <model> --tp 2   # pin GPUs
```

`--tp` flag help: "GPU number used in tensor parallelism. Should be 2^n". Keep GPUs on NVLink or the same PCIe
root where possible.

## Context parallel (TurboMind)

Upstream: when `TP > num_key_value_heads`, KV heads must be duplicated, which halves KV capacity and lowers batch size.
`--cp` keeps KV interleaved across cp ranks instead (tp must be a multiple of cp). Upstream's examples:

```bash
lmdeploy serve api_server internlm/Intern-S1 --tp 8 --cp 2
lmdeploy serve api_server Qwen/Qwen3-235B-A22B --tp 8 --cp 2
```

## Replicas behind the proxy

```bash
lmdeploy serve proxy --server-name 127.0.0.1 --server-port 8000 \
  --routing-strategy min_expected_latency --serving-strategy Hybrid
CUDA_VISIBLE_DEVICES=0 lmdeploy serve api_server <model> --server-port 23333 --proxy-url http://127.0.0.1:8000
CUDA_VISIBLE_DEVICES=1 lmdeploy serve api_server <model> --server-port 23334 --proxy-url http://127.0.0.1:8000
curl -s http://127.0.0.1:8000/nodes/status | jq
```

Proxy defaults: port 8000, `--serving-strategy Hybrid` (or `DistServe`), `--routing-strategy min_expected_latency`
(others: `random`, `min_observed_latency`). The proxy exposes `/v1/models`, `/v1/chat/completions`,
`/v1/completions`, and node management `/nodes/status`, `/nodes/add`, `/nodes/remove`. Proxy `--api-keys`
is not part of the documented flags: protect it with a gateway, and note that `/nodes/*` bypasses key checks on
`api_server`. Multiple servers can also be launched through `torchrun` with a helper script (upstream
`api_server.md`); use the real host IP there, not `0.0.0.0`.

## Data and expert parallel (PyTorch)

Upstream metrics doc example with DP 2, TP 2 (one api_server per DP rank, hence several ports):

```bash
lmdeploy serve proxy --server-port 8000 --routing-strategy min_expected_latency --serving-strategy Hybrid
LMDEPLOY_DP_MASTER_ADDR=127.0.0.1 LMDEPLOY_DP_MASTER_PORT=29555 \
lmdeploy serve api_server Qwen/Qwen2.5-7B-Instruct --backend pytorch --tp 2 --dp 2 \
  --proxy-url http://0.0.0.0:8000 --nnodes 1 --node-rank 0
```

With `DP > 1` the api_servers bind the real host IP, so Prometheus targets must use it. Flag help: `--ep` "dp is
required when pytorch engine is used". Also `--enable-microbatch`, `--enable-eplb` (see `-h`).

## Multi-node (PyTorch engine, Ray)

Upstream example: `tp=16` over two 8-GPU nodes.

```bash
# every node: same container image or env, same model path
ray start --head --port=$DRIVER_PORT                 # head node
ray start --address=$DRIVER_NODE_ADDR:$DRIVER_PORT   # other nodes
ray status                                           # on the head
lmdeploy serve api_server $MODEL_PATH --backend pytorch --tp 16 --server-name 127.0.0.1
```

The engine picks single or multi node from `--tp` and the visible GPUs; force Ray with
`--distributed-executor-backend ray` or `LMDEPLOY_EXECUTOR_BACKEND=ray`. Use an RDMA-class network (upstream
recommends InfiniBand). Ray's ports are unauthenticated: keep the cluster on an isolated network. Docker
example in upstream uses `--network host`.

## DistServe (disaggregated prefill/decode)

Documented only as: proxy `--serving-strategy DistServe`, `--migration-protocol {RDMA,NVLINK}` (default RDMA),
`--link-type {RoCE,IB}`, `--disable-gdr`, and api_server `--role`, `--migration-backend`, `--kv-transfer-config`
(PyTorch only). The ops walk-through lives in LMDeploy's `docs/en/advance`/ source; verify on your version with
`-h`. For concepts and gates use the `disaggregated-serving` skill.
