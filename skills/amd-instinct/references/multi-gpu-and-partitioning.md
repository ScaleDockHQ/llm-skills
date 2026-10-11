# Multi-GPU, RCCL, partitioning and virtualization

> Verified against ROCm 10.1.0 release notes (known issues, GPU partitioning and virtualization sections), AMD SMI 27.1.0 CLI docs, 2026-10-11

## Topology first

```bash
amd-smi list -e            # maps enumeration index, BDF, UUID and oam_id (physical OAM slot)
amd-smi topology           # link types and hop counts between GPUs
amd-smi xgmi               # xGMI (Infinity Fabric) link information
amd-smi partition          # current compute and memory partition state
```

`--gpu` accepts the enumeration index, a BDF or a UUID. The index is discovery order, not a physical slot; use `oam_id` to find the card.

## RCCL

RCCL 2.30.7 ships with ROCm 10.1.0. RCCL reads the familiar `NCCL_*` variables.

Known issue (10.1.0, GitHub issue #8792): `allreduce` with the Low Latency (LL) protocol can return incorrect results on MI350 Series. AMD's workaround:

```bash
export NCCL_PROTO=LL128,Simple
```

Apply it for MI350X, MI355X and MI350P hosts until a fixed release; remove it after updating and re-testing.

Run an all-reduce before the model with the RCCL test binary (AMD's acceptance guide builds it as `build/all_reduce_perf`):

```bash
./build/all_reduce_perf -b 8 -e 8G -f 2 -g 8
```

AMD's MI300X acceptance threshold for this command on an 8-GPU node is at least 304 GB/s. Treat that as a reference for MI300X only.

## Compute and memory partitioning

Instinct GPUs support compute partitions (SPX, DPX, QPX, CPX) and memory partitions (NPS1, NPS2, NPS4). The matrix lists which pairs each series supports (for example SPX with NPS1 is available everywhere; CPX with NPS2 and CPX with NPS4 appear for different series). Read the live "GPU partitioning support" table for your series.

- `amd-smi partition` shows the current state. Changing it is a write operation: see `amd-smi set --help` for the exact flags on your version, and expect to unload workloads and possibly reload the driver or reboot.
- A partitioned GPU shows as several logical GPUs; the engine's `--tensor-parallel-size` and memory budgets then apply per partition. Re-run `amd-smi list` after a change.
- Passthrough and ESXi passthrough support SPX with NPS1 only. SR-IOV supports 1 VF in SPX/NPS1, and on some series 2 VFs (DPX) or 8 VFs (CPX); multi-VF needs compatible firmware.

## Virtualization

SR-IOV needs GIM 9.3.0.K. KVM passthrough and SR-IOV combinations differ per series and host/guest OS (for example KVM SR-IOV with an Ubuntu 26.04 host and guest for MI355X, MI350X, MI325X, MI300X and MI210 was added in 10.1.0). Check the matrix before building VM images.

## Other multi-GPU known issues in 10.1.0

- Multi-application workloads with heavy SDMA transfers can trigger an intermittent GPU page fault on some Instinct GPUs; the job hangs and the queue may recover only after about 15 minutes (issue #8844). Avoid running several memory-heavy jobs on the same GPUs.
- MI200: device-to-device `hipMemcpyAsync` with the DMA engine path (`hipMemcpyDeviceToDeviceNoCU`) can fail silently (issue linked in the release notes). Use `hipMemcpyDeviceToDevice`.
