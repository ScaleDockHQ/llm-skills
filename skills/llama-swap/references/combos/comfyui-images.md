# ComfyUI behind llama-swap

> Verified against llama-swap v263 (docs/kb/guides/upstreams/comfyui.md), 2026-10-11

ComfyUI is a web app, not an OpenAI-compatible server, so llama-swap serves it through a dedicated passthrough rather than `/v1/*`.

## Setup

Name the model exactly `comfyui_auto` and browse `http://localhost:8080/comfyui/` (`/comfyui` redirects and keeps the query string). Only one instance can use it.

```yaml
models:
  comfyui_auto:
    checkEndpoint: / # ComfyUI has no /health
    cmdStop: docker stop comfyui-auto
    cmd: >
      docker run --rm --name comfyui-auto --runtime=nvidia --gpus all
      -p ${PORT}:8188 -v /srv/comfyui/models:/root/ComfyUI/models
      -v /srv/comfyui/output:/root/ComfyUI/output
      yanwk/comfyui-boot:cu130-slim-v2
    unloadTimeout: 30
    ttl: 600
    unlisted: true # keep it out of /v1/models
```

The mounts are trimmed; the upstream guide has the full set. The image `yanwk/comfyui-boot:cu130-slim-v2` is the one the upstream guide uses; confirm the tag exists on Docker Hub before use (not re-checked here).

## What llama-swap forces

`compat.ignoreWebsockets: true` and `concurrencyLimit >= 999` are applied for `comfyui_auto`, so an open browser tab neither keeps the model busy nor reloads it. Websocket traffic does not reset the TTL; use a longer `ttl` for long renders. A `GET` to `/ws`, `/api/jobs` or a static asset cannot start the model (409); a `POST` that queues a job does.

## Another instance, or a custom ID

Serve it through `/upstream/<model>/` with `compat.ignoreWebsockets: true`, `concurrencyLimit: 999`, and an `upstream.ignorePaths` list that repeats the three default patterns (listing any pattern replaces the default). Details: upstream guide.

## Image pipeline into LiteLLM

ComfyUI is not exposed on `/v1/images/generations`. To give clients one URL for images, use a stable-diffusion.cpp model (routes `/v1/images/generations` and `/sdapi/v1/*` through llama-swap, then add it to LiteLLM as an image model), and keep ComfyUI for interactive work on `/comfyui/`. Pipeline details belong to the future `comfyui` skill.
