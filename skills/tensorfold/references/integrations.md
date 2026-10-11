# TensorFold: integrations

> Verified against TensorFold v1.0.7, 2026-10-11

README, docs/api.md, old repo notes for llama-swap and LiteLLM

## llama-swap (direct `cmd`, no container)

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

Pass `--port ${PORT}` because the native default 8080 collides with llama-swap. One model per process; `/health` does not load a model. Keep heavy engines in an exclusive llama-swap group. See `templates/llama-swap.yaml`.

For a recipe, wrap its launcher (`./start.sh`) instead; recipes default to `HOST=0.0.0.0 PORT=8888` and read `HOST`, `PORT`, `CONTAINER_NAME` from the environment. Set `HOST=127.0.0.1` and confirm with `ss -ltnp` nothing listens on `0.0.0.0`.

## LiteLLM

```yaml
- model_name: nemotron-tf
  litellm_params:
    model: openai/nemotron-tf
    api_base: http://127.0.0.1:8080/v1 # the gateway's address (llama-swap), not the engine's port
    api_key: os.environ/LLAMA_SWAP_API_KEY
```

Behind a gateway on loopback do not set `--api-key`; if you must, use `--api-key-file`. Tool use, reasoning fields and Responses/Anthropic routes are native to the server; see `api.md`.

## Clients

- OpenAI SDKs: `base_url=http://HOST:PORT/v1`, model = `/v1/models` ID.
- Anthropic/Claude Code: `ANTHROPIC_BASE_URL=http://HOST:PORT ANTHROPIC_API_KEY=<key-or-local>`.
- vLLM dashboards: metrics are duplicated under vLLM names (swap the `tensorfold:` prefix); see `observability.md`.
- Custom chat templates: `--chat-template FILE`.

## systemd

`templates/tensorfold.service` runs the archive binary with loopback binding. For recipes with `FOREGROUND=1 ./start.sh` (dual recipe) use a unit that runs that command; it exits with rank 0's exit code and stops the other rank when either ends.
