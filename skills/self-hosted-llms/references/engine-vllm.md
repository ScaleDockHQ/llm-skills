# vLLM

> Verified against vLLM v0.31.0, 2026-10-11

## What it is and when to choose it

vLLM is a high-throughput inference server for Hugging Face checkpoints (BF16, FP8, NVFP4, AWQ/GPTQ and
more) with continuous batching, paged KV cache, prefix caching, speculative decoding and tensor/pipeline
parallelism. Choose it for large safetensors models, many concurrent clients, tool calling with
model-specific parsers, and two-node tensor parallel across DGX Sparks. Prefer llama.cpp for GGUF and
small co-resident models; vLLM cold starts are slow (weights load, CUDA graph capture, compile).

## Install (DGX Spark/arm64 and generic x86)

Use containers. Pin a tag and record the image ID on every node (`docker image inspect -f '{{.Id}}'`).

- **Upstream, multi-arch (amd64 + arm64):** `vllm/vllm-openai:v0.31.0`. The image entrypoint is
  `vllm serve`, so engine args follow the image name. Run with `--ipc=host` (or a large `--shm-size`).
- **NGC, recommended by NVIDIA for DGX Spark:** `nvcr.io/nvidia/vllm:<YY.MM>-py3` (multi-arch; newest
  tag at writing: `26.09-py3`). Its entrypoint is not `vllm serve`; put `vllm serve <model> ...` after
  the image. NGC release numbers do not map 1:1 to upstream versions; check the bundled version with
  `docker run --rm <image> vllm --version`.
- **Model-specific images:** NVIDIA's playbook points some model families at custom upstream tags (for
  example `vllm/vllm-openai:gemma4-cu130`). Treat those as recipe-owned and diff on update.
- **Source build (only when a fix is not yet in an image):** the upstream `docker/Dockerfile` supports
  `--platform linux/arm64` with `--build-arg max_jobs=N --build-arg nvcc_threads=M`. Upstream notes the
  memory use of parallel jobs "can be substantial". On GB10 the build competes with the model for the
  same unified memory: stop serving first, keep `max_jobs` low (single digits) with `nvcc_threads=2`,
  and run the build in a memory-capped scope (see memory-safety.md).

## Minimal working config

Engine command (single node, standalone smoke test):

```bash
docker run --rm --gpus all --ipc=host -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_HUB_OFFLINE=1 \
  vllm/vllm-openai:v0.31.0 Qwen/Qwen3-Coder-30B-A3B-Instruct \
  --served-model-name qwen-coder --max-model-len 65536 --gpu-memory-utilization 0.80 \
  --enable-auto-tool-choice --tool-call-parser qwen3_xml --enable-prefix-caching
curl -s http://127.0.0.1:8000/health -o /dev/null -w '%{http_code}\n'
```

Stack wrapper, `/opt/llm-stack/models.d/qwen-coder.sh` (`MODEL_ID` and `PORT` come from start-model.sh):

```bash
model_run() {
  docker run -d --name "$MODEL_ID" --label llm-stack.role=engine \
    --gpus all --ipc=host -p "127.0.0.1:${PORT}:8000" \
    -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_HUB_OFFLINE=1 \
    vllm/vllm-openai:v0.31.0 Qwen/Qwen3-Coder-30B-A3B-Instruct \
    --host 0.0.0.0 --port 8000 --served-model-name "$MODEL_ID" \
    --max-model-len 65536 --gpu-memory-utilization 0.80 \
    --enable-auto-tool-choice --tool-call-parser qwen3_xml --enable-prefix-caching
}
```

`--host 0.0.0.0` is inside the container only; the host side is published on 127.0.0.1. llama-swap entry
in `/etc/llm-stack/llama-swap.yaml`:

```yaml
models:
  qwen-coder:
    cmd: /opt/llm-stack/start-model.sh run qwen-coder ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop qwen-coder
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    ttl: 0               # slow cold start: let the router evict it only when needed
    unloadTimeout: 60    # container shutdown frees memory slowly
    capabilities:
      tools: true        # vLLM cannot report this; context is auto-read from max_model_len
```

Put it in an exclusive group (see llama-swap.md) and raise top-level `healthCheckTimeout` above the
observed cold-start time.

### Dual DGX Spark

vLLM documents two multi-node runtimes; both need the same image, weights path and config on both
nodes, and the container on `--network host` so NCCL can reach the ConnectX-7 addresses.

- **Ray (what NVIDIA's "vLLM on two Sparks" playbook uses):** start a Ray head on node-a and a worker
  on node-b with vLLM's `examples/ray_serving/run_cluster.sh`, passing `-e VLLM_HOST_IP=<this node's CX7 IP>`
  and the interface variables from the playbook (`NCCL_SOCKET_IFNAME`, `GLOO_SOCKET_IFNAME`,
  `UCX_NET_DEVICES`, `TP_SOCKET_IFNAME`, `OMPI_MCA_btl_tcp_if_include`). Verify with `ray status`, then run
  `vllm serve <model> --tensor-parallel-size 2 --distributed-executor-backend ray` inside the head container.
  The playbook notes the 26.05+ NGC image ships without Ray and patches the script to install it.
- **Multiprocessing (fits the wrapper better):** `worker_run()` on node-b starts rank 1 with
  `--tensor-parallel-size 2 --nnodes 2 --node-rank 1 --master-addr 10.0.0.1 --headless`; `model_run()` on
  node-a starts rank 0 with `--nnodes 2 --node-rank 0 --master-addr 10.0.0.1 --host 127.0.0.1 --port $PORT`.
  vLLM documents this generically (8-GPU nodes); NVIDIA's playbook tests Ray, so validate mp on your pair.

The inter-node traffic is unencrypted and can execute code if reached; keep it on the direct CX7 link.

## How it plugs into the stack

- **Port:** llama-swap's `${PORT}` on 127.0.0.1, mapped to 8000 in the container.
- **Health:** `GET /health` returns 200 once the engine is ready and never loads anything (one model per
  process). Also `/metrics` (Prometheus), `/version`, `/v1/models`.
- **Auth:** do not pass `--api-key`; the engine stays unauthenticated on loopback, LiteLLM holds the keys.
- **APIs:** `/v1/chat/completions`, `/v1/completions`, `/v1/responses`, Anthropic `/v1/messages` and
  `/v1/messages/count_tokens`, embeddings and more.
- **LiteLLM entry** (no Responses bridge needed):

```yaml
  - model_name: qwen-coder
    litellm_params:
      model: openai/qwen-coder
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/LLAMA_SWAP_API_KEY   # any non-empty placeholder if llama-swap has no apiKeys
```

## Operating

- Start/stop through llama-swap (request the model, or `POST /api/models/unload/qwen-coder`).
- Logs: `docker logs -f qwen-coder`, or `curl -N http://127.0.0.1:8080/logs/stream/qwen-coder`.
- Loaded state: `curl -s http://127.0.0.1:8080/running | jq .`
- Update: pull the new tag on every node while serving, compare image IDs, announce downtime, swap the tag
  in `models.d/`, restart, rerun the benchmark (see updating.md). Keep the old image until verified.

## Tuning knobs worth knowing

- `--served-model-name`: the ID clients and llama-swap see; set it to the llama-swap model ID.
- `--max-model-len`: caps context and therefore KV reservation; the biggest lever on fit.
- `--gpu-memory-utilization`: fraction of device memory vLLM may claim for weights + KV. On GB10 the
  "device" is the shared 128 GB, and NVIDIA documents that `cudaMemGetInfo` underreports allocatable
  memory (it ignores what swap could reclaim). Budget OS, page cache and co-resident engines explicitly,
  start conservative (NVIDIA's playbook uses 0.8-0.9) and raise only after watching `free -h`.
- `--enable-auto-tool-choice --tool-call-parser <name>` and `--reasoning-parser <name>`: parser names are
  per model family (for example `qwen3_xml` for Qwen3-Coder, `openai` for gpt-oss, `qwen3` reasoning).
- `--default-chat-template-kwargs '{"enable_thinking": false}'`: server-side default merged with request
  `chat_template_kwargs` (request wins). Useful for per-alias reasoning defaults (see reasoning-effort.md).
- `--enable-prefix-caching` / `--no-enable-prefix-caching`: big win for agents resending long prompts.
- `--kv-cache-dtype fp8` (also `nvfp4` and others): more context per GB; numerics change, so gate it.
- `--max-num-seqs`, `--max-num-batched-tokens`: concurrency vs latency; `--speculative-config` for drafts;
  `--enforce-eager` skips CUDA graphs (faster start, slower decode).

## Known pitfalls

- First start downloads weights if they are missing; set `HF_HUB_OFFLINE=1` and download separately in a
  capped scope, or the health check times out mid-download.
- Without `--ipc=host`/`--shm-size`, tensor-parallel runs fail on shared memory.
- Ray cluster shells started by `run_cluster.sh` die with the terminal; run them under systemd or tmux.
- Raising `--gpu-memory-utilization` to "fix" a startup refusal on GB10 can push the host into swap later.
  If memory looks low after heavy file I/O, NVIDIA's debug workaround is dropping the page cache, then restarting.
- vLLM does not expose tool support in `/v1/models`; set `capabilities.tools` by hand in llama-swap.

## Official links

- Docs: https://docs.vllm.ai/ (serve args: `/en/latest/cli/serve.html`; Docker: `/en/latest/deployment/docker.html`)
- Parallelism and multi-node: https://docs.vllm.ai/en/latest/serving/parallelism_scaling.html
- Repo and releases: https://github.com/vllm-project/vllm
- NGC container: https://catalog.ngc.nvidia.com/orgs/nvidia/containers/vllm
- DGX Spark playbook: https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/vllm
