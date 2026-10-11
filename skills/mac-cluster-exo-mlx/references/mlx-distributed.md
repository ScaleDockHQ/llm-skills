# MLX distributed with mlx-lm

> Verified against mlx 0.32.3 docs (distributed, launching_distributed) and mlx-lm main `mlx_lm/server.py` (0.32.0), 2026-10-11

MLX ships `mlx.launch` and `mlx.distributed_config`. `mlx_lm.server` initializes `mx.distributed` itself: with more than one process it runs distributed, tensor-parallel by default and pipeline-parallel with `--pipeline`. In distributed mode loading adapters or draft models is not supported (server error text), so no LoRA or speculative decoding across the cluster.

## Steps

```bash
# 1. identical environments on every node (native arm64 Python 3.11+, same mlx and mlx-lm versions)
python3 -m pip install -U mlx mlx-lm            # inside the same venv path on every node

# 2. ssh keys so the launcher can reach every node without prompts
ssh node2 'python3 -c "import mlx.core as mx; print(mx.__version__)"'

# 3. hostfile: ring over Thunderbolt, or JACCL when RDMA is enabled (see networking-and-rdma.md)
mlx.distributed_config --verbose --hosts node1,node2 --backend ring --output ring.json

# 4. serve, model must be reachable from every node (same HF cache contents or shared path)
mlx.launch --hostfile ring.json -- mlx_lm.server --model mlx-community/<model>-4bit --host 127.0.0.1 --port 8080
mlx.launch --hostfile ring.json -- mlx_lm.server --model mlx-community/<model>-4bit --pipeline     # pipeline parallel
```

`mlx.launch -n 4 my_script.py` runs local processes; `--hosts ip1,ip2` or `--hostfile` runs over ssh. The backend is selected when the script calls `mx.distributed.init(backend=...)` (`any`, `ring`, `jaccl`, `mpi`, `nccl`); `any` tries what is available. JACCL needs a hostfile with `ssh`, `ips` (rank 0 reachable by all) and a per-peer `rdma` device list (`null` on the diagonal) and a full mesh.

## Notes

- Check `mlx_lm.server --help` on the installed version for the exact flag list (`--pipeline`, `--prefill-step-size`, `--max-tokens`; see the `mlx` skill's `serving.md`).
- The server binds loopback by default; expose it only on the private cluster network with a gateway in front.
- Every node needs the weights: pre-download with the same revision on all nodes (`hf download <repo>`) to avoid a slow first load.
- `mlx.launch` over ssh starts processes on remote hosts: ask before the first launch and know how to stop them (`pkill -f mlx_lm.server` on each node).

## Official links

- https://ml-explore.github.io/mlx/build/html/usage/distributed.html
- https://ml-explore.github.io/mlx/build/html/usage/launching_distributed.html
- https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/server.py
