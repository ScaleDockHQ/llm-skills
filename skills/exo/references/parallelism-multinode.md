# exo: discovery, parallelism and RDMA

> Verified against exo v1.0.71 (source 0.3.70), 2026-10-11

Sources: README (Features, Enabling RDMA on macOS, Benchmarking), `docs/api.md`, `tmp/set_rdma_network_config.sh`.

## Discovery

Nodes running the same exo version and namespace find each other automatically; no config. The API of any node sees the whole cluster in `GET /state`. One node is elected master; `--force-master` biases the election. Use `EXO_LIBP2P_NAMESPACE` to run separate clusters on one network.

## Placements

`GET /instance/previews?model_id=...` lists valid placements. Fields seen in upstream samples: `sharding` (`Pipeline` or tensor), `instance_meta` (`MlxRing`; `MlxJaccl` is the RDMA backend), `memory_delta_by_node`, and `error`. Use a preview with `error: null`.

- **Pipeline:** layers split across devices; fits larger models, little speedup per request.
- **Tensor:** each layer sharded; upstream reports up to 1.8x on 2 devices and 3.2x on 4 devices, best with RDMA.
- exo plans placement from a live view of device resources and link latency and bandwidth.

## RDMA over Thunderbolt 5 (macOS 26.2+)

Works on Macs with Thunderbolt 5 (M4 Pro Mac mini, M4 Max Mac Studio and MacBook Pro, M3 Ultra Mac Studio). Steps from upstream, all need user approval:

1. Shut down. Hold the power button about 10 seconds until the boot menu appears, choose Options (Recovery).
2. Utilities -> Terminal, run `rdma_ctl enable`, reboot.
3. exo handles the rest. From source, run `tmp/set_rdma_network_config.sh`, which removes the Thunderbolt Bridge and sets DHCP on each Thunderbolt port.

Caveats from upstream:

1. Every RDMA device must be directly cabled to every other device (full mesh).
2. Cables must support TB5.
3. On a Mac Studio, do not use the Thunderbolt 5 port next to the Ethernet port.
4. macOS versions must match exactly on all devices, including beta numbers, or ports may fail to discover each other.

Read-only checks: `sw_vers`, `networksetup -listallhardwareports | grep -A1 Thunderbolt`, `ifconfig bridge0` (should be gone for RDMA).

## Coordinator-only nodes

`uv run exo --no-worker` for a machine with good networking but little GPU.
