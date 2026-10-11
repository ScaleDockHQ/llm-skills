# Connecting two DGX Stations

> Verified against DGX OS 7.6.0 and DGX Station Development Guide, 2026-10-11

NVIDIA's playbook (build.nvidia.com/station/connect-two-stations):

- Two ConnectX-8 cables, one per rail, no switch, no bonding: QSFP0 to QSFP0 and QSFP1 to QSFP1. Rail 0 is `mlx5_0`, rail 1 is `mlx5_1`. Each rail is an independent 400 Gb/s RoCEv2 path. There is no inter-station NVLink.
- Setup runs from a separate control host over SSH: rail IPs on private subnets, MTU 9000, RoCEv2 runtime settings, then jumbo ping, RDMA port state, route checks, and an `ib_write_bw` host-memory test per rail.
- For GPU workloads (NCCL, Ray, vLLM) also pass the GDR check (CUDA DMA-BUF / Data Direct). If it fails with `mlx5dv_reg_dmabuf_mr` or error 524, the playbook points at ACS/IOMMU: `sudo rdma_topo check`, then its GRUB script, then reboot both. Do this only after the basic fabric works, and with approval.
- Crossed rails cause hard-to-debug RDMA/NCCL issues; cable errors or `High Temperature` module messages need physical action first.
- The NVIDIA vLLM playbook supports one DGX Station, not a two-Station cluster. Use a multi-node setup from the engine skill and validate NCCL yourself.

Read-only checks: `ibdev2netdev`, `ip -br addr`, `rdma link show`, `ping -M do -s 8972 <peer rail ip>`.

Same image IDs and model paths on both stations (compare IDs, not tags).

## Sources

- <https://build.nvidia.com/station/connect-two-stations>
- <https://build.nvidia.com/station/connect-two-stations/troubleshooting>
