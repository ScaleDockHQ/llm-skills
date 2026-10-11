# NCCL in containers, Kubernetes and engines

> Verified against NCCL v2.32.3 and nccl-tests v2.21.1 (docs.nvidia.com/deeplearning/nccl), 2026-10-11

Sources: NCCL user guide; vLLM docs "Parallelism and scaling" and "Troubleshooting" (vLLM v0.31.0).

## Container requirements for RDMA

- **Devices:** the RDMA character devices must be visible (`/dev/infiniband`). vLLM's guide appends `--privileged -e NCCL_IB_HCA=mlx5` to its Ray helper script for InfiniBand; on Kubernetes use your RDMA device plugin (for example the NVIDIA network operator) rather than privileged pods, and ask the cluster admin.
- **`IPC_LOCK`:** add the capability so memory can be pinned; without it `ncclCommInitRank` can fail with "unhandled system error" and no detail.
- **Shared memory:** mount `/dev/shm` (Docker `--ipc=host --shm-size=16G -v /dev/shm:/dev/shm`; Kubernetes an `emptyDir` with `medium: Memory`).
- **Memlock:** container ulimit `memlock` unlimited if the runtime defaults are low (`--ulimit memlock=-1`).
- **Network:** pods need routable IPs between nodes (host network or a secondary RDMA network); bootstrap uses `NCCL_SOCKET_IFNAME`.
- **GPUDirect RDMA:** the host needs `nvidia-peermem` or DMA-BUF; containers inherit it.

```yaml
securityContext:
  capabilities: { add: ["IPC_LOCK"] }
volumeMounts:
  - { mountPath: /dev/shm, name: dshm }
volumes:
  - { name: dshm, emptyDir: { medium: Memory } }
```

## vLLM

- Set `VLLM_HOST_IP` per node to an address on a private segment (traffic between nodes is unencrypted and the data format can be exploited if an adversary reaches it). Set `NCCL_SOCKET_IFNAME` and `GLOO_SOCKET_IFNAME` when the wrong interface is chosen.
- Confirm RDMA: `NCCL_DEBUG=TRACE vllm serve ...` and look for `[send] via NET/IB/GDRDMA` (good) versus `NET/Socket` (slow for cross-node tensor parallelism).
- Cross-node tensor parallelism needs fast links; otherwise prefer pipeline parallelism across nodes and tensor parallelism inside a node.
- vLLM's troubleshooting page has a PyTorch NCCL, Gloo and vLLM `PyNcclCommunicator` test script; run it with `torchrun` on two nodes with `NCCL_DEBUG=TRACE` before blaming the engine.

## SGLang, TensorRT-LLM, Dynamo, NIXL

They use NCCL for collectives (KV-transfer layers in disaggregated setups can also use RDMA) with the same host prerequisites. Apply the ladder; engine-specific flags belong to the engine skills. For disaggregated prefill/decode over RDMA, see `disaggregated-serving`.

## Ray and Slurm

Ray head and workers need reachable IPs; Slurm jobs must inherit the raised memlock limit. Launch the nccl-tests binary the same way as the real job (same `mpirun` or `srun`) so env and limits match.
