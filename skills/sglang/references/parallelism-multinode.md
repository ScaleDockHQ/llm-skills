# SGLang: parallelism and multi-node

> Verified against SGLang v0.5.21 (docs: advanced_features/server_arguments, dp_dpa_smg_guide, expert_parallelism, pipeline_parallelism, sgl_model_gateway, references/multi_node_deployment), 2026-10-11

## Which parallelism

| Goal                                                                | Use                                    | Flag                                                      |
| ------------------------------------------------------------------- | -------------------------------------- | --------------------------------------------------------- |
| Model does not fit on one GPU                                       | Tensor parallel                        | `--tp N` (alias `--tensor-parallel-size`)                 |
| More throughput, model fits                                         | Data parallel replicas                 | `--dp N`, or better, N processes behind the model gateway |
| MLA/MoE models (DeepSeek, MiniMax, Kimi-K2) KV duplication under TP | DP attention                           | `--enable-dp-attention --dp-size N` (set both)            |
| Large MoE (256+ experts)                                            | Expert parallel                        | `--ep N` plus `--moe-a2a-backend deepep`                  |
| Long-context prefill across nodes                                   | Pipeline parallel (+ dynamic chunking) | `--pp-size N`, `--enable-dynamic-chunking`                |
| Long context, MLA decode                                            | Decode context parallel                | `--dcp-size N`                                            |
| Prefill vs decode interference                                      | PD disaggregation                      | `combos/pd-disaggregation.md`                             |

Multi-GPU TP: `python -m sglang.launch_server --model-path <m> --tp 2`. If it fails with "peer access is not supported between these two devices", add `--enable-p2p-check`.

## Data parallelism

Upstream recommends the SGLang Model Gateway (formerly router) over the in-process `--dp` for DP:

```bash
pip install sglang-router
python -m sglang_router.launch_server --model-path meta-llama/Meta-Llama-3-8B-Instruct --dp 2 --tp 2   # 4 GPUs
# or: separate workers on different GPUs (--base-gpu-id) plus python -m sglang_router.launch_router --worker-urls ...
```

Router capabilities (cache-aware routing, PD mode, gRPC, MCP, OpenAI proxy, multi-model) are in the upstream `sgl_model_gateway` doc. Policy names seen in the docs: `cache_aware` and `power_of_two`. Docker image: `lmsysorg/sgl-model-gateway:latest` (multi-arch).

`--load-balance-method`: `auto`, `round_robin`, `follow_bootstrap_room`, `total_requests`, `total_tokens` (`total_tokens` only with DP attention).

## DP attention (DPA)

Applies data parallelism to attention only (each DP rank keeps its own KV cache; no KV duplication with MLA's single KV head), tensor/expert parallelism for FFN/experts.

```bash
python -m sglang.launch_server --model-path deepseek-ai/DeepSeek-V3 \
  --tp 8 --dp-size 8 --ep 8 --enable-dp-attention \
  --moe-a2a-backend deepep --moe-runner-backend deep_gemm
```

- `--dp-size` must be set explicitly; with the default `1`, DPA is disabled.
- Also supported on standard-attention models like Qwen; for Llama-style GQA, plain TP/DP is usually better.
- Not compatible with `STANDALONE`, `NGRAM` or `DFLASH` speculative algorithms (see `features.md`).
- `--enable-dp-lm-head` shards the vocab across the attention TP group.
- `--enable-prefill-delayer` reduces idle time under DPA.

## Expert parallelism

- `--ep N`; `--moe-a2a-backend` options in 0.5.21: `none`, `deepep`, `mooncake`, `nixl`, `mori`, `ascend_fuseep`, `flashinfer`, `megamoe`, `pplx`. `--moe-runner-backend` default `auto`.
- DeepEP modes: `--deepep-mode auto|normal|low_latency` (auto recommended; in PD disaggregation use `normal` on prefill and `low_latency` on decode).
- `--enable-two-batch-overlap` (up to ~2x throughput per upstream), `--enable-eplb` (load balancing; `--ep-num-redundant-experts`), `--ep-dispatch-algorithm`.
- Elastic EP via `--elastic-ep-backend mooncake`.

## Pipeline parallelism

`--pp-size N` splits layers across stages, mostly for very long prompts across nodes. Use `--chunked-prefill-size` with `--enable-dynamic-chunking`; env `SGLANG_DYNAMIC_CHUNKING_SMOOTH_FACTOR` (default 0.75). `--pp-max-micro-batch-size`, `--pp-async-batch-depth` tune the schedule.

## Multi-node (TP across hosts)

Run the identical command on every node, changing only `--node-rank`. Rank 0 serves the HTTP API (the other ranks do not).

```bash
# node 0 (hostname sgl-dev-0)
python -m sglang.launch_server --model-path meta-llama/Meta-Llama-3.1-405B-Instruct \
  --tp 16 --nnodes 2 --node-rank 0 --dist-init-addr sgl-dev-0:50000
# node 1
python -m sglang.launch_server --model-path meta-llama/Meta-Llama-3.1-405B-Instruct \
  --tp 16 --nnodes 2 --node-rank 1 --dist-init-addr sgl-dev-0:50000
```

Checklist:

- `--tp` is the total across nodes (here 2 nodes x 8 GPUs). `--dist-init-addr` is `<rank0 ip or hostname>:<free port>` reachable from all nodes (alias `--nccl-init-addr`).
- Same image/version and same model files on every node (shared FS or pre-downloaded identical revisions; pin `--revision`).
- Network: Docker needs `--network host` (and often `--privileged`/IB devices for RDMA). Set `NCCL_SOCKET_IFNAME` (TCP), `NCCL_IB_HCA` (InfiniBand/RoCE), `NCCL_IB_GID_INDEX` (RoCE), `GLOO_SOCKET_IFNAME`, and `NCCL_DEBUG=INFO` while debugging. Open the init port and ephemeral ports between nodes only; never to the internet.
- With `--network host`, bind the API to `--host 127.0.0.1` (or set `--api-key` and firewall), because the unauthenticated API otherwise listens on every interface.
- If startup deadlocks, add `--disable-cuda-graph` (upstream advice; in 0.5.21 docs prefer `--disable-decode-cuda-graph --disable-prefill-cuda-graph`, and note the old flag is deprecated).
- Start order: all ranks must join the rendezvous; `--dist-timeout` sets the `torch.distributed` init timeout (unset by default). Stop all ranks together. (The repo's DGX Spark practice of starting the worker node first is in `combos/dgx-spark.md`.)
- DeepSeek-class multi-node recipes: per-model pages in the upstream cookbook (`docs.sglang.io/cookbook`).

### SLURM

Upstream example: `sbatch` with `--nodes=2 --ntasks-per-node=1 --gres=gpu:8`, then `srun python3 -m sglang.launch_server --model-path "$model" --tp 16 --dist-init-addr "${HEAD_NODE}:8000" --nnodes 2 --node-rank "$SLURM_NODEID"` and wait on `nc -z "$HEAD_NODE" 30000`. Adjust partition, environment and ports to your cluster.

### Kubernetes

`docker/k8s-sglang-distributed-sts.yaml` upstream (two-node StatefulSet). Also LeaderWorkerSet and RBG examples under `references/multi_node_deployment/` (`lws_pd`, `rbg_pd`) in the docs tree.

## Verify

```bash
curl -fsS http://RANK0:30000/server_info | jq -r 'del(.launch_command) | [paths(scalars) as $p | {k: ($p|map(tostring)|join(".")), v: getpath($p)}] | .[] | select(.k|test("version$|tp_size|dp_size|ep_size|nnodes|node_rank")) | "\(.k)=\(.v)"'
nvidia-smi --query-gpu=memory.used --format=csv   # on every node
```

Run a short `bench_serving` against rank 0 and confirm all nodes show GPU utilization. Cross-engine cluster design and fabric choices: skill `multi-node-inference`.
