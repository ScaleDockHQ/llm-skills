# Integrations

> Verified against TabbyAPI main (docs, docker-compose.yml, routers) and ExLlamaV3 v1.6.1, 2026-10-11

llama-swap and LiteLLM snippets are carried from the repo's self-hosted stack notes and use those tools' documented option names; re-verify them in the `llama-swap` and `litellm` skills.

## llama-swap in front of TabbyAPI

llama-swap decides what is loaded; keep `inline_model_loading` off.

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

The image entrypoint is `python3`, so pass `main.py` first. `--disable-auth true` is acceptable only because the port is published on 127.0.0.1 and LiteLLM holds the keys; also mount a `/app/config.yml` with `network.allowed_origins: []`.

```yaml
models:
  exl3-model:
    cmd: /opt/llm-stack/start-model.sh run exl3-model ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop exl3-model
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    unloadTimeout: 30
```

`/health` returns 503 while unhealthy and does not load a model. TabbyAPI exits if its port is taken rather than moving, so let llama-swap assign `${PORT}` (the container always uses 5000 inside).

## LiteLLM

```yaml
- model_name: exl3-model
  litellm_params:
    model: openai/exl3-model
    api_base: http://127.0.0.1:8080/v1 # llama-swap, or TabbyAPI :5000/v1 directly
    api_key: os.environ/LLAMA_SWAP_API_KEY # or the TabbyAPI API key
    use_chat_completions_api: true # engine has no /v1/responses
```

LiteLLM bridges `/v1/responses` and Anthropic `/v1/messages` for clients that need them.

## MiaAI fork under llama-swap (DGX Spark)

Host process, not a container:

```bash
model_run() {
  cd /opt/exllamav3-mia && exec ./.venv/bin/python tools/serve_openai.py \
    --model /srv/models/Qwen3.8-27B-exl3-5.0bpw --draft_model mtp \
    --cache_size 65536 --host 127.0.0.1 --port "$PORT"
}
```

Adjust paths to the venv its `start.sh` created. The wrapper must stop the process itself (no container label). The server has no auth: loopback only.

## Clients

- OpenAI SDKs and agents: base URL `http://HOST:5000/v1`, API key from `api_tokens.yml`. Chat, completions and embeddings are standard; no Responses API.
- Open WebUI and other frontends: set the OpenAI connection to TabbyAPI. For frontends that insist on OpenAI model names, enable `use_dummy_models` / `dummy_model_names`. For model switching from the UI use `inline_model_loading` plus per-model `tabby_config.yml`.
- Frontends that send no sampler parameters rely on `sampling.override_preset: safe_defaults`.
- Coding agents that probe llama.cpp endpoints can read `/props` and `/v1/models` `meta` for context size and vision/thinking capability.
- Community UIs and loaders: TabbyAPI wiki page "Community Projects".
- Use `llm-clients` for client-side setup.

## Kubernetes

No official chart or manifest exists upstream (unverified). `templates/k8s.yaml` is a plain Deployment you adapt: one GPU per pod via the NVIDIA device plugin, an `emptyDir` with `medium: Memory` mounted at `/dev/shm` (sizeLimit 8Gi), a model PVC, a Secret mounting `api_tokens.yml` or config, `/health` for readiness and liveness (allow a long `startupProbe` since loading a large model takes minutes). Use `strategy: Recreate` for a single GPU. Scale by replicas behind a Service plus a gateway; there is no cross-pod model sharding.

## Cloudflare Tunnel, Tailscale

Do not expose TabbyAPI directly. Put it behind `litellm` with its own keys and publish via `cloudflare-tunnel` or `tailscale`.
