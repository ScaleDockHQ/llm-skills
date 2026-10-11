# TensorFold

> Verified against TensorFold v1.0.7, 2026-10-11

This page keeps only what is specific to this stack: the wrapper script, the llama-swap and LiteLLM entries, and the stack pitfalls. Install, flags, tuning and operating detail live in the product skill.

Depth: install the tensorfold skill (`npx skills add ScaleDockHQ/llms-skills --skill tensorfold`).

## Minimal working config

Engine command (single binary, loopback is the default bind):

```bash
/opt/tensorfold/current/bin/tensorfold-native serve ~/models/nemotron-lightning \
  --name nemotron-tf --host 127.0.0.1 --port 8090 --context 32768 --parallel 4
curl -fsS http://127.0.0.1:8090/health && curl -fsS http://127.0.0.1:8090/v1/models | jq .
```

llama-swap entry (direct `cmd`, no container needed):

```yaml
models:
  nemotron-tf:
    cmd: |
      /opt/tensorfold/current/bin/tensorfold-native serve /srv/models/nemotron-lightning
      --name ${MODEL_ID} --host 127.0.0.1 --port ${PORT}
      --context 32768 --parallel 4
    checkEndpoint: /health
    ttl: 0
```

For a recipe, call its own launcher from the wrapper instead (`models.d/<id>.sh`, `model_run()` runs the
recipe's `start.sh` with the recipe's documented overrides). Both MiaAI-Lab recipes read `HOST`, `PORT` and
`CONTAINER_NAME` from the environment and default to `HOST=0.0.0.0`, `PORT=8888`: set
`HOST=127.0.0.1 PORT="$PORT" CONTAINER_NAME="$MODEL_ID"`, and confirm with `ss -ltnp` that nothing listens
on 0.0.0.0. Recipe containers do not carry the `llm-stack.role=engine` label unless the recipe adds it.

## How it plugs into the stack

- **Port:** llama-swap `${PORT}` on 127.0.0.1 (native default `127.0.0.1:8080`, which collides with
  llama-swap, so always pass `--port`). Recipes default to 8888.
- **Health:** `GET /health` (no model load; one model per process). `/metrics` reports CUDA and pinned memory.
- **Auth:** loopback accepts local clients without a key; do not set `--api-key`/`--api-key-file` behind
  the gateway. If you must, use `--api-key-file` (restricted permissions), never `--api-key` on a command line.
- **APIs:** OpenAI chat completions, completions and Responses, plus Anthropic `/v1/messages`.
  `/v1/models` (also `/models`) includes `context_length` and `max_model_len` when the window is finite.
- **LiteLLM entry:**

```yaml
- model_name: nemotron-tf
  litellm_params:
    model: openai/nemotron-tf
    api_base: http://127.0.0.1:8080/v1
    api_key: os.environ/LLAMA_SWAP_API_KEY
```

## Known pitfalls

- Unqualified model/platform pairs are refused or unsupported; "it runs on Metal" does not mean CUDA.
- Port 8080 default collides with llama-swap; recipe `HOST=0.0.0.0` default bypasses the gateway.
- Recipes that pin a large KV pool or set a zero memory reserve hold most of a Spark's memory from the first
  second: put them in an exclusive llama-swap group and never co-locate other engines.
- The dual recipe needs key-based SSH to node-b, a RoCE-capable CX7 link and matching images on both nodes.
- Recipe READMEs contain their own performance tables; do not quote them as your baseline, measure yours.

## Official links

- Repo, README (qualified models, serve flags): https://github.com/ashhart/TensorFold
- Install runbook: https://github.com/ashhart/TensorFold/blob/main/RUNBOOK.md
- Releases: https://github.com/ashhart/TensorFold/releases
- MiaAI-Lab recipes: https://github.com/MiaAI-Lab/Qwen3.8-27B-DGX-Spark-TensorFold,
  https://github.com/MiaAI-Lab/Qwen3.8-Flash-Dual-DGX-Sparks-TensorFold
