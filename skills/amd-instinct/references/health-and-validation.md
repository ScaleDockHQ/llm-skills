# Health checks and validation

> Verified against AMD Instinct MI300X Customer Acceptance Guide (rocm.docs.amd.com/en/latest/how-to/system-optimization/mi300x.html), AMD SMI 27.1.0, 2026-10-11

AMD publishes acceptance criteria for MI300X. Use the structure for other parts and take thresholds from AMD's guide for that part.

## Basic health (read-only)

| Check                | Command                                                      | Pass                                                                            |
| -------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| OS                   | `cat /etc/os-release`                                        | Version in the compatibility matrix                                             |
| Kernel arguments     | `cat /proc/cmdline`                                          | Contains `pci=realloc=off`, `amd_iommu=on` (or `intel_iommu=on`) and `iommu=pt` |
| Driver errors        | `sudo dmesg -T \| grep amdgpu \| grep -i error`              | No output                                                                       |
| System memory        | `lsmem \| grep "Total online memory"`                        | 1.5T or more for an 8x MI300X node                                              |
| GPUs present         | `lspci \| grep MI300X`                                       | All 8 listed                                                                    |
| Link speed and width | `sudo lspci -d 1002:74a1 -vvv \| grep -e DevSta -e LnkSta`   | 32 GT/s, x16, no `FatalErr+`                                                    |
| Idle metrics         | `amd-smi monitor -putm`                                      | Idle values                                                                     |
| Kernel log           | `sudo dmesg -T \| grep -i -E 'error\|warn\|fail\|exception'` | No output                                                                       |

The kernel-argument row is AMD's MI300X acceptance criterion. Changing boot arguments needs approval and a rollback plan (keep the previous GRUB entry); do not apply them to hosts that do not need them.

## Validation tools

ROCm Validation Suite (`rvs`) with the MI300X configs: GPU properties (`gpup_single.conf`), GPU stress test (`MI300X/gst_single.conf`, pass is `met: TRUE`), input energy delay product (`iet_single.conf`), memory test (`mem.conf`, about 2 TB/s on MI300X), PCIe bandwidth (`pebb_single.conf`), PCIe qualification (`peqt_single.conf`) and peer-to-peer (`pbqt_single.conf`).

Interconnect and compute benchmarks from the same guide (MI300X thresholds):

- `TransferBench a2a` at least 32.9 GB/s; `TransferBench p2p` at least 33.9 GB/s unidirectional and 43.9 GB/s bidirectional.
- RCCL `all_reduce_perf -b 8 -e 8G -f 2 -g 8` at least 304 GB/s.
- `rocblas-bench` GEMM: FP32 at least 94100 GFLOPS, BF16 at least 130600 GFLOPS, INT8 at least 162700 GFLOPS (parameters in the guide).
- BabelStream Triad at least 3,885,301 MB/s.

These are stress tests: run them on an idle node, with approval, before production, and never on a node serving traffic.

## When a node is flaky

1. Collect: `amd-smi list`, `amd-smi metric`, `amd-smi static`, `amd-smi firmware`, `amd-smi bad-pages`, `amd-smi ras` (RAS interfaces are unavailable on MI350P in 10.1.0), and `dmesg` lines for `amdgpu`.
2. Compare driver and firmware with the matrix.
3. A single GPU with bad pages or repeated resets: isolate it with `HIP_VISIBLE_DEVICES` and tell your hardware vendor.
4. `amd-smi reset --gpureset --gpu <id>` resets a GPU; it kills running work, so get approval first.
