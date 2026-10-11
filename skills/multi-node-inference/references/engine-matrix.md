# Multi-node inference: engine flag matrix

> Verified against vLLM v0.31.0 (docs: serving/parallelism_scaling, data_parallel_deployment, expert_parallel_deployment, distributed_troubleshooting), SGLang v0.5.21 (docs: references/multi_node_deployment/multi_node, advanced_features/server_arguments), TensorRT-LLM v1.2.1 (docs: examples/llm_mgmn, parallelism), llama.cpp master build b11556 (tools/rpc/README.md), exo v1.0.71 (README), TensorFold v1.0.7 (docs/speed-up-mode.md), 2026-10-11

Rule of thumb from vLLM's docs: tensor parallel (TP) size = GPUs per node, pipeline parallel (PP) size = number of nodes, because TP needs the fastest links. If the GPU count does not divide evenly, or GPUs lack NVLink, PP is the better inter-node dimension. Total GPUs = TP x PP x DP (EP is carved out of TP x DP for MoE).

Fit first: if the model fits on one node, multi-node TP is usually slower than one node plus more replicas. Use multi-node for weights or KV that do not fit, or for wide expert parallelism.

## vLLM v0.31.0

Default runtime: Ray when a multi-node job is detected, multiprocessing for single node. Force with `--distributed-executor-backend ray|mp`.

### Ray

```bash
# head node (flag order: image, head IP, --head|--worker, HF home dir, then docker args)
bash run_cluster.sh vllm/vllm-openai <HEAD_NODE_IP> --head /path/to/hf_home -e VLLM_HOST_IP=<HEAD_NODE_IP>
# each worker node (VLLM_HOST_IP differs per node)
bash run_cluster.sh vllm/vllm-openai <HEAD_NODE_IP> --worker /path/to/hf_home -e VLLM_HOST_IP=<WORKER_NODE_IP>
# inside a container, verify, then serve from any node
ray status; ray list nodes
vllm serve /path/to/model --tensor-parallel-size 8 --pipeline-parallel-size 2 --distributed-executor-backend ray
```

`run_cluster.sh` lives at `examples/ray_serving/run_cluster.sh` in the vLLM repo. Ray traffic is **unencrypted** and the endpoints exchange data in a format that can be exploited: set `VLLM_HOST_IP` to an address on a private network and never expose Ray ports. Pre-download the model to the same path on every node. KubeRay is the alternative on Kubernetes. Optional `ray[cgraph]` is needed for some Ray features.

### Multiprocessing (no Ray)

```bash
# head
vllm serve /path/to/model --tensor-parallel-size 8 --pipeline-parallel-size 2 \
  --nnodes 2 --node-rank 0 --master-addr <HEAD_NODE_IP>
# worker
vllm serve /path/to/model --tensor-parallel-size 8 --pipeline-parallel-size 2 \
  --nnodes 2 --node-rank 1 --master-addr <HEAD_NODE_IP> --headless
```

### Data and expert parallel

| Flag                                                      | Notes                                                                                                                                                                                |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `--data-parallel-size N`                                  | Total DP replicas.                                                                                                                                                                   |
| `--data-parallel-size-local N`                            | Replicas on this node.                                                                                                                                                               |
| `--data-parallel-address`, `--data-parallel-rpc-port`     | Rank-0 node address and port.                                                                                                                                                        |
| `--data-parallel-start-rank`                              | First rank on a secondary node.                                                                                                                                                      |
| `--data-parallel-backend ray`                             | Let Ray place DP ranks; `VLLM_RAY_DP_PACK_STRATEGY=span` packs ranks across nodes.                                                                                                   |
| `--data-parallel-hybrid-lb`                               | Per-node load balancing with a shared external front end.                                                                                                                            |
| `--data-parallel-external-lb` with `--data-parallel-rank` | External load balancer, one API server per rank.                                                                                                                                     |
| `--api-server-count`                                      | Number of API server processes.                                                                                                                                                      |
| `--enable-expert-parallel`                                | MoE EP; EP size = TP x DP.                                                                                                                                                           |
| `--all2all-backend`                                       | `allgather_reducescatter` (default), `deepep_high_throughput`, `deepep_low_latency`, `flashinfer_nvlink_one_sided`, `flashinfer_nvlink_two_sided`. `deepep_v2` needs NCCL >= 2.30.4. |

### Network settings in containers

- InfiniBand: add `--privileged -e NCCL_IB_HCA=mlx5` to `run_cluster.sh`.
- GPUDirect RDMA: add `IPC_LOCK` capability; mount `/dev/shm` (`--ipc=host --shm-size=16G -v /dev/shm:/dev/shm` for Docker).
- Confirm the path: `NCCL_DEBUG=TRACE vllm serve ...` and look for `[send] via NET/IB/GDRDMA` (good) versus `[send] via NET/Socket` (raw TCP; inefficient for cross-node TP).

### Troubleshooting

- `No available node types can fulfill resource request`: usually a node with several IPs; set `VLLM_HOST_IP` on every node (same fix as the NIXL side channel host).
- Hangs at startup or mid-run: see `distributed_troubleshooting.md` upstream; general first checks (not from upstream): identical vLLM, torch and NCCL versions on every node, reachable ports.

## SGLang v0.5.21

Run the **same** command on each node with a different `--node-rank`:

```bash
python -m sglang.launch_server --model-path "$MODEL" --tp 16 \
  --dist-init-addr <NODE0_IP>:5000 --nnodes 2 --node-rank 0 --host 0.0.0.0 --port 30000
python -m sglang.launch_server --model-path "$MODEL" --tp 16 \
  --dist-init-addr <NODE0_IP>:5000 --nnodes 2 --node-rank 1
```

| Flag                                    | Default        | Notes                                                                                           |
| --------------------------------------- | -------------- | ----------------------------------------------------------------------------------------------- |
| `--dist-init-addr` / `--nccl-init-addr` | none           | `host:port` of node 0, same on all nodes.                                                       |
| `--nnodes`                              | `1`            |                                                                                                 |
| `--node-rank`                           | `0`            |                                                                                                 |
| `--tp-size` (`--tp`)                    | `1`            | Total across all nodes (16 above = 2 nodes x 8 GPUs).                                           |
| `--pp-size`                             | `1`            |                                                                                                 |
| `--dp-size`                             | `1`            |                                                                                                 |
| `--ep-size`                             | `1`            | MoE expert parallel.                                                                            |
| `--enable-dp-attention`                 | `False`        | DP attention with TP for MoE/MLA; pair with `--enable-dp-lm-head`.                              |
| `--moe-a2a-backend`                     | `none`         | `none`, `deepep`, `mooncake`, `nixl`, `mori`, `ascend_fuseep`, `flashinfer`, `megamoe`, `pplx`. |
| `--load-balance-method`                 | `auto`         | `auto`, `round_robin`, `follow_bootstrap_room`, `total_requests`, `total_tokens`.               |
| `--mem-fraction-static`                 | engine default | The DeepSeek PD example sets `0.8`.                                                             |

Upstream tip: if a multi-node run deadlocks, add `--disable-cuda-graph`. Upstream also documents a SLURM example for Llama 3.1 405B (fp16) on two nodes. A DeepSeek two-node example combines `--tp-size 16 --dp-size 8 --enable-dp-attention --moe-a2a-backend deepep`.

## TensorRT-LLM v1.2.1

Multi-node uses MPI. Under SLURM:

```bash
srun -N 2 --ntasks-per-node 8 --mpi=pmix --container-image <trtllm-image> \
  trtllm-llmapi-launch trtllm-serve "$LOCAL_MODEL_DIR" --tp_size 16 [--pp_size N] [--ep_size N]
```

- Total MPI tasks (nodes x `ntasks-per-node`) must equal the parallelism product (`tp_size` here).
- Downloading from Hugging Face is not supported in this mode: use a local model directory on every node.
- The upstream multi-node example is marked experimental.
- DeepSeek-V3 two-node example upstream: `--tp_size 16 --ep_size 4 --max_batch_size 161 --max_num_tokens 1160 --kv_cache_free_gpu_memory_fraction 0.95` with `enable_attention_dp: true` in the YAML config.
- YAML keys: `tensor_parallel_size`, `enable_attention_dp`, `moe_tensor_parallel_size`, `moe_expert_parallel_size` (the product of the last two must equal `tensor_parallel_size`).
- Parallelism families listed by upstream: TP, PP, DP (attention DP), EP, CP (context parallel) and Wide-EP.
- On Kubernetes, Dynamo multinode workloads need Grove + KAI Scheduler, or LeaderWorkerSet >= v0.7.0 with Volcano (Dynamo 1.5.x). See `disaggregated-serving` for Dynamo.

## llama.cpp RPC (master, build b11556)

Proof-of-concept and **insecure**: never bind it to an open network; use a private link or an SSH tunnel.

```bash
# build on every node with RPC backends
cmake -B build -DGGML_RPC=ON && cmake --build build --config Release
# worker (default endpoint 127.0.0.1:50052; use the private IP to accept remote clients)
ggml-rpc-server -p 50052 --device <dev> -c          # -c enables the local file cache
# client
llama-server -m model.gguf --rpc 10.0.0.2:50052,10.0.0.3:50052 -ngl 99 --host 127.0.0.1
```

| Option                                      | Default                | Notes                                                                             |
| ------------------------------------------- | ---------------------- | --------------------------------------------------------------------------------- |
| `--rpc host:port,...` (env `LLAMA_ARG_RPC`) | none                   | Backends are used like extra GPUs.                                                |
| `-ts` / `--tensor-split`                    | proportional to memory | Override the split.                                                               |
| `-sm` / `--split-mode`                      | `layer`                | `none`, `layer`, `row`, `tensor` (`tensor` experimental).                         |
| `-c` (rpc server, cache)                    | off                    | Cache dir `~/.cache/llama.cpp/rpc` or `LLAMA_CACHE`.                              |
| `GGML_RPC_NO_RDMA=1`                        | RDMA auto-negotiated   | Force TCP. RDMA = RoCEv2 via libibverbs, or macOS Thunderbolt 5 on macOS >= 26.2. |
| `GGML_RPC_DEBUG`                            | `0`                    | `0`-`3`, use `-lv 5` on the client.                                               |

`llama-server --host` defaults to `127.0.0.1`.

## TensorFold v1.0.7 (two Macs, `--speed-up`)

`tensorfold-native serve ... --speed-up FILE` splits each prompt chunk and decode round between two Macs over a Thunderbolt 5 link using MCDMA. It is **not** memory pooling: each Mac holds the whole model (the Flash Next 6-bit model is 158 GB of weights in upstream docs). Requirements in upstream's `docs/speed-up-mode.md`: macOS >= 26.2, Zig 0.17.0, the `zig-flashnext` branch, a one-time kernel dump and a settings JSON per rank:

```json
{
  "rank": 0,
  "library": ".../libmcdma-fabric.dylib",
  "links": [
    {
      "peer": 1,
      "device": "rdma_en4",
      "via": "en4/192.0.2.2",
      "port": 7490,
      "name": "speedup"
    }
  ]
}
```

N-link bonding allows 1 to 8 devices. Numerics note from upstream: replies are bit-identical across draft depths on both Macs, but can differ from a single Mac's reply because projection halves are summed in a different order: gate it (see `SKILL.md`). Upstream says the 1.0.x release binary path has not passed the same gate yet.

On NVIDIA hardware, multi-node TensorFold exists only as the community DGX Spark recipe (one rank per Spark; `./start.sh`, `./stop.sh`; env `MEM_NEED_GIB`, `TF_FLASHNEXT_ROCE`). Upstream TensorFold flags for CUDA multi-node TP are **unverified** (none found). The recipe's KV cache is FP8 by default, which is lossy: gate it.

## exo v1.0.71

Zero-config device discovery; OpenAI, Claude Messages, Responses and Ollama-compatible API and dashboard at `http://localhost:52415`. MLX backend with MLX distributed; the README claims tensor-parallel speedups of 1.8x on 2 devices and 3.2x on 4 (vendor claims: measure yours). Linux currently runs on CPU only.

- RDMA over Thunderbolt 5: macOS >= 26.2 on every device, enabled once with `rdma_ctl enable` from Recovery, every device connected to all others, TB5 cables, identical OS versions; on a Mac Studio the TB5 port next to the Ethernet port cannot be used.
- Options and env: `--no-worker`, `EXO_LIBP2P_NAMESPACE`, `EXO_OFFLINE`, `EXO_MODELS_DIRS`, `EXO_MODELS_READ_ONLY_DIRS`, `EXO_DEFAULT_MODELS_DIR`, `EXO_FAST_SYNCH`, `EXO_TRACING_ENABLED`, `EXO_ENABLE_IMAGE_MODELS`.
- Discovery is automatic, so treat the LAN as trusted and check the exo docs for what `EXO_LIBP2P_NAMESPACE` isolates before relying on it (unverified).

## Not verified here

- Dynamo multi-node DynamoGraphDeployment fields; SGLang multi-node on DGX Spark playbook (`nvidia/sglang`) and TensorRT-LLM playbook (`nvidia/trt-llm`) contents.
- llama.cpp release-tag stamp: the docs were read from master at build b11556; no stable tag.
- exo RDMA plus tensor-parallel behaviour beyond what the README states.
