# NCCL and RDMA troubleshooting

> Verified against NCCL v2.32.3 and nccl-tests v2.21.1 (docs.nvidia.com/deeplearning/nccl), 2026-10-11

Sources: NCCL user guide (Troubleshooting), vLLM troubleshooting docs. Enable `NCCL_DEBUG=INFO NCCL_DEBUG_SUBSYS=INIT,NET` first.

| Symptom                                                   | Likely cause                                                                                   | Fix                                                                          |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Log shows `NET/Socket`                                    | No usable HCA, `NCCL_IB_DISABLE=1`, wrong `NCCL_IB_HCA`, devices missing in container, memlock | Check `ibstat`, `/dev/infiniband`, `ulimit -l`, env; use `=` exact HCA names |
| `NET/IB` but not `GDRDMA`                                 | `nvidia-peermem` not loaded and DMA-BUF unsupported; topology distance; ACS                    | Load module or use open driver with DMA-BUF; check `topo -m`, ACS            |
| `ibv_create_qp failed` or `ibv_reg_mr failed`             | Pinned memory limit                                                                            | memlock unlimited; container `IPC_LOCK`                                      |
| `ibv_modify_qp failed with error Invalid argument` (RoCE) | Wrong GID index (NCCL < 2.21) or `NCCL_IB_GID_INDEX` set wrongly                               | Unset on 2.21+; `show_gids` on older                                         |
| `ibv_poll_cq` error 12 on big network                     | IB timeout too low                                                                             | Raise `NCCL_IB_TIMEOUT` (timeout 4.096 us x 2^value x retries)               |
| Init hangs, one node silent                               | Wrong interface picked for bootstrap, firewall, ports, different NCCL versions                 | `NCCL_SOCKET_IFNAME`, open port range, align versions                        |
| `ncclCommInitRank` "unhandled system error" in container  | No `IPC_LOCK` or `/dev/shm`                                                                    | Add capability and shm mount                                                 |
| Works on 1 node, slow on 2                                | Socket transport, one rail down, congestion                                                    | Ladder; `ibdiagnet`; `rdma statistic`, `ethtool -S`                          |
| Intermittent stalls, long tails                           | Retransmissions, PFC/ECN misconfig, degraded link                                              | `ib_write_lat`, `mlxlink`, switch counters                                   |
| Hang or low speed on PCIe boxes                           | ACS or translated IOMMU                                                                        | Disable per the GPU troubleshooting guide, reboot                            |
| `ibstat` port Down/Init                                   | Cable, switch, no Subnet Manager                                                               | `sminfo`, start `opensm`, replace cable                                      |
| Wrong NIC used on multi-NIC nodes                         | Auto-selection or rail mismatch                                                                | `NCCL_IB_HCA`, `NCCL_CROSS_NIC`, `NCCL_SOCKET_IFNAME`                        |
| No debug output at all with `NCCL_DEBUG=ATTN`             | NCCL older than 2.32 does not know ATTN                                                        | `NCCL_DEBUG=WARN NCCL_DEBUG_LEVELS=ATTN`                                     |
| nccl-tests fine, engine slow                              | Engine uses another NCCL, env differs, CUDA graphs off, small messages                         | Compare versions and env; check latency rows                                 |
