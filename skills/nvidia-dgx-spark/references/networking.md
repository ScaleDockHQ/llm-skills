# ConnectX-7 networking and clustering

> Verified against DGX Spark User Guide (ConnectX-7 Networking), dgx-spark-playbooks connect-two-sparks (updated 7/21/2026) and nccl (NCCL v2.30.7-1), 2026-10-11

## Ports and cables

Two QSFP ports on the back, up to 200 Gb/s each, Ethernet only. Use cables rated for at least 200 Gb/s (faster gives nothing). NVIDIA lists approved cables: Amphenol NJAAKK-N911 (0.4 m; NJAAKK0006 is 0.5 m) and Luxshare LMTQF022-SD-R. Pull-tab up, never force. The left port is the one closest to the Ethernet port as seen from the back; the playbooks assume specific ports, and both nodes must use the same physical port or NCCL tests have problems. One cable gives full bandwidth; with two cables all four interfaces need IP addresses for full bandwidth.

## Interface names

The NIC reaches the SoC through two PCIe Gen 5 x4 links, so each QSFP port shows as two Ethernet interfaces plus two RoCE devices. Names are identical on every Spark:

| QSFP port | Ethernet                       | RoCE                         |
| --------- | ------------------------------ | ---------------------------- |
| Left      | `enp1s0f0np0`, `enP2p1s0f0np0` | `rocep1s0f0`, `roceP2p1s0f0` |
| Right     | `enp1s0f1np1`, `enP2p1s0f1np1` | `rocep1s0f1`, `roceP2p1s0f1` |

`ibdev2netdev` shows the mapping and which are `Up`. If none are Up: check the cable, reboot, retry.

## Two nodes, manual (playbook "Connect Two Sparks")

1. Same username on both nodes (`whoami`).
2. Cable the same port; read `ibdev2netdev`.
3. Address the Up interfaces on each node with netplan (`templates/40-cx7.yaml`; the playbook uses 192.168.100.10 / .11 and 192.168.101.10 / .11), `chmod 600`, `sudo netplan apply`. `ip addr add` works but is lost at reboot.
4. Passwordless SSH both ways: the playbook's `discover-sparks` script, or `ssh-copy-id`.
5. Verify `ssh <peer> hostname` from each side without a prompt. Add a host alias (for example `node-b`) in `~/.ssh/config`.

Three Sparks connect in a ring (playbook Connect Three Sparks; NCCL 2.30u1 supports the ring); four use a switch (Multi Sparks Through a Switch). NVIDIA Sync's Cluster Assistant automates discovery, ConnectX-7 settings, link checks and SSH for up to three direct or four switched devices.

## NCCL validation

NVIDIA's NCCL playbook builds NCCL v2.30.7-1 and nccl-tests with Blackwell support on every node, then runs `all_gather_perf` through `mpirun`:

```bash
sudo apt-get install -y libopenmpi-dev
git clone -b v2.30.7-1 https://github.com/NVIDIA/nccl.git ~/nccl/ && cd ~/nccl/
make -j src.build NVCC_GENCODE="-gencode=arch=compute_121,code=sm_121"
git clone https://github.com/NVIDIA/nccl-tests.git ~/nccl-tests/ && cd ~/nccl-tests/ && make MPI=1
export CUDA_HOME=/usr/local/cuda MPI_HOME=/usr/lib/aarch64-linux-gnu/openmpi NCCL_HOME=$HOME/nccl/build/
export LD_LIBRARY_PATH=$NCCL_HOME/lib:$CUDA_HOME/lib64:$MPI_HOME/lib:$LD_LIBRARY_PATH
```

The playbook sets `UCX_NET_DEVICES`, `NCCL_SOCKET_IFNAME` and `OMPI_MCA_btl_tcp_if_include` to the **management** interface (`enP7s7` on Ethernet; use the Wi-Fi interface on both nodes if you have no Ethernet) for the `mpirun` bootstrap, and `mpirun -np 2 -H <ip1>:1,<ip2>:1 ... all_gather_perf` (add `-b 16G -e 16G -f 2` for a bandwidth run). It also ships `setup.sh` and `launch.sh` helpers. Building NCCL takes the node's CPU: do it with models stopped. Cleanup is deleting `~/nccl` and `~/nccl-tests`.

Engine containers in the vLLM playbook instead point `NCCL_SOCKET_IFNAME`, `GLOO_SOCKET_IFNAME`, `TP_SOCKET_IFNAME`, `UCX_NET_DEVICES` and `OMPI_MCA_btl_tcp_if_include` at the Up ConnectX-7 interface and set `VLLM_HOST_IP` to its address. See the `vllm` skill.

## Pitfalls

- Assuming the 10 GbE port is the inter-node link.
- Different physical ports on the two nodes.
- Only one of the two interfaces addressed when two cables are fitted.
- Running the NCCL build while models are loaded.
- Image drift between nodes (`combos/dual-node-cluster.md`).

## Sources

- <https://docs.nvidia.com/dgx/dgx-spark/spark-clustering.html>
- <https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/connect-two-sparks>
- <https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/nccl>
