# TensorRT-LLM (`trtllm-serve`)

> Verified against TensorRT-LLM v1.2.1, 2026-10-11

This page keeps only what is specific to this stack: the wrapper script, the llama-swap and LiteLLM entries, and the stack pitfalls. Install, flags, tuning and operating detail live in the product skill.

Depth: install the tensorrt-llm skill (`npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`).

## Minimal working config

Engine command (standalone; the playbook pattern of writing a YAML config next to the serve call):

```bash
mkdir -p /opt/llm-stack/trtllm && cat > /opt/llm-stack/trtllm/gpt-oss.yml <<'EOF'
kv_cache_config:
  dtype: "auto"
  free_gpu_memory_fraction: 0.85
cuda_graph_config:
  enable_padding: true
EOF
docker run --rm --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
  -p 127.0.0.1:8000:8000 -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  -v /opt/llm-stack/trtllm:/cfg:ro nvcr.io/nvidia/tensorrt-llm/release:1.2.1 \
  trtllm-serve openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max_batch_size 16 \
  --extra_llm_api_options /cfg/gpt-oss.yml
```

gpt-oss needs the tiktoken encodings the playbook downloads into `TIKTOKEN_ENCODINGS_BASE`; mount a
pre-fetched directory and set that variable instead of downloading at start.

Stack wrapper, `/opt/llm-stack/models.d/gpt-oss.sh`:

```bash
model_run() {
  docker run -d --name "$MODEL_ID" --label llm-stack.role=engine \
    --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
    -p "127.0.0.1:${PORT}:8000" \
    -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_HUB_OFFLINE=1 \
    -v /opt/llm-stack/trtllm:/cfg:ro -v /srv/tiktoken:/tiktoken:ro -e TIKTOKEN_ENCODINGS_BASE=/tiktoken \
    nvcr.io/nvidia/tensorrt-llm/release:1.2.1 \
    trtllm-serve openai/gpt-oss-120b --host 0.0.0.0 --port 8000 \
      --max_batch_size 16 --extra_llm_api_options /cfg/gpt-oss.yml
}
```

llama-swap entry (`useModelName` because the server names the model after its path unless the image
supports `--served_model_name`):

```yaml
models:
  gpt-oss:
    cmd: /opt/llm-stack/start-model.sh run gpt-oss ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop gpt-oss
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    useModelName: openai/gpt-oss-120b
    ttl: 0
    unloadTimeout: 90
```

## How it plugs into the stack

- **Port:** llama-swap `${PORT}` on 127.0.0.1 (container 8000 in this example; the playbook uses 8355).
- **Health:** `GET /health` (no generation, single model). Also `/metrics` (iteration stats), `/version`.
- **Auth:** none configured; loopback only, LiteLLM holds keys. Clients may send any bearer value.
- **APIs:** `/v1/models`, `/v1/completions`, `/v1/chat/completions`, and the Responses API (`/v1/responses`)
  per the current docs. No Anthropic `/v1/messages` is documented; LiteLLM's `/v1/messages` bridges it.
  If your pinned image rejects `/v1/responses`, add `use_chat_completions_api: true` below.
- **LiteLLM entry:**

```yaml
- model_name: gpt-oss
  litellm_params:
    model: openai/gpt-oss
    api_base: http://127.0.0.1:8080/v1
    api_key: os.environ/LLAMA_SWAP_API_KEY
```

## Known pitfalls

- `--backend` is deprecated (PyTorch is the only option); old commands with `--backend pytorch` still run.
- Flags marked prototype can change between rc builds; pin the tag and re-check `--help` on update.
- The playbook downloads weights and tiktoken files inside `docker run`; in the stack that turns a cold
  start into a download. Pre-fetch everything.
- Two-node runs need the hostfile, SSH keys and IB device in both containers; a missing one hangs `mpirun`.

## Official links

- `trtllm-serve` docs: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/trtllm-serve.html
- Containers: https://nvidia.github.io/TensorRT-LLM/installation/containers.html
- NGC: https://catalog.ngc.nvidia.com/orgs/nvidia/teams/tensorrt-llm/containers/release
- Repo and releases: https://github.com/NVIDIA/TensorRT-LLM
- DGX Spark playbook: https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/trt-llm
