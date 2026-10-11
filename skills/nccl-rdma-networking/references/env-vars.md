# NCCL environment variables that matter

> Verified against NCCL v2.32.3 and nccl-tests v2.21.1 (docs.nvidia.com/deeplearning/nccl), 2026-10-11

Source: NCCL user guide, "Environment Variables". Variables can also live in `NCCL_CONF_FILE` or `~/.nccl.conf` (see `templates/nccl.conf`; `NCCL_CONF_FILE` since 2.23 takes an absolute path, no `~`).

## Select devices

| Variable                      | Meaning                                                                                                                                                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NCCL_SOCKET_IFNAME`          | IP interfaces for bootstrap and sockets; prefix list, `^` excludes, `=` exact (`=eth0`, `^docker`). By default `lo` and `docker*` are avoided and `ib*` favored. Setting it bypasses auto selection                   |
| `NCCL_IB_HCA`                 | HCAs/ports for RDMA: `<hca>[:<port>[:<rail>[:<plane>]]]`, comma list, `^` excludes, `=` exact. Always use `=` (`=mlx5_0:1,mlx5_1:1`), because `mlx5_1` without `=` also matches `mlx5_10` to `mlx5_19`. Limit 32 HCAs |
| `NCCL_IB_DISABLE`             | 1 forces sockets; leave unset                                                                                                                                                                                         |
| `NCCL_NET`, `NCCL_NET_PLUGIN` | Pick or load a network plugin                                                                                                                                                                                         |
| `NCCL_CROSS_NIC`              | 0 same NIC per ring/tree (rail-optimized fabrics), 1 allow different NICs, 2 default (prefer same, allow different)                                                                                                   |

## GPU Direct and memory

`NCCL_NET_GDR_LEVEL` (LOC, PIX, PXB, PHB, SYS), `NCCL_NET_GDR_READ`, `NCCL_DMABUF_ENABLE` (default 1 where supported), `NCCL_NET_GDR_C2C` (default 1 since 2.27), `NCCL_P2P_LEVEL`, `NCCL_P2P_DISABLE`, `NCCL_SHM_DISABLE`, `NCCL_NVLS_ENABLE` (default 2), `NCCL_CUMEM_ENABLE`.

## RoCE and IB tuning

`NCCL_IB_GID_INDEX` (default -1; do not set on 2.21+), `NCCL_IB_TC`, `NCCL_IB_SL`, `NCCL_IB_QPS_PER_CONNECTION` (1 to 128, default 1), `NCCL_IB_SPLIT_DATA_ON_QPS`, `NCCL_IB_TIMEOUT` (timeout = 4.096 us x 2^value; times `NCCL_IB_RETRY_CNT` for total; raise on big networks when `ibv_poll_cq` fails with error 12), `NCCL_IB_RETRY_CNT`, `NCCL_IB_ADDR_FAMILY`, `NCCL_IB_ROCE_VERSION_NUM`, `NCCL_IB_PKEY`.

## Observability

| Variable                                | Meaning                                                                                         |
| --------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `NCCL_DEBUG`                            | VERSION, WARN, ATTN (since 2.32), INFO, TRACE                                                   |
| `NCCL_DEBUG_LEVELS`                     | Adds levels (since 2.32); prefer `NCCL_DEBUG=WARN NCCL_DEBUG_LEVELS=ATTN` across mixed versions |
| `NCCL_DEBUG_SUBSYS`                     | Filter INFO by subsystem, `^` to exclude (INIT, NET, GRAPH, ...)                                |
| `NCCL_DEBUG_FILE`                       | Log path with `%h` host and `%p` pid; absolute path only                                        |
| `NCCL_TOPO_DUMP_FILE`, `NCCL_TOPO_FILE` | Dump or override detected topology                                                              |
| `NCCL_RAS_ENABLE`                       | Reliability, Availability, Serviceability subsystem (see the RAS doc)                           |

## Tuning (use sparingly)

`NCCL_ALGO`, `NCCL_PROTO`, `NCCL_MIN_NCHANNELS`, `NCCL_MAX_NCHANNELS`, `NCCL_MIN_CTAS`, `NCCL_MAX_CTAS`, `NCCL_BUFFSIZE`. Upstream: tuning gains in one benchmark can hurt elsewhere; avoid in production without measurement.

## Ports

NCCL opens TCP ports for bootstrap; restrict with the kernel range (`net.ipv4.ip_local_port_range = 50000 51000`) and open the same range in the firewall. Needs approval.
