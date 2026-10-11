# NCCL: versions and updates

> Verified against NCCL v2.32.3 and nccl-tests v2.21.1 (docs.nvidia.com/deeplearning/nccl), 2026-10-11

Sources: NCCL GitHub releases (latest v2.32.3, 2026-09-17), user guide env notes.

- Keep NCCL, GPU driver and OFED/DOCA identical across nodes; mismatched NCCL versions across ranks is a common cause of init hangs. If the engine bundles NCCL (PyTorch wheels), upgrading means upgrading the engine image.
- Version-dependent behavior to remember: GID index dynamic since 2.21; `NCCL_CONF_FILE` since 2.23; `NCCL_DEBUG=ATTN` and `NCCL_DEBUG_LEVELS` since 2.32; `NCCL_NET_GDR_C2C` default 1 since 2.27; DMA-BUF default on since 2.13 where supported; NVLS silent fallback was tried in 2.27/2.28 and reverted in 2.29.
- Upgrade procedure: read release notes, update one node pair first, rerun the ladder (`ib_write_bw`, `all_reduce_perf`), then the engine with `NCCL_DEBUG=INFO`; keep the previous image or package to roll back.
- `NCCL_*` variables set years ago can be harmful after an upgrade; remove stale tuning and re-measure.
