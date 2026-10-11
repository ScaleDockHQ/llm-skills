# Parallelism and multi-node

> Verified against mistral.rs v0.9.4 (docs `guides/perf/distributed-inference`, `guides/perf/topology`, `reference/environment-variables`), 2026-10-11

| Mode                     | Scope             | Transport                        | Use when                                  |
| ------------------------ | ----------------- | -------------------------------- | ----------------------------------------- |
| NCCL tensor parallelism  | One machine, CUDA | NCCL collectives                 | Several similar local GPUs (default path) |
| Layer mapping + CUDA P2P | One machine       | peer access, else CPU staging    | NCCL unavailable or disabled, uneven GPUs |
| Multi-node NCCL          | Several machines  | NCCL, `MISTRALRS_MN_*` variables | Tensor parallel across machines           |
| Ring backend             | Several machines  | `RING_CONFIG` JSON               | You explicitly want ring                  |

## Selection order (CUDA build, no manual mapping)

1. One visible GPU: runs there.
2. Several GPUs: NCCL tensor parallelism if the binary has `cuda nccl` and `MISTRALRS_NO_NCCL` is unset.
3. Otherwise layer mapping (P2P when the driver allows it, else via CPU).
4. `MISTRALRS_MN_GLOBAL_WORLD_SIZE` set: NCCL extended across nodes.
5. `RING_CONFIG` set and `ring` feature compiled in: ring (set `MISTRALRS_NO_NCCL=1` if NCCL is also compiled in).

The layout is printed at `INFO` on startup. Prebuilt Linux CUDA binaries from the installer enable `nccl` when `libnccl` was found
(override with `MISTRALRS_INSTALL_NCCL=1` or `MISTRALRS_INSTALL_NO_NCCL=1`).

## One machine, several GPUs

```bash
CUDA_VISIBLE_DEVICES=0,1 mistralrs serve --host 127.0.0.1 -m Qwen/Qwen3-32B --quant 4     # NCCL TP across both
MISTRALRS_NO_NCCL=1 mistralrs serve -n "0:44;1:20" -m Qwen/Qwen3-32B --quant 4            # manual layer split
nvidia-smi topo -m                                                                       # read-only interconnect view
```

- TP uses all visible GPUs. Attention heads must divide evenly across GPUs; KV heads must divide evenly or be replicated evenly.
  An incompatible count is an error, not a silent smaller subset: restrict with `CUDA_VISIBLE_DEVICES`.
- `-n/--device-layers` ordinals are the visible ordinals after `CUDA_VISIBLE_DEVICES`.
- Mixed memory sizes: set `-n` manually; automatic mapping ignores heterogeneity and PCIe/NVLink topology and cross-socket cost.
- Apple Silicon: one device, device mapping is a no-op.
- Dynamic LoRA mutation is not for tensor-parallel deployments; preload adapters.

## Multi-node NCCL

Same CUDA+NCCL binary, model, dtype, quantization and runtime flags on every node. `global world size = local TP size x nodes`
and must satisfy the same head-divisibility constraint.

```bash
# head node (4 local GPUs of an 8-GPU world)
CUDA_VISIBLE_DEVICES=0,1,2,3 MISTRALRS_MN_GLOBAL_WORLD_SIZE=8 MISTRALRS_MN_LOCAL_WORLD_SIZE=4 \
MISTRALRS_MN_HEAD_NUM_WORKERS=1 MISTRALRS_MN_HEAD_PORT=9000 \
  mistralrs serve --host 127.0.0.1 -m Qwen/Qwen3-32B --quant 4

# worker node
CUDA_VISIBLE_DEVICES=0,1,2,3 MISTRALRS_MN_GLOBAL_WORLD_SIZE=8 MISTRALRS_MN_LOCAL_WORLD_SIZE=4 \
MISTRALRS_MN_WORKER_SERVER_ADDR=10.0.0.1:9000 MISTRALRS_MN_WORKER_ID=0 \
  mistralrs serve -m Qwen/Qwen3-32B --quant 4
```

Send client requests to the head only. The head port must be reachable from every worker, and the head hands out the NCCL id over
TCP (no authentication is documented): use a private network. On multi-interface hosts set `NCCL_SOCKET_IFNAME` before launching or NCCL may
hang at startup. Do not set `MISTRALRS_NO_NCCL` or `RING_CONFIG` in this mode.

## Ring backend

Needs a build with the `ring` feature (not in prebuilts: `cargo install mistralrs-cli --features "cuda flash-attn ring"`).
Each participant has its own `RING_CONFIG` JSON (`master_ip`, `master_port`, `port`, `right_ip`, `right_port`, `rank`,
`world_size`). `world_size` must be a power of two, and non-master ranks must set `master_ip`.

## Topology files

`--topology file.yml` places layers or tensors per device and sets per-layer ISQ; see `guides/perf/topology` upstream. Use it
instead of `-n` when you need per-layer quantization or CPU-offload control.
