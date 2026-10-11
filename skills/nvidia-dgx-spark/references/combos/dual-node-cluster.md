# Two-node DGX Spark cluster

> Verified against dgx-spark-playbooks connect-two-sparks (7/21/2026), nccl (v2.30.7-1) and vllm (06/12/2026), DGX Spark User Guide, 2026-10-11

End-to-end order for a head node (node-a) and a worker (node-b):

1. **Match the nodes.** Same DGX OS, driver, user name and UID, paths and HF cache location (`../host-setup.md`, `../updating.md`).
2. **Link.** Cable the same physical QSFP port on both, address the Up interfaces with netplan, passwordless SSH both ways (`../networking.md`). Or use NVIDIA Sync's Cluster Assistant.
3. **Validate.** NCCL `all_gather_perf` between nodes (`../networking.md`). Do not blame the engine before this passes.
4. **Memory safety on both nodes** (`../memory.md`).
5. **Same image on both.** Pull the pinned tag on each node and compare IDs:

```bash
ref=nvcr.io/nvidia/vllm:26.05-py3        # example; use your pinned tag
docker image inspect --format '{{.Id}}' "$ref"
ssh node-b "docker image inspect --format '{{.Id}}' $ref"
```

Tags lie: a `latest` pulled on one node leaves two images behind one name, which causes version-mismatch errors, hangs at NCCL init and worker crashes. Move a locally built image with `docker save "$ref" | ssh node-b docker load`. 6. **Start the engine** with the interface env pointing at the ConnectX-7 link. vLLM playbook flow: `run_cluster.sh` from vLLM's `examples/ray_serving` (pinned commit), `--head` on node 1 then worker on node 2, with `NCCL_SOCKET_IFNAME`, `GLOO_SOCKET_IFNAME`, `TP_SOCKET_IFNAME`, `UCX_NET_DEVICES`, `OMPI_MCA_btl_tcp_if_include` set to the Up interface and `VLLM_HOST_IP` to its IP. Run it in tmux or screen: the script has an EXIT trap that stops the container. The 26.05-py3 image ships without `ray`; the playbook patches `run_cluster.sh` to `pip install` it. Details: `vllm` skill. 7. **Order of operations in a stack.** The head node's wrapper starts the worker first and stops both on every exit path; llama-swap sees only the head process (`llama-swap` skill, `combos/dgx-spark.md`).

Costs of two nodes: every cold start touches both, every update is done twice, the link adds per-token latency. Prefer one node whenever weights plus KV fit.

## Sources

- <https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/vllm>
- <https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/connect-two-sparks>
