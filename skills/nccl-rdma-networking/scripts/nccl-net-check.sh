#!/usr/bin/env bash
# Read-only per-node check for NCCL over RDMA. Needs bash 3.2+. No root, no changes, no secrets printed.
set -u

section() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

section "GPUs and topology"
if have nvidia-smi; then
  nvidia-smi --query-gpu=index,name,driver_version --format=csv,noheader
  nvidia-smi topo -m 2>/dev/null | head -30
  nvidia-smi topo -p2p n 2>/dev/null | head -15
else
  echo "nvidia-smi not found"
fi

section "RDMA ports"
if have ibstatus; then ibstatus 2>/dev/null | grep -E 'Infiniband device|state|rate|link_layer'; fi
if have ibstat; then ibstat 2>/dev/null | grep -E "CA '|State|Physical state|Rate|Link layer"; fi
if have rdma; then rdma link show 2>/dev/null; fi
have ibv_devinfo || echo "ibv_devinfo not found (install rdma-core / ibverbs-utils)"
ls /dev/infiniband 2>/dev/null | head -5

section "Kernel modules"
lsmod 2>/dev/null | grep -E 'nvidia_peermem|nvidia-peermem|mlx5_core|mlx5_ib|ib_core|rdma_cm' | awk '{print $1}'

section "Limits and IOMMU"
echo "memlock: $(ulimit -l)"
tr ' ' '\n' </proc/cmdline 2>/dev/null | grep -i -E 'iommu|intel_iommu|amd_iommu' || echo "no iommu kernel args"
dmesg 2>/dev/null | grep -i -E 'iommu|dmar|default domain' | head -3 || true

section "ACS (needs root for full lspci)"
if [ "$(id -u)" -eq 0 ] && have lspci; then
  lspci -vvv 2>/dev/null | grep -c 'ACSCtl.*SrcValid+' | sed 's/^/bridges with SrcValid+: /'
else
  echo "skipped (run as root to check: lspci -vvv | grep ACSCtl)"
fi

section "NCCL environment (names only)"
env | cut -d= -f1 | grep '^NCCL_' || echo "no NCCL_ variables set"

section "NCCL versions"
python3 -c 'import torch;print("torch NCCL", torch.cuda.nccl.version())' 2>/dev/null || echo "torch not importable"
ldconfig -p 2>/dev/null | grep -E 'libnccl\.so' | head -3
have all_reduce_perf && echo "nccl-tests: $(command -v all_reduce_perf)"
have ib_write_bw && echo "perftest: $(command -v ib_write_bw)"
