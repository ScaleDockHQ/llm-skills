# NCCL: the test ladder

> Verified against NCCL v2.32.3 and nccl-tests v2.21.1 (docs.nvidia.com/deeplearning/nccl), 2026-10-11

Sources: NCCL user guide (Troubleshooting: networking, diagnostics, performance), nccl-tests README and PERFORMANCE.md, perftest tools.

Prove each rung on every node pair before the next.

## 1. NIC and link

```bash
ibstatus; ibstat          # State: Active, Physical state: LinkUp, expected Rate, consistent Link layer
rdma link show
sudo sminfo               # InfiniBand: a Subnet Manager must answer (opensm on at least one node)
sudo perfquery -x <lid>   # SymbolErrorCounter, LinkErrorRecoveryCounter, LinkDownedCounter should not grow
ethtool -S <nic>          # RoCE: errors, drops, pause and PFC counters
```

`mlxlink -d <mst_device>` shows width, speed and error state when a link is degraded. `ibdiagnet` (needs SM access) checks the whole fabric, useful when one rail misbehaves.

## 2. Point-to-point RDMA

```bash
ib_write_bw -d mlx5_0 -a                              # server
ib_write_bw -d mlx5_0 <server> -a                     # client, host memory
ib_write_bw -d mlx5_0 --use_cuda=0 <server> -a        # GPU memory (GPUDirect RDMA path)
ib_write_bw -d mlx5_0 --use_cuda=0 --use_cuda_dmabuf <server> -a   # DMA-BUF, if the build supports it
ib_write_lat -d mlx5_0 <server>                       # tail latency
rdma statistic                                        # rnr_nak_retry_err, packet_seq_err, local_ack_timeout_err must not grow
```

GPU-memory results far below host-memory results mean GPUDirect RDMA is not working (see `fabric-and-gpudirect.md`). Check `ib_write_bw --help` for what your perftest build supports. RoCE connectivity without perftest: `rping -s -a <ip> -V -C 10` and `rping -c -a <ip> -S <src_ip> -V -C 10`. InfiniBand: `sudo ibping -S` and `sudo ibping <lid>`.

## 3. NCCL collectives (nccl-tests)

```bash
# build once: make MPI=1 MPI_HOME=/path/to/mpi CUDA_HOME=/usr/local/cuda NCCL_HOME=/usr
./build/all_reduce_perf -b 8 -e 128M -f 2 -g 8                      # one node, 8 GPUs
NCCL_DEBUG=INFO mpirun -np 16 -N 8 ./build/all_reduce_perf -b 8 -e 8G -f 2 -g 1   # two nodes
```

Flags: `-b`/`-e` size range, `-f` step factor, `-g` GPUs per thread, `-c` check results, `-n` iterations, `-w` warmup. Read **busbw**, not algbw: for all-reduce busbw = algbw x 2(n-1)/n, comparable to the hardware peak. Compare large-message busbw with the NIC line rate and with NVLink for intra-node. `NCCL_TESTS_SPLIT` can run parallel groups, for example `MOD 8` to exercise only the inter-node path.

## 4. Read the NCCL log

```bash
NCCL_DEBUG=INFO NCCL_DEBUG_SUBSYS=INIT,NET NCCL_DEBUG_FILE=/tmp/nccl.%h.%p.log <command>
grep -E 'NET/(IB|Socket)|GDRDMA|Using network|NCCL version' /tmp/nccl.*.log | sort | uniq -c | head
```

- `NET/IB/GDRDMA`: InfiniBand or RoCE with GPUDirect RDMA. Efficient.
- `NET/IB` without GDRDMA: RDMA, but through host memory; fix GPUDirect.
- `NET/Socket`: plain TCP; cross-node tensor parallelism will be slow (vLLM docs). Cause: no usable HCA, `NCCL_IB_DISABLE=1`, wrong `NCCL_IB_HCA`, missing devices in a container, or memlock limits.
- Use `NCCL_DEBUG=TRACE` only briefly: it logs every call. `NCCL_DEBUG_FILE` with `%h` and `%p` keeps per-process files unique.

## 5. The engine

Run the engine with `NCCL_DEBUG=INFO` once and apply the same grep. See `containers-and-engines.md`.

`scripts/nccl-net-check.sh` collects rung 1 and the host settings on one node.
