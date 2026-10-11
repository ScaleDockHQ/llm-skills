# Fabric and GPUDirect RDMA

> Verified against NCCL v2.32.3 and nccl-tests v2.21.1 (docs.nvidia.com/deeplearning/nccl), 2026-10-11

Sources: NCCL user guide (GPU troubleshooting: GPU Direct, ACS, IOMMU; networking troubleshooting; env: GDR, DMA-BUF, GID).

## InfiniBand

- Subnet Manager required (`sudo sminfo`; `opensm` service if self-managed). Port must be Active/LinkUp with the expected Rate.
- Error counters via `perfquery`; fabric-wide `ibdiagnet`. If one rail fails or is slow, inspect its switch ports first.
- Registering pinned memory: remove the memlock limit or QP and MR creation fails (`ibv_create_qp`, `ibv_reg_mr`). Add `* soft memlock unlimited` and `* hard memlock unlimited` to `/etc/security/limits.conf` or the equivalent; log in again or restart the service (Slurm jobs need the new limits); verify `ulimit -l`.

## RoCE

- Needs a correctly configured lossless or congestion-controlled Ethernet fabric (PFC, ECN, DSCP); upstream says to investigate congestion control before changing NCCL when PFC, ECN, CNP or queue-drop counters grow.
- GID index: NCCL 2.21+ selects it dynamically, so leave `NCCL_IB_GID_INDEX` unset; on older versions find the RoCE v2 GID with `show_gids`. Wrong index gives `ibv_modify_qp failed with error Invalid argument`.
- `NCCL_IB_TC` may be required; values come from the switch or NIC vendor documentation.
- One QP per connection can underuse a RoCE network: try `NCCL_IB_QPS_PER_CONNECTION` above 1.

## GPUDirect RDMA (GPU memory straight to the NIC)

Two routes, per upstream:

1. **`nvidia-peermem`** (shipped with the CUDA driver): load on every boot with `sudo modprobe nvidia-peermem`; check with `lsmod | grep nvidia-peermem`. Persist with a `/etc/modules-load.d/` entry (needs approval).
2. **DMA-BUF** with a recent kernel and the open NVIDIA GPU driver: NCCL detects and enables it itself (`NCCL_DMABUF_ENABLE` default 1, auto-disabled when unsupported); `nvidia-peermem` is then unnecessary.

Distance control: `NCCL_NET_GDR_LEVEL` (LOC never, PIX same PCIe switch, PXB multiple switches, PHB same NUMA node via CPU, SYS across sockets). Unset lets NCCL choose; set it only when topology detection is wrong. Read `nvidia-smi topo -m`: a GPU and NIC that are PIX/PXB are the good pairing; SYS means traffic crosses sockets.

## ACS and IOMMU (bare metal)

- **ACS** on PCIe bridges redirects peer traffic to the CPU root complex, costing performance or causing hangs. Check `sudo lspci -vvv | grep ACSCtl` (SrcValid+ means maybe enabled). Disable via BIOS (VT-d/IO virtualization) or per bridge with `setpci ... ECAP_ACS+0x6.w=0000`, which resets on reboot for Broadcom PLX. In VMs ACS cannot be disabled; enable ATS on the NICs.
- **IOMMU:** on Linux bare metal, translated IOMMU mode is unsupported for PCIe peer-to-peer and risks silent corruption per the CUDA guide. Check `cat /proc/cmdline` and `dmesg | grep -iE 'iommu|dmar|default domain'`; "Default domain type: Translated" or "DMAR: IOMMU enabled" is concerning. A positive `nvidia-smi topo -p2p p` is not a full check.
- Both are BIOS or kernel changes: plan a reboot and a rollback.

## Intra-node

`nvidia-smi topo -p2p n` shows NVLink; `NCCL_P2P_LEVEL` and `NCCL_P2P_DISABLE` exist but are diagnostics, not defaults. NVLS (`NCCL_NVLS_ENABLE`, default 2) applies to third-generation NVSwitch systems with Hopper or later.
