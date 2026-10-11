# Parallelism and multi-node serving

> Verified against vLLM v0.31.0 (docs `serving/parallelism_scaling.md`, `data_parallel_deployment.md`, `expert_parallel_deployment.md`, `context_parallel_deployment.md`, `distributed_troubleshooting.md`, `examples/ray_serving/run_cluster.sh`, source `vllm/config/parallel.py`), 2026-10-11

## Choosing a strategy

| Situation                                                                   | Use                                                                                                                      |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Model fits one GPU                                                          | No parallelism. Scale throughput with replicas (independent servers behind a router).                                    |
| Fits one node, several GPUs with fast links (NVLink)                        | Tensor parallel: `--tensor-parallel-size N` (`-tp`).                                                                     |
| GPU count does not divide the model evenly, or no NVLink (for example L40S) | Pipeline parallel: `-tp 1 -pp <gpus>`; higher throughput, lower communication overhead than TP without NVLink.           |
| Model exceeds one node                                                      | TP = GPUs per node, PP = number of nodes (docs recommendation), or TP across all GPUs if the link is fast.               |
| MoE model (DeepSeek, Qwen3-MoE, Llama 4, gpt-oss) at scale                  | Data parallel attention + expert parallel MoE: `--data-parallel-size D --enable-expert-parallel`.                        |
| Long-context KV does not fit or is duplicated across TP ranks               | Decode context parallel `-dcp <size>` (size in `[1, tp_size / kv_heads]`), prefill context parallel (under development). |

After the fit succeeds, read the startup log lines `GPU KV cache size: N tokens` and
`Maximum concurrency for M tokens per request: Nx`. If concurrency is too low, add GPUs or nodes.

## Single node

```bash
vllm serve <model> --tensor-parallel-size 4
vllm serve <model> --tensor-parallel-size 4 --pipeline-parallel-size 2   # 8 GPUs
```

Containers need `--ipc=host` or a large `--shm-size`. Without it tensor parallel fails on shared memory.

## Executor backends: `mp` versus `ray`

`--distributed-executor-backend mp|ray`. Source of truth is `vllm/config/parallel.py`:

- With `None` (default) and world size above 1, vLLM uses `mp` when the world fits the node, and **also when
  `--nnodes > 1` on CUDA**. If the world size exceeds the local GPUs and `--nnodes` is not set, it raises
  `World size (N) is larger than the number of available GPUs (M) in this node`.
- Ray is used only when you ask for it (`--distributed-executor-backend ray`), when `--data-parallel-backend ray`
  is set, or when vLLM runs inside an existing Ray placement group.
- Upstream docs still say "Ray is the default for multi-node"; the v0.31.0 source disagrees. Be explicit.
- Ray is an optional dependency: `pip install "ray[cgraph]"`. Some images (NGC 26.05) ship without it.

### Multi-node with multiprocessing (no Ray)

Same image, same weights path and same flags on every node. Node 0 serves the API; others run `--headless`:

```bash
# node 0 (head), HEAD_IP reachable by all nodes
vllm serve /models/<model> --tensor-parallel-size 8 --pipeline-parallel-size 2 \
  --nnodes 2 --node-rank 0 --master-addr "$HEAD_IP"
# node 1
vllm serve /models/<model> --tensor-parallel-size 8 --pipeline-parallel-size 2 \
  --nnodes 2 --node-rank 1 --master-addr "$HEAD_IP" --headless
```

`--master-port` defaults to 29501. Total GPUs = TP x PP across nodes. For tensor parallel across exactly two
single-GPU nodes use `-tp 2 --nnodes 2` (see `references/combos/dgx-spark-dual-mp.md`).

### Multi-node with Ray

Use the repo helper `examples/ray_serving/run_cluster.sh` (takes image, head IP, `--head|--worker`, HF home
path, then extra `docker run` args; it runs `--network host --shm-size 10.24g --gpus all` and starts
`ray start --block` in a container named `node-<random>`):

```bash
bash run_cluster.sh vllm/vllm-openai:v0.31.0 <HEAD_IP> --head   /abs/path/hf-home -e VLLM_HOST_IP=<HEAD_IP>
bash run_cluster.sh vllm/vllm-openai:v0.31.0 <HEAD_IP> --worker /abs/path/hf-home -e VLLM_HOST_IP=<WORKER_IP>
docker exec -it node-<suffix> bash      # then: ray status ; ray list nodes
vllm serve /models/<model> --tensor-parallel-size 8 --pipeline-parallel-size 2 --distributed-executor-backend ray
```

- `VLLM_HOST_IP` is different on every node. Closing a shell stops its Ray node (and the cluster). Run the
  cluster under `tmux`, systemd or a supervisor.
- Set extra env vars for the whole cluster on the `run_cluster.sh` line (for example
  `-e NCCL_SOCKET_IFNAME=eth0`); a variable exported in your shell affects only the local node.
- The script downloads nothing: pre-download weights to the same path on every node, or pass `-e HF_TOKEN`.
- Ray head listens on 6379 (script constant). The Ray dashboard is on 8265.
- Security: traffic between nodes is **unencrypted** and endpoints exchange data that can lead to remote code
  execution if an attacker reaches the network. Use a private, isolated segment (direct link or VLAN).
- Alternative: KubeRay (`docs/deployment/integrations/kuberay.md`).

## Network and NCCL

- Fast interconnect matters for TP across nodes. InfiniBand: add `--privileged -e NCCL_IB_HCA=mlx5` to
  `run_cluster.sh`. GPUDirect RDMA needs `IPC_LOCK`, `--ipc=host --shm-size=16G -v /dev/shm:/dev/shm`.
- Confirm RDMA: run with `NCCL_DEBUG=TRACE` and look for `[send] via NET/IB/GDRDMA` (good) versus
  `[send] via NET/Socket` (raw TCP; slow for cross-node TP).
- Multiple NICs/IPs: set `VLLM_HOST_IP`, `NCCL_SOCKET_IFNAME`, `GLOO_SOCKET_IFNAME` (NVIDIA's Spark recipe also
  sets `UCX_NET_DEVICES`, `TP_SOCKET_IFNAME`, `OMPI_MCA_btl_tcp_if_include`).
- Verify GPU-to-GPU communication before blaming vLLM: the NCCL/Gloo/vLLM `PyNcclCommunicator` test script in
  `docs/usage/troubleshooting.md`, run with `torchrun --nnodes 2 --nproc-per-node=<n> --rdzv_backend=static
--rdzv_endpoint=$MASTER_ADDR --node-rank $NODE_RANK test.py`. Use `static` rendezvous, not `c10d`.
- Error `Error: No available node types can fulfill resource request` with enough GPUs usually means the
  node has several IPs: set `VLLM_HOST_IP` per node and compare with `ray status`.

## Data parallel and expert parallel

- Replicas inside one vLLM: `--data-parallel-size 4 --tensor-parallel-size 2` (8 GPUs). `--max-num-seqs` applies per
  DP rank; `--max-num-queued-reqs` and `--max-num-queued-tokens` apply to the whole server.
- For dense models, independent servers behind a load balancer are simpler than DP. External-LB DP flags are
  only for MoE deployments.
- Multi-node DP, internal load balancing:

```bash
# node 0 (IP 10.99.48.128)
vllm serve $MODEL --data-parallel-size 4 --data-parallel-size-local 2 \
  --data-parallel-address 10.99.48.128 --data-parallel-rpc-port 13345
# node 1
vllm serve $MODEL --headless --data-parallel-size 4 --data-parallel-size-local 2 \
  --data-parallel-start-rank 2 --data-parallel-address 10.99.48.128 --data-parallel-rpc-port 13345
```

- Modes: internal LB (single endpoint, default), hybrid (`--data-parallel-hybrid-lb`, one API server per node,
  not with `--headless`), external (`--data-parallel-rank` per process, own router). `--api-server-count N`
  scales the API front end when it becomes the bottleneck. Ray DP: `--data-parallel-backend ray` (one launch
  command; use `VLLM_RAY_DP_PACK_STRATEGY="span"` when one DP group spans nodes).
- Expert parallel: `--enable-expert-parallel`; EP size = TP x DP. Backends via `--all2all-backend`:
  `allgather_reducescatter` (default), `deepep_high_throughput` (prefill), `deepep_low_latency` (decode),
  `flashinfer_nvlink_one_sided|two_sided` (MNNVL); v0.31.0 also adds `moonep`. DeepEP and DeepGEMM must be
  installed separately; `deepep_v2` needs NCCL 2.30.4+. Multi-node EP example is in the upstream
  `expert_parallel_deployment.md`.

## Disaggregated prefill/decode and offload

`--kv-transfer-config` with NIXL, Mooncake or MoRIIO connectors; `--kv-offloading-size` with
`--kv-offloading-backend native|lmcache`; see `docs/features/disagg_prefill.md`, `nixl_connector_usage.md`,
`kv_offloading_usage.md`. Cluster-level routing and autoscaling are covered by the `vllm-production-stack`,
`llm-d` and `ray-serve` skills.

## Pitfalls

- Image drift between nodes behind one tag. Compare `docker image inspect -f '{{.Id}}'` on every node; for local
  builds `docker save | ssh node docker load`.
- Different `--max-model-len`, quantization or dtype flags between mp nodes.
- Forgetting `--headless` on non-head mp nodes (every node starts an API server) or the opposite.
- TP size not dividing attention heads or KV heads: pick a size that does.
- Weights not at the same path on all nodes; a network file system slows every cold start.
