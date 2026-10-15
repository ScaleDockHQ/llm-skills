# ComfyUI behind llama-swap, with LiteLLM in front

> Verified against ComfyUI v0.39.0, llama-swap v263 (docs/config.example.yaml, docs/kb/guides/upstreams/comfyui.md) and LiteLLM v1.105.0 docs, 2026-10-11

The stack is `client -> LiteLLM :4000 -> llama-swap :8080 -> ComfyUI :${PORT}`. Two paths exist because ComfyUI is not OpenAI-shaped:

| Client needs                                             | Path                                                                                               |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| The ComfyUI UI, or native `/prompt` and `/history` calls | llama-swap `/comfyui/` passthrough on a private path (tailnet, loopback, SSH). LiteLLM is skipped. |
| OpenAI `/v1/images/generations`                          | LiteLLM `image_generation` model -> llama-swap model that runs your **own wrapper** -> ComfyUI     |

LiteLLM v1.105.0 has no ComfyUI provider (no `providers/comfyui` docs page, no `litellm/llms` directory for it), so it can only reach ComfyUI through an OpenAI-shaped wrapper. See `integrations.md` for the wrapper outline; this skill does not ship one because none was run against a live server.

## 1. ComfyUI in llama-swap

The reserved model id is `comfyui_auto`; the endpoint is `http://<llama-swap>/comfyui/` (`/comfyui` redirects and keeps the query string). Only one instance can use it.

```yaml
models:
  comfyui_auto:
    cmd: |
      ${env.HOME}/ComfyUI/.venv/bin/python ${env.HOME}/ComfyUI/main.py
      --listen 127.0.0.1 --port ${PORT}
      --disable-all-custom-nodes --offline --disable-auto-launch
    checkEndpoint: / # ComfyUI has no /health
    ttl: 600
    unloadTimeout: 30
    unlisted: true # not an OpenAI model; keep it out of /v1/models
```

`templates/llama-swap-comfyui.yaml` is the full file with a group. For a container, add `cmdStop: docker stop <name>` and `-p 127.0.0.1:${PORT}:8188`; without `cmdStop`, SIGTERM reaches the `docker run` client, not the container, and the GPU stays held. The community image the llama-swap guide uses is `yanwk/comfyui-boot:cu130-slim-v2` (amd64 only when checked; see `install.md`).

What llama-swap forces on `comfyui_auto` (guide): `compat.ignoreWebsockets` is set to `true` and `concurrencyLimit` is raised to at least 999, so an open browser tab does not keep the model busy or reload it after a TTL unload. Websocket traffic is ignored for TTL, so a long render watched only over the websocket can be unloaded: use a longer `ttl`, or `ttl: 0` and rely on a group swap. A `GET` to `/ws`, `/api/jobs` or a static asset cannot start the model (409); queueing with `POST` does.

Keep the process bound to `127.0.0.1`, because llama-swap's `apiKeys` is the only auth in the path. API-key checks apply to `/comfyui/` like other endpoints.

For a second ComfyUI or a custom model id, use `/upstream/<model>/` and reproduce the settings by hand: `concurrencyLimit: 999`, `compat.ignoreWebsockets: true`, and `upstream.ignorePaths` (note that listing any pattern replaces the default static-asset pattern, and it matches every method rather than `GET` alone). The guide's exact patterns are in the `llama-swap` skill's `comfyui-images` combo (install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`).

## 2. Placement next to LLMs

Image and video models are large, so put `comfyui_auto` in the same exclusive group as the big LLM so they take turns:

```yaml
routing:
  router:
    use: group
    settings:
      groups:
        heavy:
          swap: true
          exclusive: true
          members: [comfyui_auto, "<your-big-llm>"]
```

If the GPU can hold both, use a non-exclusive group and set `--reserve-vram` for ComfyUI (`performance-memory.md`). Budget memory first with `self-hosted-genmedia`.

## 3. LiteLLM for the OpenAI-shaped path

Only after a wrapper exists and is registered in llama-swap as a model (for example `comfy-image`):

```yaml
model_list:
  - model_name: comfy-image
    litellm_params:
      model: openai/comfy-image # openai/ prefix + llama-swap model id
      api_base: http://127.0.0.1:8080/v1 # keep /v1
      api_key: os.environ/LLAMA_SWAP_API_KEY
      timeout: 900 # slow renders and cold swaps
    model_info:
      mode: image_generation
```

`templates/litellm-comfyui.yaml` has the same entry with comments. `model_info.mode: image_generation` is what LiteLLM docs use for image models; keep image models out of background health checks (`disable_background_health_check: true`) so a monitor does not evict the LLM.

## 4. Test each hop

```bash
# 1. ComfyUI alone (start it by hand on a spare port)
scripts/comfy-run.sh workflow_api.json
# 2. through llama-swap's passthrough (the POST starts the model)
COMFY_URL=http://127.0.0.1:8080/comfyui scripts/comfy-run.sh workflow_api.json
# 3. the model is running and the group behaves
curl -fsS http://127.0.0.1:8080/running | jq .
# 4. through LiteLLM (only with a wrapper); write the output to a file and check it
curl -sS --max-time 900 http://127.0.0.1:4000/v1/images/generations \
  -H "Authorization: Bearer $LITELLM_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"comfy-image","prompt":"a red bicycle, studio photo","size":"1024x1024"}' \
  | jq -r '.data[0].b64_json' | base64 -d > image.png && file image.png   # macOS: base64 -D
```

Step 2 sends the API calls to `/comfyui/prompt` etc. Whether `COMFY_URL=http://127.0.0.1:8080/comfyui` works end to end for every route (`/history`, `/view`) was not exercised against a live llama-swap; treat it as unverified and fall back to `/upstream/comfyui_auto/` or the process's own port if a route 404s.

## Pitfalls

- The default `checkEndpoint` of `/health` never succeeds against ComfyUI.
- `healthCheckTimeout` must exceed cold start including the first model load; ComfyUI itself is up in seconds, but a custom-node-heavy install can take minutes.
- A wrapper must treat a cold swap as part of the request time or return a job id; through Cloudflare, synchronous calls past ~125 s return 524.
- Streaming the websocket through LiteLLM does not work: LiteLLM is an OpenAI-shaped gateway.
