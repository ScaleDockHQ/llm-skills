# ExLlamaV3 (EXL3) via TabbyAPI or an OpenAI server

> Verified against ExLlamaV3 v1.6.1 (TabbyAPI main branch, no releases), 2026-10-11

This page keeps only what is specific to this stack: the wrapper script, the llama-swap and LiteLLM entries, and the stack pitfalls. Install, flags, tuning and operating detail live in the product skill.

Depth: install the exllamav3 skill (`npx skills add ScaleDockHQ/llm-skills --skill exllamav3`).

## Minimal working config

**TabbyAPI** (container listens on 5000 inside; config keys can be overridden as `--<key-with-dashes>`):

```bash
# /opt/llm-stack/models.d/exl3-model.sh
model_run() {
  docker run -d --name "$MODEL_ID" --label llm-stack.role=engine \
    --gpus all --shm-size=8g -p "127.0.0.1:${PORT}:5000" \
    -v /srv/models/exl3:/app/models \
    ghcr.io/theroyallab/tabbyapi:latest \
    main.py --host 0.0.0.0 --port 5000 --disable-auth true \
    --model-name Qwen3-32B-exl3-4.0bpw --max-seq-len 32768 --cache-size 32768
}
```

The image entrypoint is `python3` with default command `main.py --host 0.0.0.0`, so pass `main.py` first.
`--disable-auth true` is only safe because the port is published on 127.0.0.1 and LiteLLM holds the keys;
TabbyAPI warns that disabling auth also exposes it to local browser pages, so also restrict
`network.allowed_origins` (for example `[]`) in a mounted `/app/config.yml`.

**MiaAI-Lab fork server** (runs on the host from the fork's venv; `--host` defaults to 0.0.0.0, so always
pass 127.0.0.1):

```bash
# /opt/llm-stack/models.d/qwen-exl3.sh  (single host process; adjust paths to your checkout)
model_run() {
  cd /opt/exllamav3-mia && exec ./.venv/bin/python tools/serve_openai.py \
    --model /srv/models/Qwen3.8-27B-exl3-5.0bpw --draft_model mtp \
    --cache_size 65536 --host 127.0.0.1 --port "$PORT"
}
```

The venv path is whatever the fork's `start.sh` created (check it). A host process does not get the
container label; the wrapper must stop it itself.

llama-swap entry (either variant):

```yaml
models:
  exl3-model:
    cmd: /opt/llm-stack/start-model.sh run exl3-model ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop exl3-model
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    unloadTimeout: 30
```

## How it plugs into the stack

- **Port:** llama-swap `${PORT}` on 127.0.0.1 (TabbyAPI default 5000, fork default 8888).
- **Health:** both expose `GET /health`; neither loads a model on it. TabbyAPI returns 503 while unhealthy.
- **Auth:** TabbyAPI generates `api_tokens.yml` and enforces keys by default; disable on loopback only as
  above. The fork's server has no auth at all, so never bind it beyond loopback.
- **APIs:** TabbyAPI: `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/models`, plus its
  own model load/unload admin routes. Fork: `/v1/models`, `/health`, `/v1/chat/completions` only. Neither
  has `/v1/responses` or Anthropic `/v1/messages`; LiteLLM bridges both.
- **LiteLLM entry:**

```yaml
- model_name: exl3-model
  litellm_params:
    model: openai/exl3-model
    api_base: http://127.0.0.1:8080/v1
    api_key: os.environ/LLAMA_SWAP_API_KEY
    use_chat_completions_api: true # engine has no /v1/responses
```

## Known pitfalls

- Docker's default 64 MiB `/dev/shm` breaks tensor parallel and CPU MoE offload; keep `--shm-size`.
- TabbyAPI exits if its port is taken rather than moving; let llama-swap assign `${PORT}`.
- Leaving `inline_model_loading` off is right here: llama-swap, not TabbyAPI, decides what is loaded.
- An amd64-only image on a Spark fails with an exec format error; build or use the fork.
- The fork's `--host` default of 0.0.0.0 publishes an unauthenticated server on every interface.

## Official links

- ExLlamaV3: https://github.com/turboderp-org/exllamav3 (releases: `/releases`)
- TabbyAPI: https://github.com/theroyallab/tabbyAPI (docs: `/tree/main/docs`, `config_sample.yml`)
- MiaAI-Lab fork: https://github.com/MiaAI-Lab/exllamav3
