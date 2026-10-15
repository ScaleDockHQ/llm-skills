# Two DGX Sparks with the multiprocessing executor (no Ray)

> Verified against vLLM v0.31.0, 2026-10-11

Checked in the source (`vllm/config/parallel.py`, `docs/serving/parallelism_scaling.md`). Not validated on real Spark hardware by this skill.

vLLM's own multi-node `mp` mode: node 0 serves the API, node 1 runs `--headless`. No Ray, no cluster to keep
alive, and the whole thing is two plain `docker run` commands, which makes it easy to put behind a router.
NVIDIA's playbook tests the Ray path, not this one. **Unverified on Spark: validate on your pair** (start with a
small model, then raise the load) and fall back to `combos/dgx-spark-dual-ray.md` if it hangs.

Prerequisites, network and image-drift check are identical to the Ray combo (CX7 link
`10.0.0.1`/`10.0.0.2`, same image ID and weights path on both nodes, memory guard installed).

## Flags that matter (v0.31.0)

- `--tensor-parallel-size 2 --nnodes 2 --node-rank {0,1} --master-addr <node-a CX7 IP>`; `--master-port` default 29501.
- Node-b adds `--headless` (no API server). Both nodes get identical model flags.
- `--distributed-executor-backend mp` is the default here; passing it explicitly documents intent.
- Both containers: `--network host --ipc host --gpus all`, plus `NCCL_SOCKET_IFNAME` and `GLOO_SOCKET_IFNAME`
  set to the CX7 interface (name from `ibdev2netdev`). Add `VLLM_HOST_IP=<own CX7 IP>` per node if the node
  has several addresses.

## Wrapper script (node-a head, node-b worker)

Generalized from a llama-swap setup: the router calls `run`, which starts the worker over SSH first, then the head.
`MODEL_ID` and `PORT` come from the router.

```bash
# models.d/big-model.sh, sourced by a wrapper that exports MODEL_ID and PORT
IMAGE="${VLLM_IMAGE:-vllm/vllm-openai:v0.31.0}"      # pin a tag or digest, same on both nodes
HF_DIR="${LLM_HF_DIR:-$HOME/.cache/huggingface}"     # same path on both nodes
HEAD_ADDR="${LLM_HEAD_ADDR:-10.0.0.1}"
NET_IF="${LLM_CLUSTER_IF:?set to the CX7 interface from ibdev2netdev}"
REPO="<org>/<model>"; REVISION="<commit-sha>"        # pin; weights already downloaded on both nodes

common_args() {
  printf '%s\n' --network host --ipc host --gpus all \
    -v "$HF_DIR:/hf" -e HF_HOME=/hf -e HF_HUB_OFFLINE=1 \
    -e NCCL_SOCKET_IFNAME="$NET_IF" -e GLOO_SOCKET_IFNAME="$NET_IF"
}

worker_run() {   # run on node-b, for example: ssh node-b 'bash -s' < this function body
  docker run -d --name "$MODEL_ID-worker" $(common_args) --entrypoint vllm "$IMAGE" serve "$REPO" \
    --revision "$REVISION" --tensor-parallel-size 2 --distributed-executor-backend mp \
    --nnodes 2 --node-rank 1 --master-addr "$HEAD_ADDR" --headless
}

model_run() {    # run on node-a
  docker run -d --name "$MODEL_ID" $(common_args) --entrypoint vllm "$IMAGE" serve "$REPO" \
    --revision "$REVISION" --tensor-parallel-size 2 --distributed-executor-backend mp \
    --nnodes 2 --node-rank 0 --master-addr "$HEAD_ADDR" \
    --host 127.0.0.1 --port "$PORT" --served-model-name "$MODEL_ID" \
    --max-model-len 65536 --gpu-memory-utilization 0.80
}
```

`--entrypoint vllm` is needed because the NGC image has no `vllm serve` entrypoint; with the upstream
`vllm/vllm-openai` image the entrypoint already is `vllm serve` and you can drop `--entrypoint vllm ... serve`
and pass the model as the first argument (check `docker image inspect` for the image you use).

Stop path: stop and remove `"$MODEL_ID"` on node-a and `"$MODEL_ID-worker"` on node-b on **every** exit path.
A half-stopped pair keeps GPU memory held on one node and the next start fails with
`Free memory on device ... is less than desired GPU memory utilization`.

## llama-swap entry

```yaml
models:
  big-model:
    cmd: /opt/llm-stack/start-model.sh run big-model ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop big-model
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    ttl: 0
    unloadTimeout: 120
    capabilities:
      tools: true
```

Put it in an exclusive group so only one big model is loaded, and raise the top-level `healthCheckTimeout`
above the observed two-node cold start. The `start-model.sh` wrapper, exclusive-group handling and worker
start-over-SSH logic come from the skill `self-hosted-llms`
(`npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`) and `llama-swap`.

## Security

Node-to-node traffic is unencrypted and the `mp` rendezvous and worker channels can execute code if reached:
keep `--master-port` (29501) and the worker ports on the direct CX7 link. Do not publish them on the LAN.

## Pitfalls

- `--headless` node must start with the same flags as the head, including `--max-model-len` and
  `--gpu-memory-utilization`.
- Using the 10 GbE port by accident: NCCL must be pointed at the CX7 interface.
- After a crash, `docker ps -a` on **both** nodes, remove leftovers before retrying.
- See `performance-tuning.md` for unified-memory budgeting and `troubleshooting.md` for NCCL errors.
