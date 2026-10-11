# stable-diffusion.cpp `sd-server` (and ComfyUI as the alternative)

> Verified against stable-diffusion.cpp master-956-1b0ba10, 2026-10-11

## How it plugs into the stack

- **Port:** llama-swap `${PORT}`. Native default is `127.0.0.1:1234`.
- **Health:** none documented. The server loads the model before it listens, so any 200 means ready; `GET /v1/models` is cheap and loads nothing, `"/"` also works, `"none"` is the fallback. Inferred from source: verify after each update.
- **Auth:** none; keep it on loopback behind LiteLLM.
- **APIs:** OpenAI `POST /v1/images/generations`, `POST /v1/images/edits`, `GET /v1/models`; WebUI `/sdapi/v1/*`; native async `/sdcpp/v1/*`. No chat, Responses or Anthropic APIs. llama-swap routes `/v1/images/generations` and `/sdapi/v1/*` by model; other paths go through `/upstream/image-sd/...`.
- **LiteLLM entry** (image generation; smoke test it, response shapes differ between servers):

```yaml
- model_name: image-sd
  litellm_params:
    model: openai/image-sd
    api_base: http://127.0.0.1:8080/v1
    api_key: os.environ/LLAMA_SWAP_API_KEY
```

- **Operating:** start and stop via llama-swap; logs via `/logs/stream/image-sd`. After an update generate one fixed-seed image and compare.

Depth: install the stable-diffusion-cpp skill (npx skills add ScaleDockHQ/llms-skills --skill stable-diffusion-cpp). For the node-graph alternative install the comfyui skill; for Python pipelines the diffusers skill; for the genmedia stack the self-hosted-genmedia skill.
