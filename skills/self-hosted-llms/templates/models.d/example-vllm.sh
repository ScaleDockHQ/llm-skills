# models.d/qwen-coder.sh - example model definition for start-model.sh (vLLM).
# Copy to models.d/<model-id>.sh where <model-id> is the llama-swap model ID.
# Sourced by start-model.sh with MODEL_ID and PORT exported. Keep secrets out.
#
# Single node: define model_run only.
# Dual node (tensor parallel over the ConnectX-7 link): also define worker_run
# and set LLM_WORKER_HOSTS="node-b" in the llama-swap service environment.

MODEL_IMAGE="${QWEN_CODER_IMAGE:-vllm/vllm-openai:latest}"   # pin a tag or digest in production
MODEL_EXCLUSIVE=0                                          # 1 = stop all other engine containers first

HF_DIR="${LLM_HF_DIR:-$HOME/.cache/huggingface}"           # same path on every node
REPO="${QWEN_CODER_REPO:-<org>/<model>}"                    # Hugging Face repo, already downloaded
REVISION="${QWEN_CODER_REVISION:-<commit-sha>}"             # pin; never serve "main" blindly
HEAD_ADDR="${LLM_HEAD_ADDR:-10.0.0.1}"                      # node-a address on the CX7 link
NET_IF="${LLM_CLUSTER_IF:-<cx7-interface>}"                 # from `ibdev2netdev` on each node

common_args() {
  printf '%s\n' --network host --ipc host --gpus all \
    --label "$LLM_ENGINE_LABEL" \
    -v "$HF_DIR:/hf" -e HF_HOME=/hf -e HF_HUB_OFFLINE=1 \
    -e NCCL_SOCKET_IFNAME="$NET_IF" -e GLOO_SOCKET_IFNAME="$NET_IF"
}

# Head (node-a). Binds the API to loopback only; llama-swap proxies to it.
model_run() {
  set -- $(common_args)
  if [ -n "$LLM_WORKER_HOSTS" ]; then
    set -- "$@" --entrypoint vllm "$MODEL_IMAGE" serve "$REPO" --revision "$REVISION" \
      --tensor-parallel-size 2 --distributed-executor-backend mp \
      --nnodes 2 --node-rank 0 --master-addr "$HEAD_ADDR"
  else
    set -- "$@" --entrypoint vllm "$MODEL_IMAGE" serve "$REPO" --revision "$REVISION"
  fi
  docker run -d --name "$MODEL_ID" "$@" \
    --host 127.0.0.1 --port "$PORT" \
    --served-model-name "$MODEL_ID" \
    --max-model-len 65536 \
    --gpu-memory-utilization 0.80
}

# Worker (node-b), headless: no API server. Only called when LLM_WORKER_HOSTS is set.
worker_run() {
  host="$1"
  on_host "$host" docker run -d --name "$MODEL_ID-worker" $(common_args) \
    --entrypoint vllm "$MODEL_IMAGE" serve "$REPO" --revision "$REVISION" \
    --tensor-parallel-size 2 --distributed-executor-backend mp \
    --nnodes 2 --node-rank 1 --master-addr "$HEAD_ADDR" --headless
}
