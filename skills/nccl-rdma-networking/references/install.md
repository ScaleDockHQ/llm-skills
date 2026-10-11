# NCCL and RDMA tooling: install

> Verified against NCCL v2.32.3 and nccl-tests v2.21.1 (docs.nvidia.com/deeplearning/nccl), 2026-10-11

Sources: NCCL user guide (Setup), nccl-tests README, PyPI nvidia-nccl packages.

## NCCL

- Frameworks usually bring their own: PyTorch wheels depend on `nvidia-nccl-cu12` or `nvidia-nccl-cu13` (both at 2.32.3 on PyPI today). Check what the engine uses: `python3 -c 'import torch;print(torch.cuda.nccl.version())'`. A system NCCL (packages `libnccl2`/`libnccl-dev` from the NVIDIA CUDA repository, or a source build) matters for nccl-tests and non-PyTorch apps.
- Build from source: `git clone https://github.com/NVIDIA/nccl && make -j src.build`; for TLS on NCCL's socket transport add `TLS_BACKEND=OPENSSL3` (OpenSSL 3 dev packages required). NCCL does not encrypt network traffic by default.

## nccl-tests

```bash
git clone https://github.com/NVIDIA/nccl-tests && cd nccl-tests
make MPI=1 MPI_HOME=/path/to/mpi CUDA_HOME=/usr/local/cuda NCCL_HOME=/usr
./build/all_reduce_perf -b 8 -e 128M -f 2 -g 1
```

Set `NCCL_HOME` to the NCCL install that the application will load; mismatches give misleading results.

## RDMA userland

`rdma-core` and `ibverbs-utils` (`ibstat`, `ibv_devinfo`, `rdma`), `perftest` (`ib_write_bw`, `ib_write_lat`; build with CUDA for `--use_cuda`), `infiniband-diags` (`perfquery`, `ibping`, `ibdiagnet` from MLNX tools), NVIDIA DOCA-OFED or MLNX_OFED for ConnectX drivers. Package names vary by distribution; follow the vendor guide for the installed NIC.

## Kernel modules

`nvidia-peermem` ships with the CUDA driver; load it (`sudo modprobe nvidia-peermem`) or rely on DMA-BUF with the open driver. Both need approval.
