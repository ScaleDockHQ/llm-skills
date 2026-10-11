# Multi-node inference: interconnect, NCCL and the DGX Spark dual-node example

> Verified against NCCL 2.30.7 (user guide: environment variables), NVIDIA dgx-spark-playbooks main as of 2026-10-08 (nvidia/connect-two-sparks, nvidia/nccl, nvidia/vllm), vLLM v0.31.0 (docs: serving/parallelism_scaling), skills/self-hosted-llms references (hardware-dgx-spark, engine-tensorfold, read only), 2026-10-11

Cross-node tensor parallelism sends activations over the network on every layer. Whether it is worth doing is decided by the link, not by the engine flag.

## Link types

| Link                                | Used for                  | Notes                                                                                                                                             |
| ----------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| NVLink / NVSwitch                   | Intra-node TP, EP         | Fastest. Multi-node NVLink domains (for example GB200 racks) are configured through engine and Mooncake/UCX options, see `disaggregated-serving`. |
| InfiniBand (ConnectX-7 and similar) | Cross-node TP/PP/EP       | RDMA with GPUDirect where the host supports it.                                                                                                   |
| RoCE v2 (Ethernet RDMA)             | Same, on Ethernet fabrics | Needs a lossless or tuned fabric and the right GID index (`NCCL_IB_GID_INDEX`).                                                                   |
| Plain TCP sockets                   | Fallback                  | NCCL logs `via NET/Socket`; vLLM's docs call it inefficient for cross-node TP.                                                                    |
| Thunderbolt 5 RDMA                  | Apple Silicon clusters    | exo and TensorFold speed-up mode, macOS >= 26.2.                                                                                                  |

## Read-only discovery

```bash
nvidia-smi topo -m                       # GPU-GPU and GPU-NIC paths
ibv_devinfo -l; ibdev2netdev             # RDMA devices and which netdev they map to
ip -br addr; ip -br link                 # interfaces and addresses
ethtool <iface> | grep -E 'Speed|Link detected'
show_gids 2>/dev/null | head -20         # RoCE GID table (MLNX_OFED tool, if installed)
ping -c3 -I <iface> <peer-ip>
ssh <peer> 'nvidia-smi -L; ip -br addr' # same checks on the second node
```

Check that both nodes have the same driver, CUDA, NCCL, engine image and model files at the same path before debugging anything else.

## NCCL environment variables (NCCL user guide)

| Variable                          | Effect                                                                                                                             | Use                                                                         |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `NCCL_SOCKET_IFNAME`              | Which IP interfaces NCCL uses for bootstrap and sockets. By default `lo` and `docker*` are excluded unless they are the only ones. | Set to the interface on the fabric subnet, or `^docker,lo` to exclude.      |
| `NCCL_IB_HCA`                     | Which RDMA devices to use.                                                                                                         | For example `mlx5`, or exact device names from `ibv_devinfo -l`.            |
| `NCCL_IB_GID_INDEX`               | GID index for RoCE.                                                                                                                | Pick the RoCE v2 IPv4 GID from `show_gids`.                                 |
| `NCCL_IB_DISABLE`                 | Disable IB/RoCE and fall back to sockets.                                                                                          | Use only to prove the RDMA path is the problem.                             |
| `NCCL_NET_GDR_LEVEL`              | GPUDirect RDMA distance threshold (formerly `NCCL_IB_GDR_LEVEL`).                                                                  | Leave default unless debugging.                                             |
| `NCCL_P2P_DISABLE`                | Disable intra-node peer-to-peer.                                                                                                   | Debugging only.                                                             |
| `NCCL_DEBUG`, `NCCL_DEBUG_SUBSYS` | Logging.                                                                                                                           | `NCCL_DEBUG=INFO` (or `TRACE` as vLLM suggests) shows the chosen transport. |

NCCL variables do **not** configure UCX/NIXL transfers (vLLM NixlConnector) or Mooncake: those use `UCX_*` and engine variables (see `disaggregated-serving`).

## Prove the fabric before blaming the engine

1. Run `nccl-tests` (`all_reduce_perf` or `all_gather_perf`) across the two nodes with `mpirun`, using the same interface and HCA variables the engine will use. The NVIDIA Spark playbook builds NCCL v2.30.7-1 with `sm_121` and runs `all_gather_perf`.
2. Run the engine with `NCCL_DEBUG=INFO` once and confirm the transport line says IB/RoCE (GDRDMA if available), not `NET/Socket`.
3. Only then measure tokens/s and TTFT versus one node plus data-parallel replicas.

## DGX Spark dual-node (one example)

Two DGX Sparks (GB10, 128 GB unified memory each) linked by the ConnectX-7 200 GbE QSFP ports.

Facts from NVIDIA's `connect-two-sparks` playbook:

- Use a direct QSFP cable between the **same physical port** on both machines. `ibdev2netdev` shows which interface is `Up`.
- Each physical port appears as **two logical interfaces** (for example `enp1s0f1np1` and `enP2p1s0f1np1`). One cable gives full bandwidth. If you use two cables, all four interfaces need IP addresses.
- Configure static addresses in one private subnet with netplan (the playbook uses `/etc/netplan/40-cx7.yaml`).

Interface choice, as the sources differ:

- The NVIDIA `nccl` playbook sets `UCX_NET_DEVICES`, `NCCL_SOCKET_IFNAME` and `OMPI_MCA_btl_tcp_if_include` to the **management** Ethernet (`enP7s7`, or Wi-Fi `wlP9s9`) for MPI bootstrap, while NCCL's bulk traffic is expected to use the ConnectX-7 RDMA devices.
- The NVIDIA `vllm` playbook uses the **CX7** interface (variable `MN_IF_NAME`) for `VLLM_HOST_IP`, `UCX_NET_DEVICES`, `NCCL_SOCKET_IFNAME`, `GLOO_SOCKET_IFNAME`, `TP_SOCKET_IFNAME` and `MASTER_ADDR`, plus `RAY_memory_monitor_refresh_ms=0`.
- The repo's `self-hosted-llms` hardware notes warn: assuming the 10 GbE port is the inter-node link is a common mistake, point NCCL at the ConnectX-7 interface.

Resolve it by testing: run `nccl-tests` once per setting and use the interface that yields the RDMA bandwidth and the `IB` transport line.

vLLM on two Sparks (from the NVIDIA playbook, image `nvcr.io/nvidia/vllm:26.05-py3`, whose `run_cluster.sh` is patched to pip-install Ray):

```bash
vllm serve meta-llama/Llama-3.3-70B-Instruct --tensor-parallel-size 2 \
  --max-model-len 2048 --gpu-memory-utilization 0.8 --distributed-executor-backend ray
```

Memory budgeting: each Spark has 128 GB unified memory shared with the OS, so keep `--gpu-memory-utilization` conservative (the playbook uses 0.8) and follow the `self-hosted-llms` memory-safety rules before adding a second engine on the same node.

TensorFold on two Sparks (community recipe, not upstream TensorFold; see `engine-matrix.md`): one rank per Spark, needs the direct ConnectX-7 link, IPv4 on each end in one private subnet and a RoCE v2 GID; `MEM_NEED_GIB` (about 102 GiB free for its 1M-token window) and `TF_FLASHNEXT_ROCE` control it; its default FP8 KV cache is lossy and needs the numerics gate.

SGLang and TensorRT-LLM Spark playbooks (`nvidia/sglang`, `nvidia/trt-llm`) exist upstream but were not read: **unverified**.

## Common failure map

The `NET/Socket` and `No available node types` rows come from the vLLM docs; the others are general operating guidance, not upstream statements.

| Symptom                                                           | Likely cause                              | Check                                                                         |
| ----------------------------------------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------- |
| Startup hang at NCCL init                                         | Wrong interface or firewall between nodes | `NCCL_DEBUG=INFO`, `NCCL_SOCKET_IFNAME`, ports reachable both ways            |
| Works but slow, `NET/Socket` in logs                              | RDMA not used                             | `NCCL_IB_HCA`, `ibv_devinfo`, container `--privileged`/`IPC_LOCK`, `/dev/shm` |
| `No available node types can fulfill resource request` (vLLM Ray) | Multi-IP node                             | Set `VLLM_HOST_IP` on every node                                              |
| RoCE errors or timeouts                                           | Wrong GID or lossy fabric                 | `NCCL_IB_GID_INDEX`, switch PFC/ECN settings                                  |
| OOM on one node only                                              | Unequal memory or other tenants           | `nvidia-smi`, `free -h` on both nodes                                         |
