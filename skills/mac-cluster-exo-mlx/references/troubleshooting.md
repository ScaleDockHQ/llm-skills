# Troubleshooting a Mac cluster

> Verified against exo README (RDMA caveats), MLX distributed docs, `rdma_ctl status` and `ibv_devices` on macOS 26.6, 2026-10-11

| Symptom                                                     | Cause                                                                | Fix                                                                                         |
| ----------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Nodes do not see each other (exo)                           | Different namespace, firewall, different subnet, OS version mismatch | Same `EXO_LIBP2P_NAMESPACE`; same LAN or cable; match macOS versions exactly                |
| `rdma_ctl status` prints `disabled`                         | RDMA not enabled on that node                                        | Enable from Recovery (`networking-and-rdma.md`); needs reboot                               |
| `ibv_devices` shows an empty table                          | RDMA disabled, or macOS before 26.2, or no Thunderbolt 5 port in use | Update to macOS 26.2+, enable RDMA, use TB5 ports and cables                                |
| RDMA placement unavailable or falls back to ring            | Mesh not complete, a cable is not TB5, wrong port on a Mac Studio    | Cable every pair directly; avoid the port next to the Ethernet port                         |
| JACCL init fails (MLX)                                      | Hostfile `rdma` list wrong, broken mesh                              | Regenerate with `mlx.distributed_config --backend jaccl --over thunderbolt`                 |
| `mlx.launch` hangs or cannot reach a host                   | ssh needs a password or host key, wrong hostname                     | `ssh <host> true` from the launching node without prompts                                   |
| Distributed `mlx_lm.server` rejects adapters or draft model | Not supported in distributed mode                                    | Serve without adapters (fuse first) and without a draft model                               |
| Slower than one Mac                                         | Ring over TCP, small model, pipeline overhead                        | Keep it on one Mac if it fits; use RDMA tensor parallelism; compare with `exo_bench.py`     |
| One node swaps or freezes                                   | A shard exceeds that node's budget                                   | Rebalance (different placement), smaller quant, close apps; `memory_pressure` on every node |
| exo app asks for network changes                            | It installs a Network profile and LaunchDaemon                       | Expected; uninstall via the menu bar Advanced menu or the uninstall script                  |
| exo from source crashes on an M5 with Homebrew macmon       | `macmon 0.6.1` crashes on Apple M5 (README)                          | Install the pinned macmon fork revision from the README                                     |
| Port 52415 reachable by others                              | Bound beyond loopback or LAN-reachable                               | Check with `lsof -nP -iTCP:52415 -sTCP:LISTEN`; firewall it, put a gateway in front         |
