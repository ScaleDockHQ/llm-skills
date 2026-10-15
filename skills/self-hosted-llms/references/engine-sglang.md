# SGLang

> Verified against SGLang v0.5.21, 2026-10-11

This page keeps only what is specific to this stack: the wrapper script, the llama-swap and LiteLLM entries, and the stack pitfalls. Install, flags, tuning and operating detail live in the product skill.

Depth: install the sglang skill (`npx skills add ScaleDockHQ/llm-skills --skill sglang`).

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
