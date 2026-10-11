# Two DGX Sparks with Ray (tensor parallel over ConnectX-7)

> Verified against vLLM v0.31.0 `examples/ray_serving/run_cluster.sh`, NVIDIA dgx-spark-playbooks `nvidia/vllm` (main, NGC 26.05-py3 era), 2026-10-11

Use when one 128 GB Spark cannot hold the model (for example Llama 3.3 70B at useful precision, or a large MoE).
This is the recipe NVIDIA tests. If you want the engine managed by llama-swap, read
`combos/dgx-spark-dual-mp.md` too. First check that one node is not enough: two nodes double every cold start
and every update, and the link adds latency per token.

Placeholders: node-a `10.0.0.1`, node-b `10.0.0.2` on the ConnectX-7 link. Use your real addresses.

## Prerequisites

1. Cable the QSFP ports and follow NVIDIA's "Connect two Sparks" playbook (static IPs on the CX7
   interfaces, same username on both nodes, passwordless SSH both ways). Run `mkdir -p ~/.ssh && chmod 700 ~/.ssh`
   on both nodes first, or the playbook's `discover-sparks` script fails.
2. `ibdev2netdev` lists the RDMA device to interface mapping. Use the interface marked `(Up)`
   (`enp1s0f0np0` or `enp1s0f1np1`). The 10 GbE port is **not** the inter-node link.
3. Identical image, same image ID, same weights path on both nodes (see "Image drift").
4. Memory safety: install a memory guard before loading big models (the skill `self-hosted-llms` ships one).
   An out-of-memory host on unified memory can freeze instead of OOM-killing.

## 1. Get `run_cluster.sh` on both nodes

NVIDIA pins a known-good upstream commit and patches in Ray, because the NGC 26.05 image ships without it:

```bash
wget https://raw.githubusercontent.com/vllm-project/vllm/51c1ee9b7c8acbba4899a8ebffd390685d171946/examples/ray_serving/run_cluster.sh
sed -i 's|^RAY_START_CMD="ray start|RAY_START_CMD="pip install -q --root-user-action=ignore '\''ray[default]>=2.9'\'' \&\& ray start|' run_cluster.sh
chmod +x run_cluster.sh
```

The `sed -i` form above is GNU sed (the Spark runs Linux). Whether NGC 26.09 still ships without Ray is
unverified: run `docker run --rm nvcr.io/nvidia/vllm:26.09-py3 pip show ray`; if Ray is present, the
patch is harmless but unnecessary.

## 2. Start the head (node-a), in tmux

```bash
export MN_IF_NAME=enp1s0f1np1                       # the (Up) interface from ibdev2netdev
export VLLM_HOST_IP=$(ip -4 addr show "$MN_IF_NAME" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
export VLLM_IMAGE=nvcr.io/nvidia/vllm:26.09-py3     # pin the same tag or digest on both nodes

bash run_cluster.sh "$VLLM_IMAGE" "$VLLM_HOST_IP" --head ~/.cache/huggingface \
  -e VLLM_HOST_IP="$VLLM_HOST_IP" -e UCX_NET_DEVICES="$MN_IF_NAME" \
  -e NCCL_SOCKET_IFNAME="$MN_IF_NAME" -e OMPI_MCA_btl_tcp_if_include="$MN_IF_NAME" \
  -e GLOO_SOCKET_IFNAME="$MN_IF_NAME" -e TP_SOCKET_IFNAME="$MN_IF_NAME" \
  -e RAY_memory_monitor_refresh_ms=0 -e MASTER_ADDR="$VLLM_HOST_IP"
```

Closing the terminal stops Ray and the cluster; that is why tmux or a systemd unit is required.

## 3. Start the worker (node-b), in tmux

Same variables, but `VLLM_HOST_IP` is node-b's own CX7 address, the head IP is node-a's, and the role is `--worker`:

```bash
export MN_IF_NAME=enp1s0f1np1
export VLLM_HOST_IP=$(ip -4 addr show "$MN_IF_NAME" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
export HEAD_NODE_IP=10.0.0.1
export VLLM_IMAGE=nvcr.io/nvidia/vllm:26.09-py3

bash run_cluster.sh "$VLLM_IMAGE" "$HEAD_NODE_IP" --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP="$VLLM_HOST_IP" -e UCX_NET_DEVICES="$MN_IF_NAME" \
  -e NCCL_SOCKET_IFNAME="$MN_IF_NAME" -e OMPI_MCA_btl_tcp_if_include="$MN_IF_NAME" \
  -e GLOO_SOCKET_IFNAME="$MN_IF_NAME" -e TP_SOCKET_IFNAME="$MN_IF_NAME" \
  -e RAY_memory_monitor_refresh_ms=0 -e MASTER_ADDR="$HEAD_NODE_IP"
```

## 4. Verify and serve (on node-a)

```bash
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E '^node-[0-9]+$')
docker exec "$VLLM_CONTAINER" ray status          # expect 2 nodes, 2 GPUs

docker exec -it "$VLLM_CONTAINER" /bin/bash -c '
  vllm serve meta-llama/Llama-3.3-70B-Instruct \
    --tensor-parallel-size 2 --max-model-len 2048 \
    --gpu-memory-utilization 0.8 --distributed-executor-backend ray'
```

Gated models need `hf auth login` inside the container; paste the token interactively, never on a command line.
Pre-download weights on **both** nodes (the HF cache is mounted from `~/.cache/huggingface` on each).
`--max-model-len 2048` is NVIDIA's smoke-test value; raise it only after watching `free -h`.

Test: `curl http://localhost:8000/v1/completions` on node-a. The API listens on all interfaces here, so firewall it
or add `--host 127.0.0.1`; do not expose the Ray ports (6379, 8265).

## Image drift

Pulling a moving tag on one node leaves two different images behind one tag; start-up then fails in confusing
ways (version mismatch, NCCL init hang, worker crash). Compare IDs, not tags:

```bash
ref=nvcr.io/nvidia/vllm:26.09-py3
docker image inspect --format '{{.Id}}' "$ref"
ssh node-b "docker image inspect --format '{{.Id}}' $ref"
```

For a locally built image, move it with `docker save "$ref" | ssh node-b docker load`.

## Behind llama-swap

Wrap the head/worker start in a script and let llama-swap call it with `cmd`/`cmdStop`. Because the Ray cluster
outlives `vllm serve`, the router must stop the whole cluster (both containers), not just the server process.
The mp variant fits this better; prefer it unless you need Ray features. Details in
`combos/dgx-spark-dual-mp.md` and the skills `llama-swap` and `self-hosted-llms`.

## Pitfalls

- Unified memory: `nvidia-smi` memory is not reported; `--gpu-memory-utilization` is a fraction of memory
  shared with the OS and page cache. Start at 0.7-0.8. After heavy file I/O, drop caches
  (`sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'`) and restart.
- The NGC known issue on aggressive memory allocation applies to every node (`references/install.md`).
- Traffic between nodes is unencrypted and can lead to remote code execution if reached: keep it on the direct
  CX7 link.
- `Error: No available node types can fulfill resource request`: wrong or multiple IPs; set `VLLM_HOST_IP` per node.
- Confirm RDMA with `NCCL_DEBUG=TRACE`: want `via NET/IB/GDRDMA`, not `via NET/Socket`.
- Validate the link with NVIDIA's NCCL playbook before blaming vLLM.
