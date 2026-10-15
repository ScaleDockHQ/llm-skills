# vLLM

> Verified against vLLM v0.31.0, 2026-10-11

This page keeps only what is specific to this stack: the wrapper script, the llama-swap and LiteLLM entries, and the stack pitfalls. Install, flags, tuning and operating detail live in the product skill.
Dual DGX Spark runtimes (Ray and multiprocessing) are covered in the `vllm` skill.

Depth: install the vllm skill (`npx skills add ScaleDockHQ/llm-skills --skill vllm`).

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
    ttl: 0 # slow cold start: let the router evict it only when needed
    unloadTimeout: 60 # container shutdown frees memory slowly
    capabilities:
      tools: true # vLLM cannot report this; context is auto-read from max_model_len
```

Put it in an exclusive group (see llama-swap.md) and raise top-level `healthCheckTimeout` above the
observed cold-start time.

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
    api_key: os.environ/LLAMA_SWAP_API_KEY # any non-empty placeholder if llama-swap has no apiKeys
```

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
