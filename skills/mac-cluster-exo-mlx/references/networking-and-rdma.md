# Networking and RDMA

> Verified against exo README (Enabling RDMA on macOS), MLX distributed docs (ring, JACCL, mlx.distributed_config, launching_distributed), `rdma_ctl` and `ibv_devices` run locally on macOS 26.6, 2026-10-11

## Backends

| Backend | Transport                                   | Needs                                                   | Notes                                                                                         |
| ------- | ------------------------------------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| ring    | TCP sockets over Ethernet or Thunderbolt IP | Nothing extra (always available in MLX)                 | Usually faster than MPI; higher bandwidth over a Thunderbolt ring                             |
| JACCL   | RDMA over Thunderbolt 5                     | macOS 26.2+, TB5 on every node, full mesh, RDMA enabled | Order-of-magnitude lower latency than ring (MLX docs); needed for tensor parallelism at speed |
| MPI     | Per MPI library                             | An MPI install                                          | Mature; not covered here                                                                      |

exo uses MLX distributed underneath; its placements are labeled `MlxRing` or `jaccl` and `exo_bench.py` can filter by `--instance-meta ring|jaccl`.

## RDMA requirements (exo README and MLX docs)

- macOS 26.2 or later; works on Macs with Thunderbolt 5 (exo lists M4 Pro Mac mini, M4 Max Mac Studio, M4 Max MacBook Pro, M3 Ultra Mac Studio).
- Every node must be cabled to every other node (fully connected mesh) with cables that support Thunderbolt 5. A broken mesh is invalid for JACCL.
- On a Mac Studio, do not use the Thunderbolt 5 port next to the Ethernet port.
- OS versions must match exactly on all nodes, including beta numbers, or RDMA ports may not discover each other.
- If running exo from source, disable Thunderbolt Bridge and set DHCP on each RDMA port with the repository's `tmp/set_rdma_network_config.sh` (the macOS app handles this itself).

## Enable RDMA (cannot be done remotely)

Ask first; it needs physical access and a reboot per node.

1. Shut down the Mac, hold the power button until the boot options appear, choose Options (Recovery).
2. Open Terminal from Utilities, run `rdma_ctl enable`, press Enter.
3. Reboot.

Undo with `rdma_ctl disable` the same way. Check state any time without privileges:

```bash
rdma_ctl status          # prints enabled or disabled
ibv_devices              # lists rdma_enN devices when enabled; empty table when not
```

## Ring over Thunderbolt or Ethernet (MLX)

`mlx.distributed_config` discovers Thunderbolt connectivity over SSH and writes the hostfile for `mlx.launch`:

```bash
mlx.distributed_config --verbose --hosts host1,host2 --backend ring          # prints per-node setup commands and hostfile
mlx.distributed_config --verbose --backend jaccl --hosts host1,host2 --over thunderbolt --output cluster-jaccl.json   # needs RDMA enabled
```

`--auto-setup` configures the nodes itself and needs password-less sudo on them: that changes network services and disables the Thunderbolt bridge, so ask first. Manual setup per MLX docs: disable the Thunderbolt bridge, give each cable its own subnet (for example `192.168.0.1` and `192.168.0.2` on the two ends).

## Official links

- https://github.com/exo-explore/exo#enabling-rdma-on-macos
- https://ml-explore.github.io/mlx/build/html/usage/distributed.html
- https://ml-explore.github.io/mlx/build/html/usage/launching_distributed.html
