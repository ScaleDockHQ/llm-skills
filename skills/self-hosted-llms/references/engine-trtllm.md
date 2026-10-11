# TensorRT-LLM (`trtllm-serve`)

> Verified against TensorRT-LLM v1.2.1, 2026-10-11

## What it is and when to choose it

TensorRT-LLM is NVIDIA's inference library; `trtllm-serve` starts an OpenAI-compatible server on top of
its PyTorch backend (the old engine-build workflow is not needed for serving). Choose it when NVIDIA
publishes an optimized recipe or checkpoint for your model (NVFP4/FP8 from `nvidia/*` on Hugging Face),
when NVIDIA's DGX Spark playbooks cover the model, or for multi-node runs launched through MPI. It has the
heaviest images and slowest cold starts of the stack's engines; give it an exclusive group.

Versions: latest stable is v1.2.1; the 1.3.0 release-candidate line (1.3.0rc29 at writing) is what the
current docs and NVIDIA's Spark playbooks use. Flags below are from the current `trtllm-serve` docs; many
are marked beta or prototype upstream, so confirm with `trtllm-serve serve --help` in your exact image.

## Install (DGX Spark/arm64 and generic x86)

Use NGC release containers; both architectures are in one tag:

```bash
docker pull nvcr.io/nvidia/tensorrt-llm/release:1.2.1        # stable, amd64 + arm64
docker pull nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc29    # rc line used by current docs
```

NVIDIA's DGX Spark playbook pins rc tags (`1.3.0rc13` single node, `1.3.0rc5` in the two-Spark section at
writing); treat those as recipe defaults and diff them on update. `devel` images are for building from
source only. Run containers with `--ipc=host --ulimit memlock=-1 --ulimit stack=67108864` as the playbook does.

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

### Dual DGX Spark

NVIDIA's two-Spark playbook starts one long-running container per node on `--network host` with
`/dev/infiniband`, OpenMPI variables pointing at the CX7 interfaces and a hostfile with both CX7 IPs, then
on node-a runs `mpirun ... trtllm-llmapi-launch trtllm-serve <model> --tp_size 2 ...`. In the stack, keep
those two containers persistent (systemd) and make `model_run()` launch the `mpirun` inside the node-a
container with `--host 127.0.0.1 --port "$PORT"` (host networking); the container name then differs from
the model ID, so the wrapper's stop must end that process explicitly. Validate this pattern before relying on it.

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

## Operating

- Start/stop via llama-swap; `docker logs -f gpt-oss` or llama-swap `/logs/stream/gpt-oss`.
- `curl -s http://127.0.0.1:8080/upstream/gpt-oss/metrics` for KV cache and batching stats.
- Update: pull the new tag on every node while serving (images are large; check disk first), compare image
  IDs, re-read the playbook's YAML for changed keys, restart in a downtime window, benchmark again.

## Tuning knobs worth knowing

- `--max_batch_size`, `--max_num_tokens`, `--max_seq_len`: concurrency, batch tokens and context cap.
- `--kv_cache_free_gpu_memory_fraction` (alias `--free_gpu_memory_fraction`) or
  `kv_cache_config.free_gpu_memory_fraction` in YAML: share of free memory after weights for KV. On GB10 it
  is computed from shared memory that the OS also needs; the playbook uses 0.8-0.9 for a single model.
- `--tp_size`, `--pp_size`, `--ep_size`: parallelism; `--trust_remote_code` where the model needs it.
- `--reasoning_parser <name>` and `--tool_parser <name>` (choices include `qwen3`, `qwen3_coder`,
  `deepseek-r1`, `nano-v3`, `gemma4`; `auto` selects by model).
- `--config` is the preferred name for `--extra_llm_api_options` (same YAML; CLI flags win).
- YAML: `cuda_graph_config`, `kv_cache_config.enable_block_reuse` (prefix reuse), `disable_overlap_scheduler`.

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
