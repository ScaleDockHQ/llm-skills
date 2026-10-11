# KoboldCpp integrations

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

## Clients

Any OpenAI-compatible client: base URL `http://127.0.0.1:5001/v1`, any model name, API key = `--password`
value if set (else any string). Also speaks KoboldAI, Ollama, Anthropic (`/v1/messages`), A1111 and ComfyUI
styles, so SillyTavern, Open WebUI, chat UIs and IDE agents can point at it by picking the matching API
type. For client setup see the `llm-clients` skill.

## llama-swap in front (several models, on demand)

```yaml
models:
  "kobold-qwen":
    cmd: |
      /opt/koboldcpp/koboldcpp-linux-x64 --model ${models_dir}/model.gguf
      --usecuda --contextsize 16384 --host 127.0.0.1 --port ${PORT} --skiplauncher --jinja
    proxy: "http://127.0.0.1:${PORT}"
    checkEndpoint: /api/extra/version
    ttl: 1800
```

KoboldCpp has no `/health`, hence the version endpoint. Raise `healthCheckTimeout` above the real cold load.
See the `llama-swap` skill for the rest.

## LiteLLM

```yaml
model_list:
  - model_name: kobold
    litellm_params:
      model: openai/koboldcpp
      api_base: http://127.0.0.1:5001/v1
      api_key: os.environ/KCPP_PASSWORD # any non-empty value if --password is unset
```

KoboldCpp implements `/v1/responses`, so the `openai/` custom-base Responses assumption in LiteLLM is
satisfied; still test a streamed request. See `litellm`.

## Admin and router mode (built-in model swapping)

Put several `.kcpps` (or `.gguf`) files in one directory, then:

```bash
./koboldcpp-linux-x64 --admin --admindir /srv/kcpp-configs --adminpassword "$KCPP_ADMINPASSWORD" \
  --routermode --host 127.0.0.1 --port 5001
```

- Without `--routermode`, swap by hand: `POST /api/admin/reload_config` with `{"filename":"x.kcpps"}` and
  `Authorization: Bearer $KCPP_ADMINPASSWORD`.
- With `--routermode` (needs `--admin`), a chat or completion request whose `model` equals a file name in the
  admin dir triggers a reload of that config, then proxies the request. `GET /v1/models` lists those names.
- `--autoswapmode` (needs admin and router) lets one config define text, image, speech and other models and
  swaps families automatically; `--autoswapthreshold MB` keeps small families resident.
- `--adminunloadtimeout s` unloads the model after idle time; `--baseconfig` supplies a base config.
- Swaps are a full reload: expect cold-load latency on the first request after a switch.

## Reverse proxy and TLS

Bind KoboldCpp to loopback and terminate TLS in Caddy, nginx or a tunnel (`caddy`, `cloudflare-tunnel`,
`tailscale` skills). Disable response buffering for SSE (nginx `proxy_buffering off`; Caddy flushes SSE
responses on its own; `flush_interval -1` forces it). Alternatively `--ssl cert.pem key.pem` (unencrypted PEMs). `--password` does
not cover image endpoints, so also enforce auth at the proxy if images are enabled.
`--remotetunnel` creates a Cloudflare tunnel for you; it exposes the server publicly, so ask first.

## Image models and ComfyUI

KoboldCpp emulates parts of the ComfyUI API (`/prompt`, `/history`, `/view`), so tools that talk to ComfyUI
can often use it; for full node workflows use the `comfyui` skill.

## Kubernetes

No official chart or manifest. The Docker image is for experts; if you must, run it as a single replica with a
PVC for models and probe `/api/extra/version`.
