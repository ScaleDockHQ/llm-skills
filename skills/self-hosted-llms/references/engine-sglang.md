# SGLang

> Verified against SGLang v0.5.21, 2026-10-11

## What it is and when to choose it

SGLang is a high-throughput serving engine with RadixAttention (automatic prefix reuse across requests),
continuous batching, chunked prefill, speculative decoding, tensor/pipeline/data parallelism and
multi-node support. Choose it as an alternative to vLLM when a model's recipe or launch day support lands
in SGLang first, for agent workloads with heavy shared prefixes, or for structured output. It is a
cold-start-heavy engine like vLLM: one model per process, best in an exclusive llama-swap group.

## Install (DGX Spark/arm64 and generic x86)

Use the official image `lmsysorg/sglang`. CUDA 12 tags are no longer published (`v0.5.19-cu129` was the last).

- **Pin:** `lmsysorg/sglang:v0.5.21-cu130` (amd64 + arm64). `latest-cu130` is the moving equivalent and is
  what NVIDIA's DGX Spark SGLang playbook uses.
- **`spark` tag:** arm64-only and last pushed 2025-11 at the time of writing; prefer the versioned `-cu130`
  tag on GB10 unless a model card tells you otherwise.
- Run with `--ipc=host` (or a large `--shm-size`, upstream examples use 32g).
- pip/uv installs exist; containers keep both nodes identical, so prefer them.

## Minimal working config

Engine command (standalone smoke test):

```bash
docker run --rm --gpus all --ipc=host -p 127.0.0.1:30000:30000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_HUB_OFFLINE=1 \
  lmsysorg/sglang:v0.5.21-cu130 \
  python3 -m sglang.launch_server --model-path openai/gpt-oss-120b --served-model-name gpt-oss \
  --host 0.0.0.0 --port 30000 --mem-fraction-static 0.75 --context-length 65536
curl -s http://127.0.0.1:30000/health -o /dev/null -w '%{http_code}\n'
```

`sglang serve MODEL_PATH --host ... --port ...` is the newer equivalent entry point.

Stack wrapper, `/opt/llm-stack/models.d/gpt-oss.sh`:

```bash
model_run() {
  docker run -d --name "$MODEL_ID" --label llm-stack.role=engine \
    --gpus all --ipc=host -p "127.0.0.1:${PORT}:30000" \
    -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_HUB_OFFLINE=1 \
    lmsysorg/sglang:v0.5.21-cu130 \
    python3 -m sglang.launch_server --model-path openai/gpt-oss-120b \
      --served-model-name "$MODEL_ID" --host 0.0.0.0 --port 30000 \
      --mem-fraction-static 0.75 --context-length 65536 --enable-metrics
}
```

llama-swap entry:

```yaml
models:
  gpt-oss:
    cmd: /opt/llm-stack/start-model.sh run gpt-oss ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop gpt-oss
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    ttl: 0
    unloadTimeout: 60
    capabilities:
      tools: true # set by hand; only claim it if you pass --tool-call-parser
```

### Dual DGX Spark

SGLang's multi-node mode runs the same command on both nodes with a shared rendezvous address; use
`--network host` so the ranks reach each other over the ConnectX-7 link:

```bash
# node-a (rank 0, serves the API)       # node-b (rank 1), from worker_run() over ssh
--tp-size 2 --nnodes 2 --node-rank 0    --tp-size 2 --nnodes 2 --node-rank 1
--dist-init-addr 10.0.0.1:50000         --dist-init-addr 10.0.0.1:50000
--host 127.0.0.1 --port "$PORT"
```

Start node-b first, then node-a; stop both. Upstream suggests `--disable-cuda-graph` if a multi-node run
deadlocks. Set NCCL interface variables (for example `NCCL_SOCKET_IFNAME`) to the CX7 interface as in
NVIDIA's connect-two-sparks playbook.

## How it plugs into the stack

- **Port:** llama-swap `${PORT}` on 127.0.0.1 (container 30000).
- **Health:** `GET /health` checks the server without generating; use it as `checkEndpoint`.
  `GET /health_generate` generates one token: good for a deep manual probe, wrong for frequent polling.
  Also `/get_model_info`, `/server_info`, and `/metrics` with `--enable-metrics`.
- **Auth:** do not pass `--api-key`/`--admin-api-key`; loopback only, LiteLLM holds keys.
- **APIs:** OpenAI `/v1/chat/completions`, `/v1/completions`, `/v1/models`, `/v1/responses`, Anthropic
  `/v1/messages`, plus native `/generate`.
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
- `curl -s http://127.0.0.1:8080/upstream/gpt-oss/server_info | jq .` shows effective server args without
  going through the model name router.
- Update: pull the new versioned tag on every node while serving, compare image IDs, read the release notes
  for changed defaults, restart in a downtime window, rerun the benchmark (see updating.md).

## Tuning knobs worth knowing

- `--mem-fraction-static`: fraction for weights + KV pool. On GB10 the GPU shares 128 GB with the OS and
  page cache; start around 0.7-0.8 (the playbook uses 0.75) and lower it if CUDA graph capture OOMs.
- `--context-length`: caps context (default from the model config); `--max-total-tokens` caps the pool.
- `--tool-call-parser <name>` (or `auto` to detect from the chat template) and `--reasoning-parser <name>`.
- `--kv-cache-dtype fp8_e4m3|fp8_e5m2|bf16`: more context per GB; numerics change.
- `--chunked-prefill-size N` (`-1` disables): trades TTFT against memory spikes on long prompts.
- `--max-running-requests`, `--disable-radix-cache` (A/B only), `--speculative-algorithm` for drafts.
- `--enable-cache-report` returns cached prompt tokens in `usage.prompt_tokens_details`.

## Known pitfalls

- `--host 0.0.0.0` with `-p` mapping is fine; with `--network host` (multi-node) it would publish the
  unauthenticated API on every interface: bind 127.0.0.1 in that case.
- NVFP4 checkpoints need `--quantization modelopt_fp4` per NVIDIA's Spark playbook.
- Using `/health_generate` as `checkEndpoint` adds load; keep it for manual checks.
- The `spark` tag can lag far behind releases; confirm what you run with `/server_info` or `pip show sglang`
  inside the container.

## Official links

- Docs: https://docs.sglang.io/ (server arguments, native APIs, Anthropic-compatible API, install)
- Repo and releases: https://github.com/sgl-project/sglang
- Images: https://hub.docker.com/r/lmsysorg/sglang/tags
- DGX Spark playbook: https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/sglang
